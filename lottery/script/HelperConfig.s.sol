// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChain();

    struct NetworkConfig {
        uint256 entranceFee;
        address vrfCordinator;
        uint256 interval;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address linkAddress;
        address account;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public NetworkConfigs;

    constructor() {
        NetworkConfigs[11155111] = getSepoliaNetworkConfig();
    }

    function getConfigByChainId(
        uint256 _chainId
    ) public returns (NetworkConfig memory) {
        if (NetworkConfigs[_chainId].vrfCordinator != address(0)) {
            return NetworkConfigs[_chainId];
        } else if (_chainId == 31337) {
            return getOdCreateAnvilNetworkConfig();
        } else {
            revert HelperConfig__InvalidChain();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaNetworkConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                entranceFee: 0.01 ether,
                vrfCordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                interval: 30,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 36617806939514148070012914982111474411352938046435020241180162587373645360664,
                callbackGasLimit: 500000,
                linkAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                account: 0x2a3D206626337FcAC4C5Cfc0f9fBe18F9D900f47
            });
    }

    function getOdCreateAnvilNetworkConfig()
        public
        returns (NetworkConfig memory)
    {
        if (localNetworkConfig.vrfCordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock anvilMock = new VRFCoordinatorV2_5Mock(
            0.25 ether,
            1e9,
            4e15
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            vrfCordinator: address(anvilMock),
            interval: 30,
            //dosent matter
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            linkAddress: address(link),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}
