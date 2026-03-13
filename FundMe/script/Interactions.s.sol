// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script , console} from "forge-std/Script.sol";
import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {FundMe} from "../src/FundMe.sol";

contract FundFundMe is Script {

    function FundFundMeContract (address mostRecentDeployment) public {
        vm.startBroadcast();
        // FundMe.fund(payable(mostRecentDeployment).fund{value:1e18}());
        FundMe fundme = FundMe(mostRecentDeployment);
        fundme.fund{value : 1e18}();
        vm.stopBroadcast();
        console.log("funded the fundMe contract !");
    }

    function run() external {
        address mostRecentDeployment = DevOpsTools.get_most_recent_deployment("FundMe", block.chainid);
        FundFundMeContract(mostRecentDeployment);
    }
}