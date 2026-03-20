// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract Subscription is Script {
    function createSubscriptionFromNetworkConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinatorAddress = helperConfig
            .getConfig()
            .vrfCoordinatorAddress;
        address account = helperConfig.getConfig().account;
        createSubscription(vrfCoordinatorAddress, account);
    }

    function createSubscription(
        address vrfCoordinatorAddress,
        address account
    ) public returns (uint256, address) {
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinatorAddress)
            .createSubscription();
        vm.stopBroadcast();
        return (subId, vrfCoordinatorAddress);
    }

    function run() public {
        createSubscriptionFromNetworkConfig();
    }
}

contract FundSubscription is Script {
    function fundSubscriptionFromNetworkConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if (helperConfig.getConfig().subId == 0) {
            Subscription subscription = new Subscription();
            (config.subId, config.vrfCoordinatorAddress) = subscription
                .createSubscription(
                    config.account,
                    config.vrfCoordinatorAddress
                );
        }

        address vrfCoordinatorAddress = helperConfig
            .getConfig()
            .vrfCoordinatorAddress;
        address account = config.account;
        address linkAddress = config.linkAddress;
        uint256 subId = config.subId;

        fundSubscription(
            subId,
            3 ether,
            vrfCoordinatorAddress,
            account,
            linkAddress
        );

        helperConfig.setConfig(block.chainid, config);
    }

    function fundSubscription(
        uint256 subId,
        uint256 amount,
        address vrfCordinatorAddress,
        address account,
        address linkAddress
    ) public {
        if (block.chainid == 31337) {
            vm.startBroadcast(account);
            VRFCoordinatorV2_5Mock(vrfCordinatorAddress).fundSubscription(
                subId,
                amount
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkAddress).transferAndCall(
                vrfCordinatorAddress,
                amount,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionFromNetworkConfig();
    }
}

contract AddConsumer is Script {
    //addConsumer(uint256 subId, address consumer)
    function addLatestConsumer(address latestRaffle) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subId = helperConfig.getConfig().subId;
        address account = helperConfig.getConfig().account;
        address vrfCordinatorAddress = helperConfig
            .getConfig()
            .vrfCoordinatorAddress;
        addConsumer(subId, vrfCordinatorAddress, account, latestRaffle);
    }

    function addConsumer(
        uint256 subId,
        address vrfCordinatorAddress,
        address account,
        address latestRaffle
    ) public {
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCordinatorAddress).addConsumer(
            subId,
            latestRaffle
        );
        vm.stopBroadcast();
    }

    function run() public {
        address latestRaffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addLatestConsumer(latestRaffle);
    }
}
