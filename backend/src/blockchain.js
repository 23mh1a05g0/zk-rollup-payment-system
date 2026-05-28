const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
require("dotenv").config();

// Load deployed address
let contractAddress = process.env.CONTRACT_ADDRESS;
let rpcUrl = process.env.RPC_URL || "http://127.0.0.1:8545";

try {
  const addressesPath = path.join(__dirname, "../../deployments/addresses.json");
  if (fs.existsSync(addressesPath)) {
    const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));
    if (!contractAddress && addresses.ZKRollupPayments) {
      contractAddress = addresses.ZKRollupPayments;
    }
    // Fallback RPC URL inside docker might use hardhat name
    if (!process.env.RPC_URL && addresses.rpcUrl) {
      // If we are running inside docker backend container, we want http://hardhat:8545
      // If we are on localhost, we might want http://127.0.0.1:8545. Let's decide based on host name
      if (process.env.POSTGRES_HOST === "postgres") {
        rpcUrl = "http://hardhat:8545";
      } else {
        rpcUrl = "http://127.0.0.1:8545";
      }
    }
  }
} catch (err) {
  console.log("Could not load deployments/addresses.json, using environment variables.", err.message);
}

if (!contractAddress) {
  contractAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"; // fallback default
}

console.log(`[BLOCKCHAIN] Connecting to RPC: ${rpcUrl}`);
console.log(`[BLOCKCHAIN] Using Contract Address: ${contractAddress}`);

const provider = new ethers.JsonRpcProvider(rpcUrl);

// Relayer Wallet
const relayerPrivateKey = process.env.RELAYER_PRIVATE_KEY || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
const wallet = new ethers.Wallet(relayerPrivateKey, provider);

const contractABI = [
  "function deposit() external payable",
  "function withdraw(uint256 amount) external",
  "function commitBatch(bytes32 newStateRoot, bytes32 batchHash, uint256 txCount, bytes proof, uint256[] publicInputs) external",
  "function addRelayer(address relayer) external",
  "function removeRelayer(address relayer) external",
  "function isRelayer(address relayer) external view returns (bool)",
  "function verifier() external view returns (address)",
  "function currentStateRoot() external view returns (bytes32)",
  "function batchCount() external view returns (uint256)",
  "function batches(uint256) external view returns (bytes32 oldStateRoot, bytes32 newStateRoot, uint256 txCount, bytes32 batchHash, uint256 committedAt, address relayer)",
  "function deposits(address) external view returns (uint256)",
  
  "event Deposited(address indexed user, uint256 amount, uint256 newBalance)",
  "event Withdrawn(address indexed user, uint256 amount)",
  "event BatchCommitted(uint256 indexed batchIndex, bytes32 newStateRoot, bytes32 batchHash, uint256 txCount, address relayer)"
];

const contract = new ethers.Contract(contractAddress, contractABI, wallet);

module.exports = {
  provider,
  wallet,
  contract,
  contractAddress,
  contractABI
};