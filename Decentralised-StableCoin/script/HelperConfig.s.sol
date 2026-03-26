// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address wETH;
        address wBTC;
        address ethPriceFeed;
        address btcPriceFeed;
        uint256 deployerKey;
    }

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    function getSepoliaNetworkConfig() public returns (NetworkConfig memory) {
        return NetworkConfig({
            wETH: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            ethPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            btcPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.wETH != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        ERC20Mock weth = new ERC20Mock("wETH", "wETH", msg.sender, 10000e18);
        ERC20Mock wbtc = new ERC20Mock("wBTC", "wBTC", msg.sender, 10000e18);
        MockV3Aggregator ethPriceFeed = new MockV3Aggregator(8, 2000 * 1e8);
        MockV3Aggregator btcPriceFeed = new MockV3Aggregator(8, 60000 * 1e8);
        vm.stopBroadcast();

        return NetworkConfig({
            wETH: address(weth),
            wBTC: address(wbtc),
            ethPriceFeed: address(ethPriceFeed),
            btcPriceFeed: address(btcPriceFeed),
            deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
        });
    }
}
