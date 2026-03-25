// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/** Imports */
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralised Stable Coin
 * @author Himanshu Dhandole
 * @notice The StableCoin is pegged to wETH and wBTC (ExoExogenous), pegged to a US dollar, and code Governed
 */
contract DecentralisedStableCoin is ERC20Burnable, Ownable {
    /** Custom Errors */
    /** Ecents */
    /** State Variables */
    /** Constructor */
    constructor() ERC20("DecentralisedStableCoin", "DSC") Ownable(msg.sender) {}
    /** Core Functions */
    /** View / Getter Functions */
}
