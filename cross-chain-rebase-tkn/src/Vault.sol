// SPDX-Licanse-Identifier: MIT
pragma solidity ^0.8.19;

/*************** IMPORTS ***************/
import {I_RebaseToken} from "./interfaces/I_RebaseToken.sol";

/**
 * @title Vault contract for Rebase Token
 * @author Himanshu Dhandole
 * @notice this contract locks the collateral and mints the rebase token and supports the reedem of collateral thrugh biurning of rebase tokens
 */
contract Vault {
    /*************** EVENTS ***************/
    event Deposited(address indexed depositor, uint256 indexed amount);
    event Burned(address indexed burner, uint256 indexed amount);

    /*************** ERRORS ***************/
    error Vault__AmountNotValid();
    error Vault__BurnFailed();

    /*************** STATE VARIABLES ***************/
    I_RebaseToken immutable i_rebaseToken;

    /*************** MODIFIER ***************/
    modifier isValid(uint256 _amount) {
        if (_amount < 0) {
            revert Vault__AmountNotValid();
        }
        _;
    }

    /*************** CONSTRUCTOR ***************/
    constructor(I_RebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    /*************** CORE FUNCTIONS ***************/
    function deposit() external payable isValid(msg.value) {
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposited(msg.sender, msg.value);
    }

    function reedem() public {
        uint256 balance = i_rebaseToken.balanceOf(msg.sender);
        if (balance < 0) {
            revert Vault__AmountNotValid();
        }
        i_rebaseToken.burn(msg.sender, balance);

        emit Burned(msg.sender, balance);

        (bool success,) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert Vault__BurnFailed();
        }
    }

    // this function accepts all eth without sending calldata
    receive() external payable {}
}
