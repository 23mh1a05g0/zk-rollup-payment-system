const { contract } = require("./blockchain");
const pool = require("./db");

function startIndexer() {
  console.log("📡 Starting Indexer Event Listeners...");

  // 1. Deposited event
  contract.on("Deposited", async (user, amount, newBalance, event) => {
    try {
      const txHash = event.log ? event.log.transactionHash : (event.transactionHash || "");
      const blockNumber = Number(event.log ? event.log.blockNumber : (event.blockNumber || 0));
      console.log(`[INDEXER] Deposited user=${user} amount=${amount.toString()} tx=${txHash} block=${blockNumber}`);

      await pool.query(
        `INSERT INTO deposits (user_address, amount_wei, tx_hash, block_number, indexed_at)
         VALUES ($1, $2, $3, $4, NOW())`,
        [user.toLowerCase(), amount.toString(), txHash, blockNumber]
      );
      console.log(`[INDEXER] Successfully indexed deposit for ${user}`);
    } catch (err) {
      console.error("[INDEXER ERROR] Deposited handler failed:", err.message);
    }
  });

  // 2. BatchCommitted event
  contract.on("BatchCommitted", async (batchIndex, newStateRoot, batchHash, txCount, relayer, event) => {
    try {
      const txHash = event.log ? event.log.transactionHash : (event.transactionHash || "");
      console.log(`[INDEXER] BatchCommitted batchIndex=${batchIndex.toString()} newStateRoot=${newStateRoot} tx=${txHash}`);

      // Update committed_at, tx_hash. If not exists (e.g. proposed on chain first), insert it.
      await pool.query(
        `INSERT INTO batches (batch_index, old_state_root, new_state_root, batch_hash, tx_count, relayer_address, committed_at, tx_hash)
         VALUES ($1, NULL, $2, $3, $4, $5, NOW(), $6)
         ON CONFLICT (batch_index) DO UPDATE
         SET new_state_root = EXCLUDED.new_state_root,
             batch_hash = EXCLUDED.batch_hash,
             tx_count = EXCLUDED.tx_count,
             relayer_address = EXCLUDED.relayer_address,
             committed_at = NOW(),
             tx_hash = EXCLUDED.tx_hash`,
        [
          Number(batchIndex),
          newStateRoot,
          batchHash,
          Number(txCount),
          relayer.toLowerCase(),
          txHash
        ]
      );
      console.log(`[INDEXER] Successfully indexed batch index=${batchIndex}`);
    } catch (err) {
      console.error("[INDEXER ERROR] BatchCommitted handler failed:", err.message);
    }
  });

  // 3. Withdrawn event
  contract.on("Withdrawn", async (user, amount, event) => {
    try {
      console.log(`[WITHDRAW] address=${user} amount=${amount.toString()}`);
    } catch (err) {
      console.error("[INDEXER ERROR] Withdrawn handler failed:", err.message);
    }
  });
}

module.exports = { startIndexer };
