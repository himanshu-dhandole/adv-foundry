// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DeployDecentralisedStableCoin is Script {
    address[] public priceFeeds;
    address[] public tokens;

    function run() external returns (DecentralisedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();
        (address wETH, address wBTC, address ethPriceFeed, address btcPriceFeed, uint256 deployerKey) =
            config.activeNetworkConfig();

        priceFeeds = [ethPriceFeed, btcPriceFeed];
        tokens = [wETH, wBTC];

        vm.startBroadcast(deployerKey);
        DecentralisedStableCoin dsc = new DecentralisedStableCoin();
        DSCEngine dscEngine = new DSCEngine(tokens, priceFeeds, address(dsc));

        // transfer ownership from the me to the DSC engine
        dsc.transferOwnership(address(dscEngine));
        vm.stopBroadcast();

        return (dsc, dscEngine, config);
    }
}
