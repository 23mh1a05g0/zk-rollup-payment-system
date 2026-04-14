// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IZKVerifier.sol";

contract ZKRollupPayments is Ownable {

    address public verifier;
    bytes32 public currentStateRoot;
    uint256 public batchCount;

    mapping(uint256 => BatchRecord) public batches;
    mapping(address => uint256) public deposits;
    mapping(address => bool) private relayers;

    struct BatchRecord {
        bytes32 oldStateRoot;
        bytes32 newStateRoot;
        uint256 txCount;
        bytes32 batchHash;
        uint256 committedAt;
        address relayer;
    }

    event Deposited(address indexed user, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed user, uint256 amount);
    event BatchCommitted(
        uint256 indexed batchIndex,
        bytes32 newStateRoot,
        bytes32 batchHash,
        uint256 txCount,
        address relayer
    );

    modifier onlyRelayer() {
        require(relayers[msg.sender], "Not authorized relayer");
        _;
    }

    constructor(address _verifier) Ownable(msg.sender) {
    verifier = _verifier;
    relayers[msg.sender] = true;
    }

    // ---------------- USER FUNCTIONS ----------------

    function deposit() external payable {
        require(msg.value > 0, "Amount must be > 0");

        deposits[msg.sender] += msg.value;

        emit Deposited(msg.sender, msg.value, deposits[msg.sender]);
    }

    function withdraw(uint256 amount) external {
        require(deposits[msg.sender] >= amount, "ZKRollup: insufficient balance");

        deposits[msg.sender] -= amount;

        payable(msg.sender).transfer(amount);

        emit Withdrawn(msg.sender, amount);
    }

    // ---------------- RELAYER FUNCTION ----------------

    function commitBatch(
        bytes32 newStateRoot,
        bytes32 batchHash,
        uint256 txCount,
        bytes calldata proof,
        uint256[] calldata publicInputs
    ) external onlyRelayer {

        bool isValid = IZKVerifier(verifier).verifyProof(proof, publicInputs);
        require(isValid, "ZKRollup: invalid proof");

        bytes32 oldRoot = currentStateRoot;

        currentStateRoot = newStateRoot;

        batches[batchCount] = BatchRecord({
            oldStateRoot: oldRoot,
            newStateRoot: newStateRoot,
            txCount: txCount,
            batchHash: batchHash,
            committedAt: block.timestamp,
            relayer: msg.sender
        });

        emit BatchCommitted(batchCount, newStateRoot, batchHash, txCount, msg.sender);

        batchCount++;
    }

    // ---------------- ADMIN FUNCTIONS ----------------

    function addRelayer(address relayerAddr) external onlyOwner {
        relayers[relayerAddr] = true;
    }

    function removeRelayer(address relayerAddr) external onlyOwner {
        relayers[relayerAddr] = false;
    }

    function isRelayer(address relayerAddr) external view returns (bool) {
        return relayers[relayerAddr];
    }
}