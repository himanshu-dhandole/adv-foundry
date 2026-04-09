// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";

contract TestRebaseToken is Test {
    RebaseToken rtk;

    address owner = makeAddr("owner");
    address minter = makeAddr("minter");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant PRECISION_FACTOR = 1e18;
    uint256 constant INITIAL_INTEREST_RATE = 5e18;
    uint256 constant MINT_AMOUNT = 100e18;

    // ─────────────────────────────────────────────
    //  Setup
    // ─────────────────────────────────────────────

    function setUp() public {
        vm.prank(owner);
        rtk = new RebaseToken();

        // Grant minter the MINT_AND_BURN role
        vm.prank(owner);
        rtk.grantMintAndBurnRole(minter);
    }

    // ─────────────────────────────────────────────
    //  1. Deployment / Initial State
    // ─────────────────────────────────────────────

    function test_Deployment_NameAndSymbol() public view {
        assertEq(rtk.name(), "Rebase Token");
        assertEq(rtk.symbol(), "RTK");
    }

    function test_Deployment_InitialInterestRate() public view {
        assertEq(rtk.getCurrentIntrestRate(), INITIAL_INTEREST_RATE);
    }

    function test_Deployment_OwnerIsDeployer() public view {
        assertEq(rtk.owner(), owner);
    }

    function test_Deployment_TotalSupplyIsZero() public view {
        assertEq(rtk.totalSupply(), 0);
    }

    // ─────────────────────────────────────────────
    //  2. Access Control – grantMintAndBurnRole
    // ─────────────────────────────────────────────

    function test_GrantMintAndBurnRole_OnlyOwner() public {
        address stranger = makeAddr("stranger");
        vm.expectRevert();
        vm.prank(stranger);
        rtk.grantMintAndBurnRole(stranger);
    }

    function test_GrantMintAndBurnRole_OwnerCanGrant() public {
        address newMinter = makeAddr("newMinter");
        vm.prank(owner);
        rtk.grantMintAndBurnRole(newMinter);

        // newMinter should now be able to mint
        vm.prank(newMinter);
        rtk.mint(alice, MINT_AMOUNT);
        assertEq(rtk.balanceOf(alice), MINT_AMOUNT);
    }

    // ─────────────────────────────────────────────
    //  3. Minting
    // ─────────────────────────────────────────────

    function test_Mint_UnauthorizedReverts() public {
        vm.expectRevert();
        vm.prank(alice);
        rtk.mint(alice, MINT_AMOUNT);
    }

    function test_Mint_ZeroAmountReverts() public {
        vm.expectRevert(RebaseToken.RebaseToken__InvalidAmountSent.selector);
        vm.prank(minter);
        rtk.mint(alice, 0);
    }

    function test_Mint_CorrectBalanceAfterMint() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);
        assertEq(rtk.balanceOf(alice), MINT_AMOUNT);
    }

    function test_Mint_SetsUserInterestRate() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);
        assertEq(rtk.getIntrestRateToUser(alice), INITIAL_INTEREST_RATE);
    }

    function test_Mint_SetsLastUpdatedTimestamp() public {
        uint256 before = block.timestamp;
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);
        assertEq(rtk.getsLastUpdatedTimeStampToUser(alice), before);
    }

    function test_Mint_FuzzAmount(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);
        vm.prank(minter);
        rtk.mint(alice, amount);
        assertEq(rtk.balanceOf(alice), amount);
    }

    // ─────────────────────────────────────────────
    //  4. Interest Accrual (balanceOf grows over time)
    // ─────────────────────────────────────────────

    function test_BalanceOf_GrowsWithTime() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        uint256 balanceAtMint = rtk.balanceOf(alice);

        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);

        uint256 balanceAfter = rtk.balanceOf(alice);
        assertGt(balanceAfter, balanceAtMint, "Balance should grow over time");
    }

    function test_BalanceOf_LinearGrowthFormula() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        uint256 timeElapsed = 1000; // seconds
        vm.warp(block.timestamp + timeElapsed);

        uint256 expectedGrowthFactor = PRECISION_FACTOR + (timeElapsed * INITIAL_INTEREST_RATE);
        uint256 expectedBalance = MINT_AMOUNT * expectedGrowthFactor / PRECISION_FACTOR;
        assertEq(rtk.balanceOf(alice), expectedBalance);
    }

    function test_BalanceOf_NoGrowthForFreshAddress() public view {
        // An address with no interaction should have 0 balance
        assertEq(rtk.balanceOf(alice), 0);
    }

    // ─────────────────────────────────────────────
    //  5. Interest Settlement on mint (second mint)
    // ─────────────────────────────────────────────

    function test_SecondMint_SettlesPreviousInterest() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.warp(block.timestamp + 365 days);

        uint256 accruedBalance = rtk.balanceOf(alice);

        // Second mint – interest should be settled first
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        // Principal should now include the accrued interest + new mint
        uint256 principalAfter = rtk.getPrincipalAmount(alice);
        assertEq(principalAfter, accruedBalance + MINT_AMOUNT);
    }

    // ─────────────────────────────────────────────
    //  6. Burning
    // ─────────────────────────────────────────────

    function test_Burn_UnauthorizedReverts() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.expectRevert();
        vm.prank(alice);
        rtk.burn(alice, MINT_AMOUNT);
    }

    function test_Burn_ZeroAmountReverts() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.expectRevert(RebaseToken.RebaseToken__InvalidAmountSent.selector);
        vm.prank(minter);
        rtk.burn(alice, 0);
    }

    function test_Burn_PartialAmount() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        uint256 burnAmount = 40e18;
        vm.prank(minter);
        rtk.burn(alice, burnAmount);

        assertEq(rtk.balanceOf(alice), MINT_AMOUNT - burnAmount);
    }

    function test_Burn_MaxUint256_BurnsEntireBalance() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        // Advance time so interest accrues
        vm.warp(block.timestamp + 100 days);

        vm.prank(minter);
        rtk.burn(alice, type(uint256).max);

        assertEq(rtk.balanceOf(alice), 0);
    }

    function test_Burn_SettlesPreviousInterestBeforeBurn() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.warp(block.timestamp + 365 days);

        uint256 accruedBal = rtk.balanceOf(alice);

        vm.prank(minter);
        rtk.burn(alice, accruedBal);

        assertEq(rtk.balanceOf(alice), 0);
    }

    // ─────────────────────────────────────────────
    //  7. setIntrestRate
    // ─────────────────────────────────────────────

    function test_SetInterestRate_OnlyOwnerCanSet() public {
        vm.expectRevert();
        vm.prank(alice);
        rtk.setIntrestRate(1e18);
    }

    function test_SetInterestRate_CanDecreaseRate() public {
        uint256 newRate = 3e18;
        vm.prank(owner);
        rtk.setIntrestRate(newRate);
        assertEq(rtk.getCurrentIntrestRate(), newRate);
    }

    function test_SetInterestRate_CannotIncrease() public {
        uint256 higherRate = INITIAL_INTEREST_RATE + 1;
        vm.expectRevert(
            abi.encodeWithSelector(RebaseToken.RebaseToken__NewIntrestRateCannotIncrease.selector, higherRate)
        );
        vm.prank(owner);
        rtk.setIntrestRate(higherRate);
    }

    function test_SetInterestRate_EmitsEvent() public {
        uint256 newRate = 2e18;
        vm.expectEmit(true, false, false, true);
        emit RebaseToken.IntrestRateUpdated(newRate);
        vm.prank(owner);
        rtk.setIntrestRate(newRate);
    }

    function test_SetInterestRate_NewMintersGetLowerRate() public {
        // Mint for alice at initial rate
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);
        assertEq(rtk.getIntrestRateToUser(alice), INITIAL_INTEREST_RATE);

        // Owner reduces rate
        uint256 lowerRate = 2e18;
        vm.prank(owner);
        rtk.setIntrestRate(lowerRate);

        // Mint for bob after rate change
        vm.prank(minter);
        rtk.mint(bob, MINT_AMOUNT);
        assertEq(rtk.getIntrestRateToUser(bob), lowerRate);

        // Alice still keeps her original rate locked in
        assertEq(rtk.getIntrestRateToUser(alice), INITIAL_INTEREST_RATE);
    }

    // ─────────────────────────────────────────────
    //  8. transfer
    // ─────────────────────────────────────────────

    function test_Transfer_CorrectAmounts() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        uint256 transferAmount = 30e18;
        vm.prank(alice);
        rtk.transfer(bob, transferAmount);

        assertEq(rtk.balanceOf(alice), MINT_AMOUNT - transferAmount);
        assertEq(rtk.balanceOf(bob), transferAmount);
    }

    function test_Transfer_RecipientInheritsInterestRateIfUnset() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.prank(alice);
        rtk.transfer(bob, 10e18);

        // Bob had no prior rate, so he should inherit alice's rate
        assertEq(rtk.getIntrestRateToUser(bob), INITIAL_INTEREST_RATE);
    }

    function test_Transfer_MaxUint256_TransfersFullBalance() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.warp(block.timestamp + 100 days);

        uint256 aliceBalBefore = rtk.balanceOf(alice);

        vm.prank(alice);
        rtk.transfer(bob, type(uint256).max);

        assertEq(rtk.balanceOf(alice), 0);
        assertEq(rtk.balanceOf(bob), aliceBalBefore);
    }

    function test_Transfer_SettlesInterestForBothParties() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.prank(minter);
        rtk.mint(bob, MINT_AMOUNT);

        vm.warp(block.timestamp + 200 days);

        // Both should have accrued interest before transfer
        uint256 aliceBefore = rtk.balanceOf(alice);
        uint256 bobBefore = rtk.balanceOf(bob);
        assertGt(aliceBefore, MINT_AMOUNT);
        assertGt(bobBefore, MINT_AMOUNT);

        uint256 transferAmount = aliceBefore / 2;
        vm.prank(alice);
        rtk.transfer(bob, transferAmount);

        // After transfer alice's balance should be ~half
        assertApproxEqAbs(rtk.balanceOf(alice), aliceBefore - transferAmount, 1);
    }

    // ─────────────────────────────────────────────
    //  9. transferFrom
    // ─────────────────────────────────────────────

    function test_TransferFrom_CorrectAmountsAndAllowance() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        uint256 transferAmount = 50e18;
        vm.prank(alice);
        rtk.approve(bob, transferAmount);

        vm.prank(bob);
        rtk.transferFrom(alice, bob, transferAmount);

        assertEq(rtk.balanceOf(alice), MINT_AMOUNT - transferAmount);
        assertEq(rtk.balanceOf(bob), transferAmount);
    }

    function test_TransferFrom_MaxUint256_TransfersFullBalance() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.warp(block.timestamp + 50 days);

        uint256 aliceBal = rtk.balanceOf(alice);

        vm.prank(alice);
        rtk.approve(bob, type(uint256).max);

        vm.prank(bob);
        rtk.transferFrom(alice, bob, type(uint256).max);

        assertEq(rtk.balanceOf(alice), 0);
        assertEq(rtk.balanceOf(bob), aliceBal);
    }

    function test_TransferFrom_RecipientInheritsInterestRateIfUnset() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        vm.prank(alice);
        rtk.approve(bob, MINT_AMOUNT);

        vm.prank(bob);
        rtk.transferFrom(alice, bob, 10e18);

        assertEq(rtk.getIntrestRateToUser(bob), INITIAL_INTEREST_RATE);
    }

    // ─────────────────────────────────────────────
    //  10. View / Getter Functions
    // ─────────────────────────────────────────────

    function test_GetPrincipalAmount_ReflectsStoredBalance() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);

        // Immediately after mint principal == MINT_AMOUNT
        assertEq(rtk.getPrincipalAmount(alice), MINT_AMOUNT);

        // After time passes balanceOf grows but principalAmount stays the same
        vm.warp(block.timestamp + 365 days);
        assertEq(rtk.getPrincipalAmount(alice), MINT_AMOUNT);
        assertGt(rtk.balanceOf(alice), MINT_AMOUNT);
    }

    function test_GetLastUpdatedTimestamp_UpdatesOnMint() public {
        vm.prank(minter);
        rtk.mint(alice, MINT_AMOUNT);
        assertEq(rtk.getsLastUpdatedTimeStampToUser(alice), block.timestamp);
    }
}
