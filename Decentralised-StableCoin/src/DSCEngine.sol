// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 *  Imports
 */
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title Decentralised Stable Coin Engine
 * @author Himanshu Dhandole
 * @notice This has core functions of the DSC
 * the DSC coin is :
 * Decentralised governance (liquidation model)
 * pegged to US dollar
 * ExoExogenous along wETH and wBTC (both are erc20)
 *
 * @dev this is Loosly based on DAO / Maker DAO protocol
 */
contract DSCEngine is ReentrancyGuard {
    /**
     * Custom Errors
     */
    error DSCEngine__AmountCannotBeZero();
    error DSCEngine__TokenNotAllowed(address _collateralAddress);
    error DSCEngine__LowBalanceInwallet();
    error DSCEngine__FailedToSetCollateralAddresses();
    error DSCEngine__TransferFailed();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorTooLow();

    /**
     * Events
     */
    event CollateralDepositSuccess(
        address indexed _depositor, address indexed _collateralAddress, uint256 indexed _amount
    );

    /**
     * State Variables
     */
    mapping(address collateralAddress => address priceFeed) private s_priceFeeds;
    mapping(address depositor => mapping(address collateralAddress => uint256 amount)) private s_collateralToUser;
    mapping(address => uint256) public s_DscMinted;
    DecentralisedStableCoin private immutable i_dsc;
    address[] private s_CollateralTokens;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;

    /**
     * Modifiers
     */
    modifier checkValidAmount(uint256 _amount) {
        if (_amount <= 0) revert DSCEngine__AmountCannotBeZero();
        _;
    }
    modifier checkAllowedToken(address _collateralAddress) {
        if (s_priceFeeds[_collateralAddress] == address(0)) {
            revert DSCEngine__TokenNotAllowed(_collateralAddress);
        }
        _;
    }

    /**
     * Constructor
     */
    constructor(
        address[] memory _AlloewedTokenAddresses,
        address[] memory _AllPriceFeeds,
        address _decentralisedStableCoin
    ) {
        if (_AlloewedTokenAddresses.length != _AllPriceFeeds.length) {
            revert DSCEngine__FailedToSetCollateralAddresses();
        }
        if (_AlloewedTokenAddresses.length != 0 && _AllPriceFeeds.length != 0) {
            for (uint256 i = 0; i < _AlloewedTokenAddresses.length; i++) {
                s_priceFeeds[_AlloewedTokenAddresses[i]] = _AllPriceFeeds[i];
                s_CollateralTokens.push(_AlloewedTokenAddresses[i]);
            }
        }
        i_dsc = DecentralisedStableCoin(_decentralisedStableCoin);
    }

    /**
     * Core Functions
     */
    function depositCollateral(address _collateralAddress, uint256 _amount)
        public
        checkValidAmount(_amount)
        checkAllowedToken(_collateralAddress)
        nonReentrant
    {
        s_collateralToUser[msg.sender][_collateralAddress] += _amount;
        emit CollateralDepositSuccess(msg.sender, _collateralAddress, _amount);
        bool success = IERC20(_collateralAddress).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function withdrawCollateral() public {}

    function mintDSC(uint256 _amount) public checkValidAmount(_amount) {
        s_DscMinted[msg.sender] += _amount;
        // check the health ratio to be valid
        _checkHealthFactorAndRevert(msg.sender);

        // mint if all OK
        bool success = i_dsc.mint(_amount);
        if (!success) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC() public {}

    function liquidate() public {}

    // internal functions

    function _getAccountInformation(address _user) public view returns (uint256, uint256) {
        // total minted
        uint256 totalMinted = s_DscMinted[_user];
        // total collateral in USD
        uint256 totalCollateralInUSD = getAccountTotalCollateralInUSD(_user);
        return (totalMinted, totalCollateralInUSD);
    }

    /**
     * @dev this returns the number to determine the health factor below 1 is bad !
     */
    function _getHealthFactor(address _user) internal view returns (uint256) {
        // total minted
        // total collateral in USD
        (uint256 totalMinted, uint256 totalCollateralInUSD) = _getAccountInformation(_user);

        // watch again
        uint256 collateralAdjustedForLiquidationThreshold =
            (totalCollateralInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForLiquidationThreshold * 1e18) / totalMinted;
    }

    function _checkHealthFactorAndRevert(address _user) internal view {
        // check the health factor
        // revert if less than 1
        uint256 healthfactor = _getHealthFactor(_user);
        if (healthfactor < 1e18) {
            revert DSCEngine__HealthFactorTooLow();
        }
    }

    // external view functions
    function getAccountTotalCollateralInUSD(address _user) public view returns (uint256) {
        uint256 totalCollateralInUSD = 0;
        for (uint256 i = 0; i < s_CollateralTokens.length; i++) {
            address token = s_CollateralTokens[i];
            uint256 amount = s_collateralToUser[_user][token];

            // watch again in video
            totalCollateralInUSD += getValueInUSD(token, amount);
        }

        return totalCollateralInUSD;
    }

    function getValueInUSD(address _token, uint256 _amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return uint256(((uint256(price) * 1e10) * _amount) / 1e18);
    }
}
