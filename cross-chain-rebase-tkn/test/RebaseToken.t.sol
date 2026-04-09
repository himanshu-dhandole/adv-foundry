// SPDX-License-Identifier : MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "src/RebaseToken.sol";

contract TestRebaseToken is Test {
    RebaseToken rtk;

    function setUp() public {
        rtk = new RebaseToken();
    }

    function testDeployment() public {
        console.log("rtk :", address(rtk));
    }
}
`