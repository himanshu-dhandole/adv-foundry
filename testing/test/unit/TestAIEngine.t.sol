// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test, console } from "forge-std/Test.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { StableCoin } from "src/StableCoin.sol";
import { StableCoinEngine } from "src/StableCoinEngine.sol";
import { DeployStableCoin } from "script/Deploy.s.sol";
import { ERC20Mock } from "test/mocks/MockERC20.sol";
import { MockV3Aggregator } from "test/mocks/MockV3Aggregator.sol";

contract TestAiEngine is Test {
    HelperConfig config;
    StableCoin drs;
    StableCoinEngine scEngine;
    
    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    
    address wETH;
    address wBTC;
    address wETH_priceFeed;
    address wBTC_priceFeed;

    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // 10 WETH
    uint256 public constant STARTING_USER_BALANCE = 100 ether; // 100 WETH

    function setUp() public {
        DeployStableCoin deployer = new DeployStableCoin();
        (drs, scEngine, config) = deployer.run();
        (wETH, wBTC, wETH_priceFeed, wBTC_priceFeed,) = config.activeNetworkConfig();

        // Give mocked tokens to user and liquidator
        ERC20Mock(wETH).mint(USER, STARTING_USER_BALANCE);
        ERC20Mock(wBTC).mint(USER, STARTING_USER_BALANCE);
        
        ERC20Mock(wETH).mint(LIQUIDATOR, STARTING_USER_BALANCE);
        ERC20Mock(wBTC).mint(LIQUIDATOR, STARTING_USER_BALANCE);
    }

    ///////////////////////////////////////
    // End-to-End Healthy Scenario Tests //
    ///////////////////////////////////////

    // 1. A complete lifecycle of an average healthy user (Deposit, Mint, Burn, Redeem)
    function testHealthyUserCompleteLifecycle() public {
        vm.startPrank(USER);
        
        // 1. Deposit 2 WETH (value $4000)
        ERC20Mock(wETH).approve(address(scEngine), 2 ether);
        scEngine.depositCollateral(wETH, 2 ether);
        
        // 2. Mint 1000 DRS (health factor will be 2.0)
        scEngine.mintDRS(1000 ether);
        
        uint256 userDrsBalance = scEngine.getDrsMinted(USER);
        assertEq(userDrsBalance, 1000 ether);
        assertEq(scEngine.getHealthFactor(USER), 2 ether); // 2.0 (1e18 * 2)

        // 3. User tries to withdraw 1 WETH while keeping 1000 DRS debt.
        // Left collateral: 1 WETH = $2000. 50% threshold = $1000. Debt = $1000.
        // HF = 1.0, which is perfectly valid (>= MINIMUM_HEALTH_FACTOR).
        scEngine.reedemCollateral(wETH, 1 ether);
        
        assertEq(scEngine.getCollateralBalanceOfUser(USER, wETH), 1 ether);
        assertEq(scEngine.getHealthFactor(USER), 1 ether); // 1.0 (1e18)

        // 4. User partially burns DRS (turns 1000 DRS to 500 DRS)
        drs.approve(address(scEngine), 500 ether);
        scEngine.burnDRS(500 ether);
        userDrsBalance = scEngine.getDrsMinted(USER);
        assertEq(userDrsBalance, 500 ether);

        // 5. User wants to burn the rest of DRS and redeem everything else in one go
        drs.approve(address(scEngine), 500 ether);
        scEngine.burnAndReedemCollateral(wETH, 1 ether, 500 ether);

        assertEq(scEngine.getDrsMinted(USER), 0);
        assertEq(scEngine.getCollateralBalanceOfUser(USER, wETH), 0);
        
        vm.stopPrank();
    }

    ///////////////////////////////////
    // End-to-End Liquidation Tests  //
    ///////////////////////////////////

    function testLiquidationScenarioFull() public {
        // Arrange - User setup
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(scEngine), 1 ether);
        // User deposits 1 WETH ($2000) and mints 1000 DRS (Max safe limit)
        scEngine.depositCollateralAndMintDRS(wETH, 1 ether, 1000 ether);
        
        assertEq(scEngine.getHealthFactor(USER), 1 ether); 
        vm.stopPrank();

        // Arrange - Price crash 
        // WETH price drops from $2000 to $1600.
        // New Value of 1 WETH = $1600.
        // Max borrow limit for 1 WETH = $800.
        // User has $1000 debt -> User is UNDERWATER.
        int256 newWethPrice = 1600e8; 
        MockV3Aggregator(wETH_priceFeed).updateAnswer(newWethPrice);

        uint256 unhealthyFactor = scEngine.getHealthFactor(USER);
        // EXPECTED = (1600 * 0.5 * 1e18) / 1000 = 0.8e18
        assertEq(unhealthyFactor, 0.8 ether);
        
        // Assert User drops below min health factor
        assert(unhealthyFactor < scEngine.getMinimumHealthFactor());

        // Arrange - Liquidator comes in
        vm.startPrank(LIQUIDATOR);
        // Liquidator needs some DRS to pay the user's debt.
        // Liquidator deposits 10 WETH ($16000) and mints 1000 DRS.
        ERC20Mock(wETH).approve(address(scEngine), 10 ether);
        scEngine.depositCollateralAndMintDRS(wETH, 10 ether, 1000 ether);
        
        uint256 liquidatorWethBefore = ERC20Mock(wETH).balanceOf(LIQUIDATOR);
        
        // Approve DRS on the engine to burn the debt for the user
        drs.approve(address(scEngine), 1000 ether);
        
        // ACT - Liquidate user's 1000 DRS debt in exchange for WETH collateral + bonus
        scEngine.liquidate(USER, wETH, 1000 ether);
        vm.stopPrank();

        // Assertions for Liquidation
        uint256 userDebtAfter = scEngine.getDrsMinted(USER);
        assertEq(userDebtAfter, 0); // User is fully debt-free now
        
        // Let's calculate exactly how much WETH the liquidator took:
        // Debt covered: 1000 DRS ($1000). At $1600/ETH -> 1000/1600 = 0.625 ETH
        // 10% Liquidation Bonus: 0.0625 ETH
        // Total WETH redeemed: 0.6875 ETH
        uint256 liquidatorWethAfter = ERC20Mock(wETH).balanceOf(LIQUIDATOR);
        assertEq(liquidatorWethAfter - liquidatorWethBefore, 0.6875 ether); // They gained exactly this much WETH
        
        // User collateral remaining: 1 WETH - 0.6875 WETH = 0.3125 WETH
        uint256 userLeftoverCollateral = scEngine.getCollateralBalanceOfUser(USER, wETH);
        assertEq(userLeftoverCollateral, 0.3125 ether);
    }
    
    // Testing what happens if price crashes extremely hard causing undercollateralization.
    function testUserBecomesUndercollateralizedUnderflowRevert() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(scEngine), 1 ether);
        scEngine.depositCollateralAndMintDRS(wETH, 1 ether, 1000 ether);
        vm.stopPrank();

        // WETH price drops from $2000 to $900 completely rapidly (Flash crash)
        // Debt = 1000. WETH Collateral Value = 900.
        // User is hopelessly bankrupt. 
        MockV3Aggregator(wETH_priceFeed).updateAnswer(900e8);
        
        vm.startPrank(LIQUIDATOR);
        ERC20Mock(wETH).approve(address(scEngine), 10 ether);
        scEngine.depositCollateralAndMintDRS(wETH, 10 ether, 1000 ether);
        
        drs.approve(address(scEngine), 1000 ether);
        
        // This will revert with an underflow / Panic because Liquidator needs:
        // Debt 1000 DRS -> 1.11... WETH + 10% bonus -> 1.22... WETH total.
        // Since user only has 1 WETH, the math tries to subtract more than they have.
        // A truly robust engine handles this via system debt, but for this math, it's expected to revert.
        vm.expectRevert(); 
        scEngine.liquidate(USER, wETH, 1000 ether);
        vm.stopPrank();
    }

    //////////////////////////////////////////
    // Complex Multiple Collateral Scenario //
    //////////////////////////////////////////

    function testMultiCollateralBorrowingAndRepayment() public {
        vm.startPrank(USER);
        
        // User deposits 1 WETH ($2000) and 1 WBTC ($60000)
        ERC20Mock(wETH).approve(address(scEngine), 1 ether);
        scEngine.depositCollateral(wETH, 1 ether);
        
        ERC20Mock(wBTC).approve(address(scEngine), 1 ether);
        scEngine.depositCollateral(wBTC, 1 ether);

        // Max limit: WETH ($1000 debt max) + WBTC ($30000 debt max) = $31000 max.
        // User borrows 30,000 DRS. 
        scEngine.mintDRS(30000 ether);
        
        uint256 hfBefore = scEngine.getHealthFactor(USER);
        
        // $62000 * 0.5 / 30000 = 1.033333333...
        assert(hfBefore > 1 ether);

        // Price of WETH goes to 0 (WETH collapses)
        MockV3Aggregator(wETH_priceFeed).updateAnswer(0);

        // New Max Limit: WBTC ($30000 limit). Max limit is exactly $30000.
        // Debt is exactly $30000.
        // HF = $60000 * 0.5 / 30000 = 1.0. User survives WETH collapsing to $0 without being liquidated!
        uint256 hfAfterDrop = scEngine.getHealthFactor(USER);
        assertEq(hfAfterDrop, 1 ether);
        
        // Repay everything
        drs.approve(address(scEngine), 30000 ether);
        scEngine.burnDRS(30000 ether);
        
        scEngine.reedemCollateral(wBTC, 1 ether);
        scEngine.reedemCollateral(wETH, 1 ether);

        // Verify everything is 0
        assertEq(scEngine.getCollateralBalanceOfUser(USER, wETH), 0);
        assertEq(scEngine.getCollateralBalanceOfUser(USER, wBTC), 0);
        assertEq(scEngine.getDrsMinted(USER), 0);

        vm.stopPrank();
    }
}
