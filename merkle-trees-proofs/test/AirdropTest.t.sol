// SPDX-License-Identifier : MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/test.sol";
import {AuraToken} from "src/AuraToken.sol";
import {MerkleAirdrop} from "src/MerkleAirdrop.sol";
import {DeployScript} from "script/Deploy.s.sol";

contract AirdropTest is Test {
    AuraToken tkn;
    MerkleAirdrop merkle;
    bytes32 root = 0xb1e815a99ee56f7043ed94e7e2316238187a59d85c211d06f9be7c5f94424aec;
    address user;
    uint256 userKey;
    address gasPayer;
    bytes32 proof1 = 0x9e10faf86d92c4c65f81ac54ef2a27cc0fdf6bfea6ba4b1df5955e47f187115b;
    bytes32 proof2 = 0x8c1fd7b608678f6dfced176fa3e3086954e8aa495613efcd312768d41338ceab;
    bytes32[] proofs = [proof1, proof2];

    function setUp() public {
        // tkn = new AuraToken();
        // merkle = new MerkleAirdrop(root, tkn);
        // user = 0x6CA6D1e2D5347bfaB1d91E883F1915560E891290;
        // tkn.mint(address(this), 10000 ether);
        // tkn.transfer(address(merkle), 1000 ether);

        (user, userKey) = makeAddrAndKey("user");
        gasPayer = makeAddr("gas");
        DeployScript deploy = new DeployScript();
        (merkle, tkn) = deploy.run();
    }

    function testDeploment() public {
        console.log("user add ", user);
        console.log("userKey add ", userKey);
        console.log("merkle bal : ", tkn.balanceOf(address(merkle)));
    }

    // function testAirdrop() public {
    //     vm.startPrank(user);
    //     uint256 startingBal = tkn.balanceOf(user);
    //     merkle.claim(user, 2500 ether, proofs);
    //     uint256 endingBal = tkn.balanceOf(user);
    //     console.log("starting bal : ", startingBal);
    //     console.log("ending bal : ", endingBal);
    //     vm.stopPrank();
    // }

    function testAirdropFromSignature() public {
        bytes32 hashedMessage = merkle.getMessageHash(user, 2500 ether);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, hashedMessage);
        vm.prank(gasPayer);
        merkle.claim(user, 2500 ether, proofs, v, r, s);
        console.log("user bal :", tkn.balanceOf(user));
    }
}
