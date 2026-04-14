// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "./interfaces/IZKVerifier.sol";

contract StubZKVerifier is IZKVerifier {
    function verifyProof(
        bytes calldata,
        uint256[] calldata
    ) external pure override returns (bool) {
        return true;
    }
}