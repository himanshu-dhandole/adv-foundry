// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.sol";

contract FundMeTest is Test {
    FundMe fundMe;
    address USER = makeAddr("user");

    function setUp() public {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, 1000e18);
    }
    function testMinimumLimit() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }
    function testOwner() public {
        assertEq(fundMe.i_owner(), msg.sender);
    }
    function testGetVersion() public {
        assertEq(fundMe.getVersion(), 0);
    }

    function testFunderFailsToSendEth() public {
        vm.expectRevert();
        fundMe.fund();
    }

    function testFunderSendsEth() public {
        vm.prank(USER);
        fundMe.fund{value: 5e18}();
        uint256 amountFunded = fundMe.addressToAmountFunded(USER);
        assertEq(amountFunded, 5e18);
    }

    function testGetOwner() public {
        console.log(fundMe.getOwner().balance);
    }

    function testWithdrawFunds() public {
        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        vm.startPrank(USER);
        vm.deal(USER, 50e18);
        fundMe.fund{value: 5e18}();
        vm.stopPrank();
        uint256 startingFundBalance = address(fundMe).balance;

        //Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundBalance = address(fundMe).balance;
        assertEq(endingFundBalance, 0);
        assertEq(
            fundMe.getOwner().balance,
            startingOwnerBalance + startingFundBalance
        );
    }

    function testMultipleFundersAndWithdraw() public {
        //Arrange
        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint160 startingFunderIndex = 2;
        uint160 noOfFunders = 10;
        for (uint160 i = startingFunderIndex; i <= noOfFunders; i++) {
            hoax(address(i), 5e18);
            fundMe.fund{value: 5e18}();
        }
        uint256 fundmeAfterFunding = address(fundMe).balance;
        console.log("fundme after funding : ", address(fundMe).balance);

        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //assert
        assert(address(fundMe).balance == 0);
        console.log(
            "startingOwnerBalance : ",
            startingOwnerBalance,
            "startingFundMeBalance : ",
            startingFundMeBalance
        );
        console.log("fundMe.getOwner().balance: ", fundMe.getOwner().balance);
        assertEq(
            fundMe.getOwner().balance,
            startingOwnerBalance + fundmeAfterFunding
        );
    }
}
