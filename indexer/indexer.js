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

const abi = [
  "event Deposit(address indexed user, uint256 amount)"
];

const contract = new ethers.Contract(
  process.env.CONTRACT_ADDRESS,
  abi,
  provider
);

console.log("📡 Indexer started...");

// Listen event
contract.on("Deposit", async (user, amount) => {
  try {
    console.log("💰 Deposit detected:", user, amount.toString());

    await pool.query(
      `INSERT INTO deposits (user_address, amount_wei)
       VALUES ($1, $2)`,
      [user, amount.toString()]
    );

    console.log("✅ Stored in DB");
  } catch (err) {
    console.error("❌ Indexer error:", err.message);
  }
});