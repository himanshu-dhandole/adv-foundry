// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

////////////    IMPORTS    ////////////
import { Script, console } from "forge-std/Script.sol";
import { HelperConfig } from "./HelperConfig.s.sol";
import { StableCoin } from "src/StableCoin.sol";
import { StableCoinEngine } from "src/StableCoinEngine.sol";

contract DeployStableCoin is Script {
    ////////////    STATE VARIABLES    ////////////
    address[] acceptedTokenAddresses;
    address[] acceptedTokenPriceFeeds;

    ////////////    CORE FUNCTION    ////////////
    function run() public returns (StableCoin, StableCoinEngine, HelperConfig) {
        HelperConfig config = new HelperConfig();

        (address wETH, address wBTC, address wETH_priceFeed, address wBTC_priceFeed, uint256 deployerKey) =
            config.activeNetworkConfig();
        acceptedTokenAddresses = [wETH, wBTC];
        acceptedTokenPriceFeeds = [wETH_priceFeed, wBTC_priceFeed];

        vm.startBroadcast(deployerKey);
        StableCoin drs = new StableCoin();
        StableCoinEngine scEngine = new StableCoinEngine(acceptedTokenAddresses, acceptedTokenPriceFeeds, drs);
        drs.transferOwnership(address(scEngine));
        vm.stopBroadcast();

        console.log("DRS address : ", address(drs));
        console.log("DRS Engine address : ", address(scEngine));

        return (drs, scEngine, config);
    }
}
