// SPDX-License-Identifier : MIT
pragma solidity ^0.8.24;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MerkleAirdrop {
    using SafeERC20 for IERC20;
    // event
    event Claimed(address indexed account, uint256 indexed amount);

    //error
    error MerkleAirdrop__ProofInvalid();

    // state variables
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    address[] private claimers;

    constructor(bytes32 _merkleRoot, IERC20 _airdropToken) {
        i_merkleRoot = _merkleRoot;
        i_airdropToken = _airdropToken;
    }

    function claim(address _account, uint256 _amount, bytes32[] calldata merkleProof) external {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_account, _amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__ProofInvalid();
        }
        emit Claimed(_account, _amount);

        i_airdropToken.safeTransfer(_account, _amount);
    }
}
