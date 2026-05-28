const { ethers } = require("ethers");
const { contract, wallet } = require("./blockchain");
const pool = require("./db");

let isRunning = false;

async function processPendingIntents() {
  if (isRunning) return;
  isRunning = true;

  try {
    // 1. Fetch up to 10 pending payment intents
    const intentsRes = await pool.query(
      `SELECT * FROM payment_intents 
       WHERE status = 'pending' 
       ORDER BY created_at ASC 
       LIMIT 10`
    );
    const intents = intentsRes.rows;

    if (intents.length === 0) {
      isRunning = false;
      return;
    }

    console.log(`[RELAYER] Found ${intents.length} pending intents. Processing batch...`);

    // 2. Query current blockchain state
    const batchCount = await contract.batchCount();
    const currentStateRoot = await contract.currentStateRoot();

    // 3. Compute batchHash (keccak256 of concatenated intent IDs)
    const concatenatedIds = intents.map(i => i.id).join("");
    const batchHash = ethers.keccak256(ethers.toUtf8Bytes(concatenatedIds));

    // 4. Compute newStateRoot (keccak256 of currentStateRoot + batchHash)
    const packedData = ethers.concat([currentStateRoot, batchHash]);
    const newStateRoot = ethers.keccak256(packedData);

    console.log(`[RELAYER] Batch: count=${batchCount.toString()} currentStateRoot=${currentStateRoot} batchHash=${batchHash} newStateRoot=${newStateRoot}`);

    // 5. Submit transaction
    let tx;
    try {
      tx = await contract.commitBatch(
        newStateRoot,
        batchHash,
        intents.length,
        "0x1234", // Stub proof
        []        // Stub public inputs
      );
      console.log(`[RELAYER] Transaction submitted: ${tx.hash}. Waiting for confirmation...`);
      await tx.wait();
      console.log(`[RELAYER] Transaction confirmed.`);
    } catch (txErr) {
      console.error(`[RELAYER ERROR] Transaction failed:`, txErr.message);
      
      // Update intents status to failed
      const intentIds = intents.map(i => i.id);
      await pool.query(
        `UPDATE payment_intents
         SET status = 'failed', updated_at = NOW()
         WHERE id = ANY($1::uuid[])`,
        [intentIds]
      );
      isRunning = false;
      return;
    }

    // 6. DB update transaction on success
    const client = await pool.connect();
    try {
      await client.query("BEGIN");

      // Insert batch record (if indexer hasn't inserted it yet via event listener)
      const batchInsertRes = await client.query(
        `INSERT INTO batches (batch_index, old_state_root, new_state_root, batch_hash, tx_count, relayer_address, committed_at, tx_hash)
         VALUES ($1, $2, $3, $4, $5, $6, NOW(), $7)
         ON CONFLICT (batch_index) DO UPDATE
         SET old_state_root = EXCLUDED.old_state_root,
             new_state_root = EXCLUDED.new_state_root,
             batch_hash = EXCLUDED.batch_hash,
             tx_count = EXCLUDED.tx_count,
             relayer_address = EXCLUDED.relayer_address,
             committed_at = NOW(),
             tx_hash = EXCLUDED.tx_hash
         RETURNING id`,
        [
          Number(batchCount),
          currentStateRoot,
          newStateRoot,
          batchHash,
          intents.length,
          wallet.address.toLowerCase(),
          tx.hash
        ]
      );
      const dbBatchId = batchInsertRes.rows[0].id;

      // Update payment intents to 'batched' and associate with batch_id
      const intentIds = intents.map(i => i.id);
      await client.query(
        `UPDATE payment_intents
         SET status = 'batched', batch_id = $1, updated_at = NOW()
         WHERE id = ANY($2::uuid[])`,
         [dbBatchId, intentIds]
      );

      await client.query("COMMIT");
      console.log(`[RELAYER] Successfully updated DB for batch ${batchCount.toString()}`);
    } catch (dbErr) {
      await client.query("ROLLBACK");
      console.error(`[RELAYER ERROR] DB transaction failed:`, dbErr.message);
    } finally {
      client.release();
    }

  } catch (err) {
    console.error(`[RELAYER ERROR] General execution failed:`, err.message);
  } finally {
    isRunning = false;
  }
}

function startRelayer() {
  console.log("⏱️ Starting Relayer periodic worker (every 15 seconds)...");
  
  // Run process immediately on start
  processPendingIntents();

  // Schedule recursively to avoid overlap
  const interval = 15000;
  const run = async () => {
    await processPendingIntents();
    setTimeout(run, interval);
  };
  setTimeout(run, interval);
}

module.exports = { startRelayer };
