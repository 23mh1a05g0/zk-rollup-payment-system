const { ethers } = require("ethers");

// Local Hardhat node
const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");

// Use first account private key (from Hardhat node)
const wallet = new ethers.Wallet(
  "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
  provider
);

// Contract ABI (minimal)
const contractABI = [
  "function commitBatch(bytes32 newStateRoot, bytes32 batchHash, uint256 txCount, bytes proof, uint256[] publicInputs) external"
];

// Replace with your deployed contract address
const CONTRACT_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

const contract = new ethers.Contract(CONTRACT_ADDRESS, contractABI, wallet);

module.exports = contract;