// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*************** IMPORTS ***************/
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Himanshu Dhandole
 * @notice this token has a decreasing intrest rate for adapters
 * // no access modifiers has been added yet
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    /*************** EVENTS ***************/
    event IntrestRateUpdated(uint256 indexed newIntrestrate);

    /*************** ERRORS ***************/
    error RebaseToken__NewIntrestRateCannotIncrease(uint256 intrestRate);
    error RebaseToken__InvalidAmountSent();

    /*************** STATE VARIABLES ***************/
    uint256 constant PRECISION_FACTOR = 1e18;
    bytes32 private MINT_AND_BURN = keccak256("MINT_AND_BURN");
    uint256 private s_intrestRate = 5e18;
    mapping(address => uint256) private s_IntrestRateToUser;
    mapping(address => uint256) private s_LastUpdatedTimeStampToUser;

    /*************** CONSTRUCTOR ***************/
    constructor() ERC20("Rebase Token", "RTK") Ownable(msg.sender) {}

    /*************** MODIFIER ***************/
    modifier amountValid(uint256 _amount) {
        if (_amount <= 0) {
            revert RebaseToken__InvalidAmountSent();
        }
        _;
    }

    /*************** CORE FUNCTIONS ***************/
    function mint(address _to, uint256 _amount) public onlyRole(MINT_AND_BURN) amountValid(_amount) {
        _settlePreviousIntrestAccrued(_to);
        s_IntrestRateToUser[_to] = s_intrestRate;
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public onlyRole(MINT_AND_BURN) amountValid(_amount) {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _settlePreviousIntrestAccrued(_from);
        _burn(_from, _amount);
    }

    function grantMintAndBurnRole(address _user) public onlyOwner {
        _grantRole(MINT_AND_BURN, _user);
    }

    function setIntrestRate(uint256 _newIntrestRate) external onlyOwner {
        if (_newIntrestRate > s_intrestRate) {
            revert RebaseToken__NewIntrestRateCannotIncrease(_newIntrestRate);
        }
        s_intrestRate = _newIntrestRate;
        emit IntrestRateUpdated(_newIntrestRate);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        uint256 principalAmount = super.balanceOf(_user);
        uint256 growthFactor = _growthInPrincipalSinceLasteUpdatedTimeStamp(_user);
        return principalAmount * growthFactor / PRECISION_FACTOR;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        _settlePreviousIntrestAccrued(msg.sender);
        _settlePreviousIntrestAccrued(to);
        if (s_IntrestRateToUser[to] == 0) {
            s_IntrestRateToUser[to] = s_IntrestRateToUser[msg.sender];
        }
        if (value == type(uint256).max) {
            value = balanceOf(msg.sender);
        }
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        _settlePreviousIntrestAccrued(from);
        _settlePreviousIntrestAccrued(to);
        if (s_IntrestRateToUser[to] == 0) {
            s_IntrestRateToUser[to] = s_IntrestRateToUser[from];
        }
        if (value == type(uint256).max) {
            value = balanceOf(from);
        }
        return super.transferFrom(from, to, value);
    }

    /*************** INTERNAL FUNCTIONS ***************/

    function _growthInPrincipalSinceLasteUpdatedTimeStamp(address _user) internal view returns (uint256) {
        uint256 timeElapsed = block.timestamp - s_LastUpdatedTimeStampToUser[_user];
        if (timeElapsed == 0 || s_IntrestRateToUser[_user] == 0) {
            return PRECISION_FACTOR;
        }
        uint256 linearGrowthFactor = PRECISION_FACTOR + (timeElapsed * s_IntrestRateToUser[_user]);
        return linearGrowthFactor;
    }

    /**
     * @dev we settle the users previous intrest accrued before minting new tokens
     * we alse set the lastUpdated Timestamp here for each user
     */
    function _settlePreviousIntrestAccrued(address _user) internal {
        uint256 previousBalance = super.balanceOf(_user);
        uint256 currentBalance = balanceOf(_user);
        uint256 amountToBeMinted = currentBalance - previousBalance;
        s_LastUpdatedTimeStampToUser[_user] = block.timestamp;
        _mint(_user, amountToBeMinted);
    }

    /*************** EXTERNAL VIEW / GETTER FUNCTIONS ***************/
    function getCurrentIntrestRate() external view returns (uint256) {
        return s_intrestRate;
    }

    function getIntrestRateToUser(address _user) external view returns (uint256) {
        return s_IntrestRateToUser[_user];
    }

    function getsLastUpdatedTimeStampToUser(address _user) external view returns (uint256) {
        return s_LastUpdatedTimeStampToUser[_user];
    }

    function getPrincipalAmount(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }
}
