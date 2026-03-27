// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DeployDecentralisedStableCoin} from "script/Deploy.s.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract InvarientTest is StdInvariant, Test {
    DecentralisedStableCoin dsc;
    DSCEngine dscEngine;
    HelperConfig config;
    address wETH;
    address wBTC;

    function setUp() public {
        DeployDecentralisedStableCoin deployer = new DeployDecentralisedStableCoin();
        (dsc, dscEngine, config) = deployer.run();
        (wETH, wBTC,,,) = config.activeNetworkConfig();
        Handler handler = new Handler(dsc, dscEngine);
        targetContract(address(handler));
    }

    function invariant_TotalsupplyAlwaysEqualtoWethAndwbtc() public {
        uint256 totalSupply = dsc.totalSupply();
        uint256 wETH_deposited = IERC20(wETH).balanceOf(address(dscEngine));
        uint256 wBTC_deposited = IERC20(wBTC).balanceOf(address(dscEngine));

        uint256 wETH_USD = dscEngine.getValueInUSD(wETH, wETH_deposited);
        uint256 wBTC_USD = dscEngine.getValueInUSD(wBTC, wBTC_deposited);

        assert(wETH_USD + wBTC_USD >= totalSupply);
    }
}
