// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
import {BasicNFT} from "src/BasicNFT.sol";

contract Interactions is Script {
    function run() public {
        address recentDeployment = DevOpsTools.get_most_recent_deployment(
            "BasicNFT",
            block.chainid
        );
        mintNFTonRecentDeploymemt(recentDeployment);
    }

    function mintNFTonRecentDeploymemt(address _recentDeployment) public {
        vm.startBroadcast();
        BasicNFT(_recentDeployment).mintNFT(
            "https://avatars.githubusercontent.com/u/146882119?v=4"
        );
        vm.stopBroadcast();
    }
}
