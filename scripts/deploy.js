const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying with account:", deployer.address);

  // Deploy Verifier
  const Verifier = await ethers.getContractFactory("StubZKVerifier");
  const verifier = await Verifier.deploy();
  await verifier.deployed();

  console.log("Verifier deployed:", verifier.address);

  // Deploy Rollup
  const Rollup = await ethers.getContractFactory("ZKRollupPayments");
  const rollup = await Rollup.deploy(verifier.address);
  await rollup.deployed();

  console.log("Rollup deployed:", rollup.address);

  // Save addresses
  const data = {
    network: "localhost",
    chainId: 31337,
    rpcUrl: "http://127.0.0.1:8545",
    ZKRollupPayments: rollup.address,
    StubZKVerifier: verifier.address,
    deployedAt: new Date().toISOString(),
  };

  fs.writeFileSync("./deployments/addresses.json", JSON.stringify(data, null, 2));

  console.log("Deployment saved ✅");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});