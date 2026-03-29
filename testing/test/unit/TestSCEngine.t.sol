// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

////////////    IMPORTS    ////////////
import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { StableCoin } from "src/StableCoin.sol";
import { StableCoinEngine } from "src/StableCoinEngine.sol";
import { DeployStableCoin } from "script/Deploy.s.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "test/mocks/MockERC20.sol";

contract TestStableCoinEngine is Test {
    HelperConfig config;
    StableCoin drs;
    StableCoinEngine scEngine;
    address USER = makeAddr("user");
    address wETH;
    address wBTC;
    address wETH_priceFeed;
    address wBTC_priceFeed;

    function setUp() public {
        DeployStableCoin deployer = new DeployStableCoin();
        (drs, scEngine, config) = deployer.run();
        (wETH, wBTC, wETH_priceFeed, wBTC_priceFeed,) = config.activeNetworkConfig();
        ERC20Mock(wETH).mint(USER, 100e18);
        ERC20Mock(wBTC).mint(USER, 100e18);
    }

    modifier deposit() {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(scEngine), 1e18);
        scEngine.depositCollateral(wETH, 1e18);
        ERC20Mock(wBTC).approve(address(scEngine), 1e18);
        scEngine.depositCollateral(wBTC, 1e18);
        vm.stopPrank();
        _;
    }

    function testDepositCollateral() public {
        uint256 startingBal = scEngine.getCollateralBalanceOfUser(USER, wETH);
        console.log("starting bal : ", scEngine.getCollateralBalanceOfUser(USER, wETH));
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(scEngine), 1e18);
        scEngine.depositCollateral(wETH, 1e18);
        vm.stopPrank();
        console.log("current bal : ", scEngine.getCollateralBalanceOfUser(USER, wETH));
        assert(startingBal < scEngine.getCollateralBalanceOfUser(USER, wETH));
    }

    function testRevertMintDRStoken() public deposit {
        vm.startPrank(USER);
        vm.expectRevert(StableCoinEngine.SCEngine__HealthFactorTooLow.selector);
        scEngine.mintDRS(33000e18);
        vm.stopPrank();
        console.log("drs balance : ", scEngine.getDrsMinted(USER));
    }

    function testMintDRStoken() public deposit {
        vm.startPrank(USER);
        console.log("get health factor : ", scEngine.getHealthFactor(USER));
        scEngine.mintDRS(1000e18);
        console.log("get health factor : ", scEngine.getHealthFactor(USER));
        vm.stopPrank();
        console.log("drs balance : ", scEngine.getDrsMinted(USER));
    }

    function testRevertIfDepositAmountIsZero() public {
        vm.startPrank(USER);
        vm.expectRevert(StableCoinEngine.SCEngine__AmountCannotBeZero.selector);
        scEngine.depositCollateral(wETH, 0);
        vm.stopPrank();
    }

    function testRevertIfMintAmountIsZero() public deposit {
        vm.startPrank(USER);
        vm.expectRevert(StableCoinEngine.SCEngine__AmountCannotBeZero.selector);
        scEngine.mintDRS(0);
        vm.stopPrank();
    }

    function testDepositCollateralAndMintDRS() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(scEngine), 1e18);
        scEngine.depositCollateralAndMintDRS(wETH, 1e18, 1000e18); // 1 WETH is 2000 in value, so 1000 max borrowing is perfectly valid
        vm.stopPrank();

        uint256 expectedTokens = 1000e18;
        assertEq(scEngine.getDrsMinted(USER), expectedTokens);
        assertEq(scEngine.getCollateralBalanceOfUser(USER, wETH), 1e18);
    }

    function testRevertDepositCollateralAndMintDRSIfHealthFactorTooLow() public {
        vm.startPrank(USER);
        ERC20Mock(wETH).approve(address(scEngine), 1e18);

        vm.expectRevert(StableCoinEngine.SCEngine__HealthFactorTooLow.selector);
        // 1 WETH gives max ~1000 DRS, attempting to mint 1001e18 drops health factor < 1
        scEngine.depositCollateralAndMintDRS(wETH, 1e18, 1001e18);
        vm.stopPrank();
    }

    function testGetDrsAddressIsInitiallyCorrect() public view {
        address engineDrsAddress = scEngine.getDrsAddress();
        assertEq(engineDrsAddress, address(drs));
    }

    function testReedemCollateral() public deposit {
        vm.startPrank(USER);
        uint256 starting = scEngine.getCollateralBalanceOfUser(USER, wETH);
        console.log("starting bal :", scEngine.getCollateralBalanceOfUser(USER, wETH));
        scEngine.reedemCollateral(wETH, 1e18);
        console.log("ending bal :", scEngine.getCollateralBalanceOfUser(USER, wETH));
        assert(starting > scEngine.getCollateralBalanceOfUser(USER, wETH));
        vm.stopPrank();
    }

    modifier mint() {
        vm.startPrank(USER);
        scEngine.mintDRS(1000e18);
        vm.stopPrank();
        _;
    }

    function testBurnDSC() public deposit mint {
        vm.startPrank(USER);
        uint256 starting = scEngine.getDrsMinted(USER);
        console.log("starting bal :", starting);
        drs.approve(address(scEngine), 1e18);
        scEngine.burnDRS(1e18);
        console.log("ending bal :", scEngine.getDrsMinted(USER));
        assert(starting > scEngine.getDrsMinted(USER));
        vm.stopPrank();
    }
}
