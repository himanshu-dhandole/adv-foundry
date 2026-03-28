// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/////////// IMPORTS ///////////
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Decentralised Stable Coin
 * @author Himanshu Dhandole
 * @notice This is a Decentralised Stable Coin pegged to Indian Rupee
 * @dev the coin enforces Overcollateralisd (200%) , Arthematically and code Governed
 */
contract StableCoin is ERC20Burnable, Ownable {
    /////////// ERROR ///////////

    error StableCoin__AmountCannotBeZero();
    error StableCoin__CannotMintToAddressZero();
    error StableCoin__BurnAmountExceedsBalance();

    /////////// MODIFIER ///////////

    modifier checkZero(uint256 _amount) {
        if (_amount <= 0) {
            revert StableCoin__AmountCannotBeZero();
        }
        _;
    }

    /////////// CONSTRUCTOR ///////////

    constructor() ERC20("Decentralised Rupee", "DRS") Ownable(msg.sender) { }

    /////////// CORE FUNCTIONS  ///////////

    function mint(address _to, uint256 _amount) public checkZero(_amount) onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert StableCoin__CannotMintToAddressZero();
        }
        _mint(_to, _amount);
        return true;
    }

    function burn(uint256 _amount) public override onlyOwner checkZero(_amount) {
        if (_amount >= balanceOf(msg.sender)) {
            revert StableCoin__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }
}
