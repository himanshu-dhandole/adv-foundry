// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

////////////    IMPORTS    ////////////

import { Script } from "forge-std/Script.sol";
import { ERC20Mock } from "test/mocks/MockERC20.sol";
import { MockV3Aggregator } from "test/mocks/MockV3Aggregator.sol";

/**
 * @title Helper Configurations
 * @author Himanshu Dhandole
 * @notice this contract contract contains all the necessary configurations for deploying the stablecoin and StableCoinEngine on Sepolia Testnet and Anvil Local Testnet
 */
contract HelperConfig is Script {
    ////////////    STRUCTS    ////////////
    struct NetworkConfig {
        address wETH;
        address wBTC;
        address wETH_priceFeed;
        address wBTC_priceFeed;
        uint256 deployerKey;
    }

    ////////////    STATE VARIABLES    ////////////
    NetworkConfig public activeNetworkConfig;

    ////////////    CONSTRUCTOR    ////////////
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaNetworkConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilNetworkConfig();
        }
    }

    ////////////    CORE FUNCTIONS    ////////////
    function getSepoliaNetworkConfig() private view returns (NetworkConfig memory) {
        return NetworkConfig({
            wETH: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
            wBTC: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            wETH_priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            wBTC_priceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilNetworkConfig() private returns (NetworkConfig memory) {
        if (activeNetworkConfig.wETH != address(0)) {
            return activeNetworkConfig;
        }
        vm.startBroadcast();
        ERC20Mock wETH = new ERC20Mock("wrapped ETH", "WETH", msg.sender, 1000e18);
        ERC20Mock wBTC = new ERC20Mock("wrapped BTC", "WBTC", msg.sender, 1000e18);
        MockV3Aggregator wETH_priceFeed = new MockV3Aggregator(8, 2000e8);
        MockV3Aggregator wBTC_priceFeed = new MockV3Aggregator(8, 60000e8);
        vm.stopBroadcast();

        return NetworkConfig({
            wETH: address(wETH),
            wBTC: address(wBTC),
            wETH_priceFeed: address(wETH_priceFeed),
            wBTC_priceFeed: address(wBTC_priceFeed),
            deployerKey: vm.envUint("ANVIL_PRIVATE_KEY")
        });
    }
}
