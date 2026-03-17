// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract CreateSubscription is Script {
    constructor() {}

    function createSubscriptionViaConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCordinator = helperConfig.getConfig().vrfCordinator;
        (uint256 subId, ) = createSubscription(vrfCordinator);
        return (subId, vrfCordinator);
    }

    function createSubscription(
        address _vrfCordinator
    ) public returns (uint256, address) {
        vm.startBroadcast();
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
        fundSubscription(vrfCordinator, subscriptionId, linkAddress);
    }

    function fundSubscription(
        address _vrfCordinator,
        uint256 _subscriptionId,
        address _linkAddress
    ) public {
        console.log("Funding subscription: ", _subscriptionId);
        console.log("Using vrfCoordinator: ", _vrfCordinator);
        console.log("On chainId: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(_vrfCordinator).fundSubscription(
                _subscriptionId,
                3 ether
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(_linkAddress).transferAndCall(
                _vrfCordinator,
                3 ether,
                abi.encode(_subscriptionId)
            );
            vm.stopBroadcast();
        }
    }
}
