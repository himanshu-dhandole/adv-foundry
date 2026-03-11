// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMe} from "../script/DeployFundMe.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    function setUp() public {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
    }
    function testMinimumLimit() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }
    function testOwner() public {
        assertEq(fundMe.i_owner(), msg.sender);
    }
    function testGetVersion() public {
        assertEq(fundMe.getVersion(), 4);
    }
}
