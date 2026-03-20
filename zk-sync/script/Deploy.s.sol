// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Subscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

contract DeployRaffle is Script {
    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (config.subId == 0) {
            Subscription subscription = new Subscription();
            (config.subId, config.vrfCoordinatorAddress) = subscription
                .createSubscription(
                    config.vrfCoordinatorAddress,
                    config.account
                );

            // now we fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.subId,
                50 ether,
                config.vrfCoordinatorAddress,
                config.account,
                config.linkAddress
            );

            helperConfig.setConfig(block.chainid, config);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle({
            _vrfCoordinatorAddress: config.vrfCoordinatorAddress,
            _keyHash: config.keyHash,
            _subId: config.subId,
            _callbackGasLimit: config.callbackGasLimit
        });
        vm.stopBroadcast();

        // now we add the latest deployed raffle as a consumer to our subscription
        //  uint256 subId, address vrfCordinatorAddress, address account, address latestRaffle
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            config.subId,
            config.vrfCoordinatorAddress,
            config.account,
            address(raffle)
        );

        return (raffle, helperConfig);
    }
}
