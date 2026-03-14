// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/** 
 * @title Raffle
 * @author Himanshu Dhandole
 * @notice This is a simple raffle contract that allows users to enter the raffle by paying an entrance fee.
 * @dev This implements chainLink VRFV2.5.
 */
contract Raffle {

    uint256 public immutable i_entranceFee;

    constructor(uint256 _entranceFee) {
        i_entranceFee = _entranceFee;
    }

    function enterRaffle() public payable {

    }
    function pickWinner() public {

    } 
}