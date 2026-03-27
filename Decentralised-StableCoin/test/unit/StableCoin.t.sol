// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployDecentralisedStableCoin} from "script/Deploy.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract TestStableCoin is Test {
    DecentralisedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig config;
    address USER = makeAddr("user");
    address wETH;
    address wBTC;

    function setUp() public {
        DeployDecentralisedStableCoin deployer = new DeployDecentralisedStableCoin();
        (dsc, dscEngine, config) = deployer.run();
        vm.deal(USER, 50 ether);
        (wETH, wBTC,,,) = config.activeNetworkConfig();
        ERC20Mock(wETH).mint(USER, 5e18);
    }

    function testOwnerOfDSC() public {
        console.log(address(dsc));
        console.log(address(dscEngine));

        assert(dsc.owner() == address(dscEngine));
    }

    function testConvertionOfColleateralToUSD() public {
        vm.prank(USER);
        console.log(dscEngine.getValueInUSD(wETH, 1 ether));
        // 2000000000000000000000
        assert(dscEngine.getValueInUSD(wETH, 1 ether) == 2000e18);
        console.log(dscEngine.getValueInUSD(wBTC, 1 ether));
        assert(dscEngine.getValueInUSD(wBTC, 1 ether) == 60000e18);
    }

    function testGetAccountTotalCollateralInUSD() public {
        vm.prank(USER);
        uint256 amt = dscEngine.getAccountTotalCollateralInUSD(msg.sender);
        console.log("amount : ", amt);
    }

    function testDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateral(wETH, 1 ether);
        uint256 amt = dscEngine.getAccountTotalCollateralInUSD(USER);
        vm.stopPrank();
        console.log("amount : ", amt);
        assert(amt == 2000e18);
    }

    function testMintAtLimit() public {
        vm.startPrank(USER);

        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateral(wETH, 1 ether);

        // max allowed = 1000 DSC (2000 * 50%)
        dscEngine.mintDSC(1000e18);

        assertEq(dscEngine.s_DscMinted(USER), 1000e18);

        vm.stopPrank();
    }

    function testMintRevert() public {
        vm.startPrank(USER);

        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateral(wETH, 1 ether);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorTooLow.selector);
        dscEngine.mintDSC(5000e18);

        assertEq(dscEngine.s_DscMinted(USER), 0);

        vm.stopPrank();
    }

    modifier depositCollateral() {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateral(wETH, 1 ether);
        vm.stopPrank();
        _;
    }

    function testReedemCollateral() public depositCollateral {
        vm.startPrank(USER);
        console.log("balance before : ", dscEngine.getCollateralToUser(wETH));
        console.log("health Factor :", dscEngine.getHealthFactor(USER));
        dscEngine.reedemCollateral(wETH, 1e18);
        console.log("balance after : ", dscEngine.getCollateralToUser(wETH));
        vm.stopPrank();
    }

    function testMintDSCAndDepositCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateralAndMintDSC(wETH, 1 ether, 1e18);
        assert(dscEngine.getDscMinted(USER) == 1e18);
        vm.stopPrank();
    }

    function testRevertHealthCheckWnenMintingMore() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorTooLow.selector);
        dscEngine.depositCollateralAndMintDSC(wETH, 1 ether, 1001e18); // more thaan 200% overcollateralised
        vm.stopPrank();
    }

    function testBurnAndReedemCollateral() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        // mint 100 stable coins
        dscEngine.depositCollateralAndMintDSC(wETH, 1 ether, 100e18);
        console.log("collateral wETH: ", dscEngine.getCollateralBalanceOfUser(USER, wETH));
        console.log("minted DSC: ", dscEngine.getDscMinted(USER));
        dsc.approve(address(dscEngine), 50e18);
        dscEngine.reedemCollateralAndBurnDSC(wETH, 0.1 ether, 50e18);
        assert(dscEngine.getDscMinted(USER) == 50e18);
        vm.stopPrank();
    }

    // ==========================================
    // ai tests
    // ==========================================

    function testRevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](2);
        tokenAddresses[0] = wETH;
        priceFeedAddresses[0] = address(1);
        priceFeedAddresses[1] = address(2);

        vm.expectRevert(DSCEngine.DSCEngine__FailedToSetCollateralAddresses.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function testRevertsIfDepositAmountIsZero() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);

        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        dscEngine.depositCollateral(wETH, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedToken() public {
        ERC20Mock randomToken = new ERC20Mock("RAN", "RAN", USER, 100e18);
        vm.startPrank(USER);
        vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(randomToken)));
        dscEngine.depositCollateral(address(randomToken), 1 ether);
        vm.stopPrank();
    }

    function testRevertsIfMintAmountIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        dscEngine.mintDSC(0);
        vm.stopPrank();
    }

    function testRevertsIfBurnAmountIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        dscEngine.burnDSC(0);
        vm.stopPrank();
    }

    function testRevertsIfRedeemAmountIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(DSCEngine.DSCEngine__AmountCannotBeZero.selector);
        dscEngine.reedemCollateral(wETH, 0);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealthFactor() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateralAndMintDSC(wETH, 1 ether, 100e18);
        vm.stopPrank();

        address LIQUIDATOR = makeAddr("liquidator");
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__NotLiquidatable.selector);
        dscEngine.liquidate(USER, wETH, 10e18);
        vm.stopPrank();
    }

    function testRevertsIfDebtIsLowForLiquidate() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateralAndMintDSC(wETH, 1 ether, 10e18);
        vm.stopPrank();

        address LIQUIDATOR = makeAddr("liquidator");
        vm.startPrank(LIQUIDATOR);
        vm.expectRevert(DSCEngine.DSCEngine__DebtIsLow.selector);
        dscEngine.liquidate(USER, wETH, 100e18); // Attempting to liquidate more than the exact debt
        vm.stopPrank();
    }

    function testGetCollateralTokenPriceFeed() public {
        address priceFeed = dscEngine.getCollateralTokenPriceFeed(wETH);
        assert(priceFeed != address(0)); 
    }

    function testGetCollateralTokens() public {
        address[] memory tokens = dscEngine.getCollateralTokens();
        assert(tokens.length == 2);
    }

    function testGetMinHealthFactor() public {
        uint256 minHealthFactor = dscEngine.getMinHealthFactor();
        assert(minHealthFactor == 1e18);
    }

    function testGetLiquidationThreshold() public {
        uint256 threshold = dscEngine.getLiquidationThreshold();
        assert(threshold == 50);
    }

    function testGetDsc() public {
        address dscAddress = dscEngine.getDsc();
        assert(dscAddress == address(dsc));
    }

    function testGetAccountCollateralValue() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateral(wETH, 1 ether);
        vm.stopPrank();
        
        uint256 collateralValue = dscEngine.getAccountTotalCollateralInUSD(USER);
        uint256 expectedValue = dscEngine.getValueInUSD(wETH, 1 ether);
        assert(collateralValue == expectedValue);
    }

    function testGetPrecision() public {
        assertEq(dscEngine.getPrecision(), 1e18);
    }
    
    function testGetAdditionalFeedPrecision() public {
        assertEq(dscEngine.getAdditionalFeedPrecision(), 1e10);
    }

    function testGetLiquidationBonus() public {
        assertEq(dscEngine.getLiquidationBonus(), 10);
    }

    function testGetLiquidationPrecision() public {
        assertEq(dscEngine.getLiquidationPrecision(), 100);
    }
}
