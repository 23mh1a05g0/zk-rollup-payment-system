const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");
const http = require("http");
require("dotenv").config();

// Helper HTTP functions to avoid external dependencies
function httpGet(url) {
  return new Promise((resolve, reject) => {
    http.get(url, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        try {
          resolve({
            status: res.statusCode,
            body: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            body: data
          });
        }
      });
    }).on("error", reject);
  });
}

function httpPost(url, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const postData = JSON.stringify(body);
    const options = {
      hostname: u.hostname,
      port: u.port || (u.protocol === "https:" ? 443 : 80),
      path: u.pathname + u.search,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData)
      }
    };
    const req = http.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        try {
          resolve({
            status: res.statusCode,
            body: JSON.parse(data)
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            body: data
          });
        }
      });
    });
    req.on("error", reject);
    req.write(postData);
    req.end();
  });
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));

async function main() {
  console.log("🚀 Starting End-to-End Validation...");

  const results = [];
  let passedCount = 0;
  let failedCount = 0;

  function recordResult(testName, success, detail) {
    if (success) passedCount++;
    else failedCount++;
    results.push({
      test: testName,
      status: success ? "pass" : "fail",
      detail: detail
    });
    console.log(`${success ? "✅ PASS" : "❌ FAIL"}: ${testName} - ${detail}`);
  }

  // 1. Setup Providers & Wallets
  let rpcUrl = process.env.RPC_URL || "http://127.0.0.1:8545";
  let rollupAddress;

  try {
    const addressesPath = path.join(__dirname, "../deployments/addresses.json");
    if (fs.existsSync(addressesPath)) {
      const addresses = JSON.parse(fs.readFileSync(addressesPath, "utf8"));
      rollupAddress = addresses.ZKRollupPayments;
      // Use Docker internal RPC if running inside docker, else host
      if (process.env.POSTGRES_HOST === "postgres") {
        rpcUrl = "http://hardhat:8545";
      }
    }
  } catch (err) {
    console.log("Could not load deploy address config", err.message);
  }

  if (!rollupAddress) {
    rollupAddress = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";
  }

  console.log(`Connecting to provider at: ${rpcUrl}`);
  const provider = new ethers.providers.JsonRpcProvider(rpcUrl);

  const userAPrivateKey = process.env.USER_A_PRIVATE_KEY || "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
  const userAAddress = process.env.USER_A_ADDRESS || "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
  const userBAddress = process.env.USER_B_ADDRESS || "0x3C44CdDdb6a900fa2b585dd299e03d12FA4293BC";

  const walletA = new ethers.Wallet(userAPrivateKey, provider);

  const abi = [
    "function deposit() external payable",
    "function deposits(address) external view returns (uint256)"
  ];
  const contract = new ethers.Contract(rollupAddress, abi, walletA);

  const apiPort = process.env.API_PORT || 4000;
  const apiBase = `http://localhost:${apiPort}`;

  // ---------------- TEST 1: On-Chain Deposit ----------------
  try {
    console.log(`Depositing 0.5 ETH from USER_A (${userAAddress})...`);
    const parseEther = ethers.utils ? ethers.utils.parseEther : ethers.parseEther;
    const tx = await contract.deposit({ value: parseEther("0.5") });
    const receipt = await tx.wait();
    
    recordResult(
      "Deposit ETH On-Chain",
      receipt.status === 1,
      `Deposited 0.5 ETH, tx: ${receipt.transactionHash}`
    );
  } catch (err) {
    recordResult("Deposit ETH On-Chain", false, `Failed: ${err.message}`);
  }

  // ---------------- TEST 2: Indexer tracks deposit ----------------
  try {
    console.log("Waiting for indexer to index the deposit...");
    let indexed = false;
    let balanceObj;
    for (let i = 0; i < 15; i++) {
      await sleep(2000);
      try {
        const res = await httpGet(`${apiBase}/deposits/${userAAddress}`);
        if (res.status === 200) {
          balanceObj = res.body;
          const bal = BigInt(balanceObj.balanceWei);
          if (bal >= 500000000000000000n) {
            indexed = true;
            break;
          }
        }
      } catch (err) {
        // retry
      }
    }
    
    recordResult(
      "Indexer Deposit Sync",
      indexed,
      indexed
        ? `Deposit balance tracked successfully: ${balanceObj.balanceEth} ETH (${balanceObj.balanceWei} wei)`
        : `Deposit balance not tracked. Last balance: ${balanceObj ? balanceObj.balanceWei : "none"}`
    );
  } catch (err) {
    recordResult("Indexer Deposit Sync", false, `Failed: ${err.message}`);
  }

  // ---------------- TEST 3: Submit Valid Intent ----------------
  let validIntentId;
  try {
    console.log("Submitting valid intent (0.1 ETH)...");
    const res = await httpPost(`${apiBase}/intents`, {
      fromAddress: userAAddress,
      toAddress: userBAddress,
      amountWei: "100000000000000000" // 0.1 ETH
    });

    const is2xx = res.status >= 200 && res.status < 300;
    validIntentId = res.body?.intentId;

    recordResult(
      "Submit Valid Intent",
      is2xx && !!validIntentId,
      is2xx ? `Success: Status code ${res.status}, Intent ID: ${validIntentId}` : `Failed: Status code ${res.status}`
    );
  } catch (err) {
    recordResult("Submit Valid Intent", false, `Failed: ${err.message}`);
  }

  // ---------------- TEST 4: Submit Invalid Intent ----------------
  try {
    console.log("Submitting invalid intent (999 ETH)...");
    const res = await httpPost(`${apiBase}/intents`, {
      fromAddress: userAAddress,
      toAddress: userBAddress,
      amountWei: "999000000000000000000" // 999 ETH (more than deposit)
    });

    const is400 = res.status === 400;
    const hasErrorMsg = res.body?.error === "Insufficient on-chain deposit";

    recordResult(
      "Submit Invalid Intent",
      is400 && hasErrorMsg,
      `Asserted status 400 and error message: status=${res.status}, error="${res.body?.error}"`
    );
  } catch (err) {
    recordResult("Submit Invalid Intent", false, `Failed: ${err.message}`);
  }

  // ---------------- TEST 5: Poll Relayer for Batch Commit ----------------
  try {
    console.log("Waiting for relayer to process batch...");
    let processed = false;
    let finalState;
    for (let i = 0; i < 20; i++) {
      await sleep(2000);
      try {
        const stateRes = await httpGet(`${apiBase}/state`);
        const intentsRes = await httpGet(`${apiBase}/intents?status=batched`);
        
        finalState = stateRes.body;
        const intents = intentsRes.body?.intents || [];
        
        const hasBatchedIntent = intents.some(i => i.id === validIntentId);
        
        if (finalState && finalState.batchCount >= 1) {
          processed = true;
          break;
        }
      } catch (err) {
        // retry
      }
    }

    recordResult(
      "Relayer Batch Processing",
      processed,
      processed
        ? `Batch successfully committed. Count: ${finalState?.batchCount}, Root: ${finalState?.currentStateRoot}`
        : `Batch count did not increase. Last state: ${JSON.stringify(finalState)}`
    );
  } catch (err) {
    recordResult("Relayer Batch Processing", false, `Failed: ${err.message}`);
  }

  // ---------------- TEST 6: Verify Batches Endpoint ----------------
  try {
    console.log("Verifying batches listing endpoint...");
    const res = await httpGet(`${apiBase}/batches`);
    const batches = res.body?.batches || [];
    
    recordResult(
      "Verify Batches List",
      batches.length > 0,
      `Found ${batches.length} committed batches via API`
    );
  } catch (err) {
    recordResult("Verify Batches List", false, `Failed: ${err.message}`);
  }

  // ---------------- Generate Report ----------------
  const report = {
    passed: passedCount,
    failed: failedCount,
    results: results
  };

  fs.writeFileSync(
    path.join(__dirname, "../validation_report.json"),
    JSON.stringify(report, null, 2)
  );

  console.log(`\n======================================`);
  console.log(`E2E Validation Completed: ${passedCount} Passed, ${failedCount} Failed`);
  console.log(`======================================`);

  process.exit(failedCount > 0 ? 1 : 0);
}

main().catch(err => {
  console.error("Fatal error during validation:", err);
  process.exit(1);
});
