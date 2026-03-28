// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { StableCoin } from "src/StableCoin.sol";

contract StableCoinTest is Test {
    StableCoin public stableCoin;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.prank(owner);
        stableCoin = new StableCoin();
    }

    ///////////////////////////////////
    //           MINT TESTS          //
    ///////////////////////////////////

    function test_MintSuccessfully() public {
        vm.prank(owner);
        bool success = stableCoin.mint(user, 100 ether);

        assertTrue(success);
        assertEq(stableCoin.balanceOf(user), 100 ether);
    }

    function test_MintRevertsIfAmountIsZero() public {
        vm.prank(owner);
        vm.expectRevert(StableCoin.StableCoin__AmountCannotBeZero.selector);
        stableCoin.mint(user, 0);
    }

    function test_MintRevertsIfNotOwner() public {
        vm.prank(user);
        vm.expectRevert();
        stableCoin.mint(user, 100 ether);
    }

    function test_MintRevertsIfToAddressIsZero() public {
        vm.prank(owner);
        vm.expectRevert(StableCoin.StableCoin__CannotMintToAddressZero.selector);
        stableCoin.mint(address(0), 100 ether);
    }

    ///////////////////////////////////
    //           BURN TESTS          //
    ///////////////////////////////////

    function test_BurnSuccessfully() public {
        vm.startPrank(owner);
        stableCoin.mint(owner, 100 ether);
        stableCoin.burn(50 ether);
        vm.stopPrank();

        assertEq(stableCoin.balanceOf(owner), 50 ether);
    }

    function test_BurnRevertsIfAmountIsZero() public {
        vm.startPrank(owner);
        stableCoin.mint(owner, 100 ether);
        vm.expectRevert(StableCoin.StableCoin__AmountCannotBeZero.selector);
        stableCoin.burn(0);
        vm.stopPrank();
    }

    function test_BurnRevertsIfNotOwner() public {
        vm.prank(owner);
        stableCoin.mint(user, 100 ether);

        vm.prank(user);
        vm.expectRevert();
        stableCoin.burn(50 ether);
    }

    function test_BurnRevertsIfAmountExceedsBalance() public {
        vm.startPrank(owner);
        stableCoin.mint(owner, 100 ether);
        vm.expectRevert(StableCoin.StableCoin__BurnAmountExceedsBalance.selector);
        stableCoin.burn(110 ether);
        vm.stopPrank();
    }
}
