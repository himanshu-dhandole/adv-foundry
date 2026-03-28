// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

////////////    IMPORTS    ////////////
import { StableCoin } from "./StableCoin.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20Mock } from "test/mocks/MockERC20.sol";
import { MockV3Aggregator } from "test/mocks/MockV3Aggregator.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// import {MockERC20} from "";

/**
 * @title Decentralised Stable Coin Engine
 * @author Himanshu Dhandole
 * @notice This is a Decentralised Stable Coin pegged to Indian Rupee
 * @dev the coin enforces Overcollateralisd (200%) , Arthematically and code Governed
 */
contract StableCoinEngine is ReentrancyGuard {
    ////////////    ERRORS    ////////////
    error SCEngine__AcceptedAddressLengthZero();
    error SCEngine__AmountCannotBeZero();
    error SCEngine__TransferFailed();
    error SCEngine__HealthFactorTooLow();

    ////////////    EVENTS    ////////////
    event CollateralDeposited(address indexed user, address indexed collateralAddrees, uint256 amount);

    ////////////    MODIFIERS    ////////////
    modifier validAmount(uint256 _amount) {
        if (_amount <= 0) {
            revert SCEngine__AmountCannotBeZero();
        }
        _;
    }

    ////////////    STATE VARIABLES    ////////////
    uint256 immutable REMAINING_PRECISION = 1e10;
    uint256 immutable PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MINIMUM_HEALTH_FACTOR = 1e18;
    mapping(address => address) private s_tokenAddressToPriceFeed;
    mapping(address => uint256) private s_userToDRSminted;
    mapping(address userAddress => mapping(address tokenAddress => uint256 amount)) private s_CollateralToUser;
    address[] private s_AcceptedTokens;
    StableCoin immutable i_DRS;

    ////////////    CONSTRUCTOR    ////////////
    constructor(address[] memory _AcceptedTokenAddress, address[] memory _TokenPriceFeeds, StableCoin _DRS) {
        if (_AcceptedTokenAddress.length != 0) {
            for (uint256 i = 0; i < _AcceptedTokenAddress.length; i++) {
                s_tokenAddressToPriceFeed[_AcceptedTokenAddress[i]] = _TokenPriceFeeds[i];
                s_AcceptedTokens.push(_AcceptedTokenAddress[i]);
            }
        } else {
            revert SCEngine__AcceptedAddressLengthZero();
        }
        i_DRS = _DRS;
    }

    ////////////    CORE FUNCTIONS    ////////////
    function depositCollateral(address _collateralAddress, uint256 _amount) public validAmount(_amount) {
        _depositCollateral(_collateralAddress, _amount);
        _checkHealthFactorOrRevert(msg.sender);
    }
    function mintDRS() public { }

    function reedemCollateral() public { }
    function burnDRS() public { }
    function liquidate() public { }

    ////////////    INTERNAL FUNCTIONS   ////////////

    function _checkHealthFactorOrRevert(address _user) internal view {
        (uint256 totalMinted, uint256 totalCollateralInRupees) = _getAccountInformation(_user);
        uint256 healthFactor = _getHealthFactor(totalMinted, totalCollateralInRupees);
        if (healthFactor < MINIMUM_HEALTH_FACTOR) {
            revert SCEngine__HealthFactorTooLow();
        }
    }

    function _depositCollateral(address _collateralAddress, uint256 _amount) private nonReentrant {
        s_CollateralToUser[msg.sender][_collateralAddress] += _amount;
        emit CollateralDeposited(msg.sender, _collateralAddress, _amount);
        IERC20(_collateralAddress).approve(address(this), _amount);
        bool success = IERC20(_collateralAddress).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address _user) internal view returns (uint256, uint256) {
        uint256 DRSMinted = s_userToDRSminted[_user];
        uint256 totalCollateralInRs = _getCollateralInRupees(_user);
        return (totalCollateralInRs, DRSMinted);
    }

    function _getCollateralInRupees(address _user) internal view returns (uint256) {
        uint256 totalCollateralInRs = 0;
        for (uint256 i = 0; i < s_AcceptedTokens.length; i++) {
            uint256 collateral = s_CollateralToUser[_user][s_AcceptedTokens[i]];
            (, int256 price,,,) =
                AggregatorV3Interface(s_tokenAddressToPriceFeed[s_AcceptedTokens[i]]).latestRoundData();
            totalCollateralInRs += (collateral * (uint256(price) * REMAINING_PRECISION) / PRECISION);
        }
        return totalCollateralInRs;
    }

    // at every given moment the DSR should be 200% overcollateralised
    // at 100 collateral i can only get 50 loan
    function _getHealthFactor(uint256 _totalDSCMintedByUser, uint256 _totalCollateralInRupees)
        internal
        pure
        returns (uint256)
    {
        if (_totalDSCMintedByUser == 0) {
            return type(uint96).max;
        }
        uint256 collateralAdjusted = (_totalCollateralInRupees * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjusted * PRECISION) / _totalDSCMintedByUser;
    }

    ////////////    EXTERNAL VIEW FUNCTIONS   ////////////
}
