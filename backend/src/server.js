require("dotenv").config();
const express = require("express");
const cors = require("cors");
const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

const { contract, contractAddress } = require("./blockchain");
const pool = require("./db");
const { startIndexer } = require("./indexer");
const { startRelayer } = require("./relayer");

const app = express();

app.use(cors());
app.use(express.json());

// Root route
app.get("/", (req, res) => {
  res.send("Backend running ✅");
});

// Database Migration on startup
async function runMigrations() {
  const client = await pool.connect();
  try {
    console.log("[DB] Running migrations...");
    const migrationPath = path.join(__dirname, "../migrations/001_init.sql");
    if (!fs.existsSync(migrationPath)) {
      throw new Error(`Migration file not found at ${migrationPath}`);
    }
    const sql = fs.readFileSync(migrationPath, "utf8");
    await client.query(sql);
    console.log("[DB] Migrations executed successfully ✅");
  } catch (err) {
    console.error("[DB] Migration failed ❌", err.message);
    process.exit(1);
  } finally {
    client.release();
  }
}

// ---------------- REST API ENDPOINTS ----------------

// 1. Submit a new payment intent (POST /intents)
app.post("/intents", async (req, res) => {
  try {
    const fromAddress = req.body.fromAddress || req.body.from;
    const toAddress = req.body.toAddress || req.body.to;
    const amountWei = req.body.amountWei || req.body.amount;

    if (!fromAddress || !toAddress || !amountWei) {
      return res.status(400).json({ error: "Missing required fields: fromAddress, toAddress, amountWei" });
    }

    console.log("[DEBUG] POST /intents:", { fromAddress, toAddress, amountWei, isFromAddr: ethers.isAddress(fromAddress), isToAddr: ethers.isAddress(toAddress) });

    if (!ethers.isAddress(fromAddress) || !ethers.isAddress(toAddress)) {
      return res.status(400).json({ error: "Invalid Ethereum address" });
    }

    // Live contract check for fromAddress deposit balance
    let balanceWei;
    try {
      balanceWei = await contract.deposits(fromAddress);
    } catch (contractErr) {
      console.error("[API ERROR] deposits call failed:", contractErr.message);
      return res.status(500).json({ error: "Blockchain node connection error" });
    }

    if (balanceWei < BigInt(amountWei)) {
      return res.status(400).json({ error: "Insufficient on-chain deposit" });
    }

    // Insert pending intent
    const result = await pool.query(
      `INSERT INTO payment_intents (from_address, to_address, amount_wei, status)
       VALUES ($1, $2, $3, 'pending')
       RETURNING *`,
      [fromAddress.toLowerCase(), toAddress.toLowerCase(), amountWei]
    );
    const row = result.rows[0];

    res.status(201).json({
      intentId: row.id,
      fromAddress: row.from_address,
      toAddress: row.to_address,
      amountWei: row.amount_wei,
      status: row.status,
      createdAt: row.created_at,
      updatedAt: row.updated_at
    });
  } catch (err) {
    console.error("[API ERROR] POST /intents:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// 2. Retrieve a list of payment intents (GET /intents)
app.get("/intents", async (req, res) => {
  try {
    const { address, status } = req.query;
    let queryText = "SELECT * FROM payment_intents";
    const queryParams = [];
    const whereClauses = [];

    if (address) {
      queryParams.push(address.toLowerCase());
      whereClauses.push(`from_address = $${queryParams.length}`);
    }
    if (status) {
      queryParams.push(status);
      whereClauses.push(`status = $${queryParams.length}`);
    }

    if (whereClauses.length > 0) {
      queryText += " WHERE " + whereClauses.join(" AND ");
    }
    queryText += " ORDER BY created_at DESC";

    const result = await pool.query(queryText, queryParams);
    res.json({ intents: result.rows });
  } catch (err) {
    console.error("[API ERROR] GET /intents:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// 3. Return all committed batches (GET /batches)
app.get("/batches", async (req, res) => {
  try {
    const result = await pool.query("SELECT * FROM batches ORDER BY batch_index DESC");
    res.json({ batches: result.rows });
  } catch (err) {
    console.error("[API ERROR] GET /batches:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// 4. Return details for a single batch plus intents (GET /batches/:batchIndex)
app.get("/batches/:batchIndex", async (req, res) => {
  try {
    const batchIndex = Number(req.params.batchIndex);
    if (isNaN(batchIndex)) {
      return res.status(400).json({ error: "Invalid batchIndex" });
    }

    const batchRes = await pool.query("SELECT * FROM batches WHERE batch_index = $1", [batchIndex]);
    if (batchRes.rows.length === 0) {
      return res.status(404).json({ error: "Batch not found" });
    }
    const batch = batchRes.rows[0];

    const intentsRes = await pool.query("SELECT * FROM payment_intents WHERE batch_id = $1", [batch.id]);

    res.json({
      batch: batch,
      intents: intentsRes.rows
    });
  } catch (err) {
    console.error("[API ERROR] GET /batches/:batchIndex:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// 5. Query user balance on-chain (GET /deposits/:address)
app.get("/deposits/:address", async (req, res) => {
  try {
    const { address } = req.params;
    if (!ethers.isAddress(address)) {
      return res.json({
        address: address,
        balanceWei: "0",
        balanceEth: "0.0"
      });
    }
    const balanceWeiBig = await contract.deposits(address);
    const balanceWei = balanceWeiBig.toString();
    const balanceEth = ethers.formatEther(balanceWeiBig);

    res.json({
      address: address,
      balanceWei: balanceWei,
      balanceEth: balanceEth
    });
  } catch (err) {
    console.error("[API ERROR] GET /deposits/:address:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// 6. Query rollup global state (GET /state)
app.get("/state", async (req, res) => {
  try {
    const currentStateRoot = await contract.currentStateRoot();
    const batchCount = await contract.batchCount();

    res.json({
      currentStateRoot: currentStateRoot,
      batchCount: Number(batchCount),
      contractAddress: contractAddress
    });
  } catch (err) {
    console.error("[API ERROR] GET /state:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// Start Server after running migrations
const PORT = process.env.API_PORT || 4000;

runMigrations().then(() => {
  // Initialize indexer event listeners
  startIndexer();

  // Initialize relayer periodic batch processor
  startRelayer();

  app.listen(PORT, () => {
    console.log(`🚀 Server running on port ${PORT}`);
  });
});