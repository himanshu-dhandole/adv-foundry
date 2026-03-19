// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    constructor() {}

    function createSubscriptionViaConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCordinator = helperConfig.getConfig().vrfCordinator;
        address account = helperConfig.getConfig().account;
        (uint256 subId, ) = createSubscription(vrfCordinator, account);
        return (subId, vrfCordinator);
    }

    function createSubscription(
        address _vrfCordinator,
        address account
    ) public returns (uint256, address) {
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(_vrfCordinator)
            .createSubscription();
        vm.stopBroadcast();
        return (subId, _vrfCordinator);
    }

    function run() public {
        createSubscriptionViaConfig();
    }
}

contract FundSubscription is Script {
    function run() public {
        fundSubscriptionViaConfig();
    }

    function fundSubscriptionViaConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCordinator = helperConfig.getConfig().vrfCordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address linkAddress = helperConfig.getConfig().linkAddress;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCordinator, subscriptionId, linkAddress, account);
    }

    function fundSubscription(
        address _vrfCordinator,
        uint256 _subscriptionId,
        address _linkAddress,
        address account
    ) public {
        console.log("Funding subscription: ", _subscriptionId);
        console.log("Using vrfCoordinator: ", _vrfCordinator);
        console.log("On chainId: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCordinator).fundSubscription(
                _subscriptionId,
                3000 ether
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(_linkAddress).transferAndCall(
                _vrfCordinator,
                3 ether,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }
}

contract AddConsumer is Script {
    function run() external {
        address recentDeployment = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerByConfig(recentDeployment);
    }

    function addConsumerByConfig(address recentDeployment) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCordinator = helperConfig.getConfig().vrfCordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        address account = helperConfig.getConfig().account;
        addConsumer(recentDeployment, vrfCordinator, subscriptionId, account);
    }

    function addConsumer(
        address recentDeployment,
        address vrfCordinator,
        uint256 subscriptionId,
        address account
    ) public {
        console.log("Adding consumer contract: ", recentDeployment);
        console.log("Using VRFCoordinator: ", vrfCordinator);
        console.log("On chain id: ", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCordinator).addConsumer(
            subscriptionId,
            recentDeployment
        );
        vm.stopBroadcast();
    }
}
