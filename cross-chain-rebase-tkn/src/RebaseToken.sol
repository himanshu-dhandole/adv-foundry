// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*************** IMPORTS ***************/
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Rebase Token
 * @author Himanshu Dhandole
 * @notice this token has a decreasing intrest rate for adapters
 */
contract RebaseToken is ERC20 {
    /*************** EVENTS ***************/
    event IntrestRateUpdated(uint256 indexed newIntrestrate);
    event RebaseTokenMinted(address indexed user, uint256 indexed amount);

    /*************** ERRORS ***************/
    error RebaseToken__NewIntrestRateCannotIncrease(uint256 intrestRate);
    error RebaseToken__InvalidAmountSent();

    /*************** STATE VARIABLES ***************/
    uint256 constant PRECISION_FACTOR = 1e18;
    uint256 private s_intrestRate = 5e18;
    mapping(address => uint256) private s_IntrestRateToUser;
    mapping(address => uint256) private s_LastUpdatedTimeStampToUser;

    /*************** CONSTRUCTOR ***************/
    constructor() ERC20("Rebase Token", "RTK") {}

    /*************** MODIFIER ***************/
    modifier amountValid(uint256 _amount) {
        if (_amount <= 0) {
            revert RebaseToken__InvalidAmountSent();
        }
        _;
    }

    /*************** CORE FUNCTIONS ***************/
    function mint(address _to, uint256 _amount) public amountValid(_amount) {
        _settlePreviousIntrestAccrued(_to);
        s_IntrestRateToUser[_to] = s_intrestRate;
        _mint(_to, _amount);
        emit RebaseTokenMinted(_to, _amount);
    }

    function setIntrestRate(uint256 _newIntrestRate) external {
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
        // not complete
        s_LastUpdatedTimeStampToUser[_user] = block.timestamp;
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
}
