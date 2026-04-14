// SPDX-Licanse-Identifier :MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AuraToken} from "src/AuraToken.sol";
import {MerkleAirdrop} from "src/MerkleAirdrop.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract Interact is Script {
    error InteractionScript__SignatureInvalid();

    bytes32 proof1 = 0x9e10faf86d92c4c65f81ac54ef2a27cc0fdf6bfea6ba4b1df5955e47f187115b;
    bytes32 proof2 = 0x8c1fd7b608678f6dfced176fa3e3086954e8aa495613efcd312768d41338ceab;
    bytes32[] proofs = [proof1, proof2];
    address claimingAdd = 0x2a3D206626337FcAC4C5Cfc0f9fBe18F9D900f47;
    uint256 amount = 2500 ether;
    bytes private signedMessage =
        hex"1609c8de9db0f5045a4e333c0e6369edf9e5ac80e9ce6db03e10fd32bd02018a5dab5dcf6aad040928bb33b460b99820608594876d9c5db8d2b6780c1f9ebc861b";

    function claimAirdrop(address _merkleAirdrop, address _tokenAddress) public {
        (uint8 v, bytes32 r, bytes32 s) = _SplitSignedMessage(signedMessage);
        vm.startBroadcast();
        uint256 balanceOfMe_starting = AuraToken(_tokenAddress).balanceOf(0x2a3D206626337FcAC4C5Cfc0f9fBe18F9D900f47);
        MerkleAirdrop(_merkleAirdrop).claim(claimingAdd, amount, proofs, v, r, s);
        uint256 balanceOfMe = AuraToken(_tokenAddress).balanceOf(0x2a3D206626337FcAC4C5Cfc0f9fBe18F9D900f47);
        vm.stopBroadcast();
        console.log("balance of me starting : ", balanceOfMe_starting);
        console.log("balance of me : ", balanceOfMe);
    }

    function _SplitSignedMessage(bytes memory _signedMessage) internal returns (uint8 v, bytes32 r, bytes32 s) {
        if (_signedMessage.length != 65) {
            revert InteractionScript__SignatureInvalid();
        }
        assembly {
            r := mload(add(_signedMessage, 0x20))
            s := mload(add(_signedMessage, 0x40))
            v := byte(0, mload(add(_signedMessage, 0x60)))
        }
    }

    function run() public {
        address latestDeployment = DevOpsTools.get_most_recent_deployment("MerkleAirdrop", block.chainid);
        address latest_Token_Deployment = DevOpsTools.get_most_recent_deployment("AuraToken", block.chainid);
        claimAirdrop(latestDeployment, latest_Token_Deployment);
    }
}
