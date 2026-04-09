// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";
import {I_RebaseToken} from "src/interfaces/I_RebaseToken.sol";
import {Vault} from "src/vault.sol";

contract TestVault is Test {
    address OWNER = makeAddr("owner");
    RebaseToken rtk;
    Vault vault;

    function setUp() public {
        vm.deal(OWNER, 10 ether);
        vm.startPrank(OWNER);
        rtk = new RebaseToken();
        vault = new Vault(I_RebaseToken(address(rtk)));
        rtk.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
        vm.deal(address(vault), 100 ether);
    }

    function testDeposit() public {
        vm.startPrank(OWNER);
        console.log("starting :", rtk.balanceOf(OWNER));
        vault.deposit{value: 1e18}();
        console.log("just  :", rtk.balanceOf(OWNER));
        vm.warp(block.timestamp + 100 hours);
        console.log("ending :", rtk.balanceOf(OWNER));
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(OWNER);
        console.log("starting :", rtk.balanceOf(OWNER));
        vault.deposit{value: 1e18}();
        console.log("before timeskip :", rtk.balanceOf(OWNER));
        vm.warp(block.timestamp + 1 hours);
        console.log("current (after timeskip): ", rtk.balanceOf(OWNER));
        // withdraw
        vault.reedem();
        console.log("after withdrawl bal:", rtk.balanceOf(OWNER));
        vm.stopPrank();
    }
}
