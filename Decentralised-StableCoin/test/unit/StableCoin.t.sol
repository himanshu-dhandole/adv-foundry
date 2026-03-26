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

    // function testMintRevert() public {
    //     vm.startPrank(USER);
    //     ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
    //     dscEngine.depositCollateral(wETH, 1 ether);
    //     uint256 amt = dscEngine.getAccountTotalCollateralInUSD(USER);
    //     vm.expectRevert();
    //     dscEngine.mintDSC(5000e18);
    //     vm.stopPrank();
    //     console.log("amount deposited : ", amt);
    //     console.log("total minted : ", dscEngine.s_DscMinted(USER));
    // }

    function testMintRevert() public {
        vm.startPrank(USER);

        ERC20Mock(wETH).approve(address(dscEngine), 1 ether);
        dscEngine.depositCollateral(wETH, 1 ether);

        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorTooLow.selector);
        dscEngine.mintDSC(5000e18);

        assertEq(dscEngine.s_DscMinted(USER), 0);

        vm.stopPrank();
    }
}
