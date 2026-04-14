// SPDX-License-Identifier : MIT
pragma solidity ^0.8.24;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    using SafeERC20 for IERC20;
    // event
    event Claimed(address indexed account, uint256 indexed amount);

    //error
    error MerkleAirdrop__ProofInvalid();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__SignatureInvalid();

    // state variables
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    address[] private claimers;
    mapping(address => bool) private s_hasClaimed;

    struct AirdropClaimer {
        address account;
        uint256 amount;
    }

    bytes32 constant TYPE_HASH = keccak256("AirdropClaimer(address account ,uint256 amount)");

    constructor(bytes32 _merkleRoot, IERC20 _airdropToken) EIP712("MerkleAirdrop", "1") {
        i_merkleRoot = _merkleRoot;
        i_airdropToken = _airdropToken;
    }

    function claim(address _account, uint256 _amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (s_hasClaimed[_account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }

        bytes32 digest = getMessageHash(_account, _amount);

        if (!_isValidSigature(_account, digest, v, r, s)) {
            revert MerkleAirdrop__SignatureInvalid();
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_account, _amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__ProofInvalid();
        }
        s_hasClaimed[_account] = true;
        emit Claimed(_account, _amount);

        i_airdropToken.safeTransfer(_account, _amount);
    }

    function getMessageHash(address _account, uint256 _amount) public returns (bytes32) {
        bytes32 structHash = keccak256(abi.encode(TYPE_HASH, AirdropClaimer({account: _account, amount: _amount})));

        return _hashTypedDataV4(structHash);
    }

    function _isValidSigature(address _expectedSigner, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        if (actualSigner != address(0) && actualSigner == _expectedSigner) {
            return true;
        }
        return false;
    }
}
