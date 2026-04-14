# 🚀 ZK-Rollup Payment System

A full-stack blockchain-based payment system demonstrating **ZK-Rollup architecture**, built using Flutter, Node.js, Solidity, and PostgreSQL.

---

## 📌 Overview

This project implements a simplified **ZK-Rollup payment system** where multiple transactions are processed off-chain, batched together, and committed to the blockchain efficiently.

It includes:
- Smart contracts for rollup logic
- Backend APIs for transaction handling
- PostgreSQL database for indexing
- Relayer service for blockchain interaction
- Indexer for event tracking
- Flutter-based wallet UI

---

## 🧠 Architecture
Flutter App
↓
Backend (Express.js)
↓
PostgreSQL Database
↓
Relayer Service → Blockchain (Hardhat)
↓
Indexer Service
↓
Database


---

## 🛠️ Tech Stack

## Frontend
- Flutter (Dart)

## Backend
- Node.js
- Express.js

## Blockchain
- Solidity
- Hardhat

## Database
- PostgreSQL

## Web3 Integration
- Ethers.js
- web3dart (Flutter)

## DevOps
- Docker (optional)

---

## ✨ Features

## 🔹 Payment System
- Create payment intents
- View transaction history

## 🔹 Rollup Mechanism
- Batch multiple transactions
- Reduce on-chain gas cost

## 🔹 Relayer Service
- Automatically commits batches to blockchain

## 🔹 Indexer
- Listens to blockchain events
- Stores deposits in database

## 🔹 Smart Contracts
- Deposit functionality
- Batch commit logic
- ZK verifier (stub)

## 🔹 Flutter Wallet
- Send payments
- View transactions
- Batch creation & commit

---

## ⚙️ Setup Instructions

## 1️⃣ Clone Repository

```bash
git clone https://github.com/23mh1a05g0/zk-rollup-payment-system.git
cd zk-rollup-payment-system

```

## 2️⃣ Install Dependencies
# Backend
cd backend
npm install
# Relayer
cd ../relayer
npm install
# Indexer
cd ../indexer
npm install

## 3️⃣ Start Blockchain
npx hardhat node

## 4️⃣ Deploy Contracts
npx hardhat run scripts/deploy.js --network localhost

## 5️⃣ Setup Database (Docker)
docker run -d --name zk-postgres \
-e POSTGRES_USER=postgres \
-e POSTGRES_PASSWORD=postgres \
-e POSTGRES_DB=zkrollup \
-p 5433:5432 postgres:15

## 6️⃣ Run Backend
cd backend
npx nodemon src/server.js

## 7️⃣ Run Relayer
cd ../relayer
node relayer.js

## 8️⃣ Run Indexer
cd ../indexer
node indexer.js

## 9️⃣ Run Flutter App
flutter run
🔌 API Endpoints
Create Payment Intent
POST /intents
Get All Intents
GET /intents
Create Batch
POST /batches/create
Commit Batch
POST /batches/commit
🗄️ Database Schema

## payment_intents
id
from_address
to_address
amount_wei
status
batch_id
batches
id
batch_index
new_state_root
batch_hash
tx_count
committed
deposits
id
user_address
amount_wei
created_at

## 🧪 Testing Flow
Create payment via Flutter
Create batch via API/UI
Relayer commits batch automatically
Indexer listens to blockchain events
Data stored in PostgreSQL