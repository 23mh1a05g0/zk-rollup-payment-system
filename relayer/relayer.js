require("dotenv").config();
const { ethers } = require("ethers");
const { Pool } = require("pg");

// DB
const pool = new Pool({
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
});

// Blockchain
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

const abi = [
  "function commitBatch(bytes32, bytes32, uint256, bytes, uint256[])"
];

const contract = new ethers.Contract(
  process.env.CONTRACT_ADDRESS,
  abi,
  wallet
);

// MAIN LOOP
async function runRelayer() {
  console.log("Relayer running...");

  setInterval(async () => {
    try {
      const res = await pool.query(
        "SELECT * FROM batches WHERE committed = false LIMIT 1"
      );

      if (res.rows.length === 0) {
        console.log("No batches to process");
        return;
      }

      const batch = res.rows[0];

      console.log("Processing batch:", batch.id);

      const tx = await contract.commitBatch(
        batch.new_state_root,
        batch.batch_hash,
        batch.tx_count,
        "0x1234",
        []
      );

      await tx.wait();

      await pool.query(
        "UPDATE batches SET committed = true WHERE id = $1",
        [batch.id]
      );

      console.log("Batch committed:", tx.hash);
    } catch (err) {
      console.error("Relayer error:", err.message);
    }
  }, 5000);
}

runRelayer();