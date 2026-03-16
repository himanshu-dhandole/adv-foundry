// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChain();

    struct NetworkConfig {
        address vrfCoordinatorAddress;
        bytes32 keyHash;
        uint256 subId;
        uint32 callbackGasLimit;
    }

    mapping(uint256 networkId => NetworkConfig) configsByChainId;
    NetworkConfig private localConfig;

    constructor() {
        configsByChainId[11155111] = getSepoliaNetworkConfig();
    }

    function getConfigByChainId(
        uint256 _chainId
    ) public returns (NetworkConfig memory) {
        if (configsByChainId[_chainId].vrfCoordinatorAddress != address(0)) {
            return configsByChainId[_chainId];
        } else if (_chainId == 31337) {
            return getOrCreateAnvilConfig();
        } else {
            revert HelperConfig__InvalidChain();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localConfig.vrfCoordinatorAddress != address(0)) {
            return localConfig;
        }
        // create a anvil config and return it

        vm.startBroadcast();
        VRFCoordinatorV2_5Mock anvilConfig = new VRFCoordinatorV2_5Mock(
            0.25 ether,
            1e9,
            4e15
        );
        vm.stopBroadcast();

        localConfig = NetworkConfig({
            vrfCoordinatorAddress: address(anvilConfig),
            keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subId: 0,
            callbackGasLimit: 500000
        });
        return localConfig;
    }

    function getSepoliaNetworkConfig()
        public
        pure
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                vrfCoordinatorAddress: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subId: 0,
                callbackGasLimit: 500000
            });
    }
}
