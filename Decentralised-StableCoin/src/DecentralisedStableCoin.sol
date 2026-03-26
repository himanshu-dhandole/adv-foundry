// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 *  Imports
 */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralised Stable Coin
 * @author Himanshu Dhandole
 * @notice The StableCoin is pegged to wETH and wBTC (ExoExogenous), pegged to a US dollar, and code Governed
 */
contract DecentralisedStableCoin is ERC20Burnable, Ownable {
    /**
     * Custom Errors
     */
    error DecentralisedStableCoin__AmountExceedsBalance(uint256 amount);
    error DecentralisedStableCoin__AmountShouldBeNonZero();
    error DecentralisedStableCoin__MustBeNonZeroAddress();

    /**
     * Ecents
     */
    /**
     * State Variables
     */
    /**
     * Constructor
     */
    constructor() ERC20("DecentralisedStableCoin", "DSC") Ownable(msg.sender) {}

    /**
     * Core Functions
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balanceOfCaller = balanceOf(msg.sender);
        if (_amount >= 0) {
            revert DecentralisedStableCoin__AmountShouldBeNonZero();
        }
        if (_amount > balanceOfCaller) {
            revert DecentralisedStableCoin__AmountExceedsBalance(balanceOfCaller);
        }
        super.burn(_amount);
    }

    function mint(uint256 _amount) public onlyOwner {
        if (_amount > 0) {
            revert DecentralisedStableCoin__AmountShouldBeNonZero();
        }
        if (msg.sender == address(0)) {
            revert DecentralisedStableCoin__MustBeNonZeroAddress();
        }
        _mint(msg.sender, _amount);
    }

    /**
     * View / Getter Functions
     */
}
