require("dotenv").config();
const express = require("express");
const cors = require("cors");
const contract = require("./blockchain");
const pool = require("./db");
const crypto = require("crypto"); // ✅ important

const app = express();

app.use(cors());
app.use(express.json());

// Root route
app.get("/", (req, res) => {
  res.send("Backend running ✅");
});

// DB test
app.get("/test-db", async (req, res) => {
  try {
    const result = await pool.query("SELECT NOW()");
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Create intent
app.post("/intents", async (req, res) => {
  try {
    const { from, to, amount } = req.body;

    const result = await pool.query(
      `INSERT INTO payment_intents (from_address, to_address, amount_wei)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [from, to, amount]
    );

    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Get intents
app.get("/intents", async (req, res) => {
  try {
    const result = await pool.query(
      "SELECT * FROM payment_intents ORDER BY created_at DESC"
    );

    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ✅ CREATE BATCH (FIXED)
app.post("/batches/create", async (req, res) => {
  try {
    const intentsResult = await pool.query(
      "SELECT * FROM payment_intents WHERE status = 'pending' LIMIT 10"
    );

    const intents = intentsResult.rows;

    if (intents.length === 0) {
      return res.json({ message: "No pending intents" });
    }

    const indexResult = await pool.query(
      "SELECT COALESCE(MAX(batch_index), 0) + 1 AS next_index FROM batches"
    );

    const batchIndex = indexResult.rows[0].next_index;

    // ✅ FIXED (valid bytes32)
    const newStateRoot = "0x" + crypto.randomBytes(32).toString("hex");
    const batchHash = "0x" + crypto.randomBytes(32).toString("hex");

    const batchResult = await pool.query(
      `INSERT INTO batches (batch_index, new_state_root, batch_hash, tx_count, relayer_address)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        batchIndex,
        newStateRoot,
        batchHash,
        intents.length,
        "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266",
      ]
    );

    const batch = batchResult.rows[0];

    const ids = intents.map((i) => `'${i.id}'`).join(",");

    await pool.query(
      `UPDATE payment_intents 
       SET status = 'batched', batch_id = $1 
       WHERE id IN (${ids})`,
      [batch.id]
    );

    res.json({ batch, intents });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

// COMMIT BATCH
app.post("/batches/commit", async (req, res) => {
  try {
    const { batchId } = req.body;

    const batchResult = await pool.query(
      "SELECT * FROM batches WHERE id = $1",
      [batchId]
    );

    const batch = batchResult.rows[0];

    if (!batch) {
      return res.status(404).json({ error: "Batch not found" });
    }

    const proof = "0x1234";
    const publicInputs = [];

    const tx = await contract.commitBatch(
      batch.new_state_root,
      batch.batch_hash,
      batch.tx_count,
      proof,
      publicInputs
    );

    await tx.wait();

    res.json({
      message: "Batch committed to blockchain ✅",
      txHash: tx.hash,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});

const PORT = process.env.PORT || 4000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});