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
    error DSCEngine__BurnFailed();
    error DSCEngine__HealthFactorNotChanged();
    error DSCEngine__NotLiquidatable();
    error DSCEngine__DebtIsLow();

    /**
     * Events
     */
    event CollateralDepositSuccess(
        address indexed _depositor, address indexed _collateralAddress, uint256 indexed _amount
    );
    event CollateralReedemd(
        address indexed _fromReedmed, address indexed _toSent, address indexed _collateralAddress, uint256 _amount
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
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;

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
    function depositCollateralAndMintDSC(address _collateralAddress, uint256 _amount, uint256 _amountToBeMinted)
        public
        checkValidAmount(_amount)
        checkAllowedToken(_collateralAddress)
    {
        depositCollateral(_collateralAddress, _amount);
        mintDSC(_amountToBeMinted);
    }

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

    function mintDSC(uint256 _amount) public checkValidAmount(_amount) {
        s_DscMinted[msg.sender] += _amount;
        // check the health ratio to be valid
        _checkHealthFactorAndRevert(msg.sender);

        // mint if all OK
        bool success = i_dsc.mint(msg.sender, _amount);
        if (!success) {
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * Withdrawl Functions
     */
    function reedemCollateralAndBurnDSC(address _collateralAddress, uint256 _amount, uint256 _amountToBeBurned)
        public
        checkValidAmount(_amount)
    {
        burnDSC(_amountToBeBurned);
        reedemCollateral(_collateralAddress, _amount);
        _checkHealthFactorAndRevert(msg.sender);
    }

    function reedemCollateral(address _collateralAddress, uint256 _amount)
        public
        checkValidAmount(_amount)
        nonReentrant
    {
        _reedemCollateral(msg.sender, msg.sender, _collateralAddress, _amount);
        _checkHealthFactorAndRevert(msg.sender);
    }

    function burnDSC(uint256 _amount) public checkValidAmount(_amount) nonReentrant {
        _burnDSC(_amount, msg.sender, msg.sender);
    }

    /**
     * @notice this function checks the healthfactor Identifies bad User and tries to settle this
     * the liquidator settles the debt for bad user
     * the liquidator gets 10% for settling the bad Users debt
     */
    function liquidate(address _badUser, address _collateralAddress, uint256 _debtToCover)
        public
        checkValidAmount(_debtToCover)
    {
        if (_debtToCover > s_DscMinted[_badUser]) {
            revert DSCEngine__DebtIsLow();
        }
        uint256 startingHealthfactor = getHealthFactor(_badUser);
        if (startingHealthfactor > MIN_HEALTH_FACTOR) {
            revert DSCEngine__NotLiquidatable();
        }
        uint256 collateralNeededToSettleDebt = _convertDscToCollateral(_collateralAddress, _debtToCover);

        // giving 10% more to the liquidator as a bonus
        // the amount is given by our treasury
        uint256 liquidatorsBonus = (collateralNeededToSettleDebt * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalAmountToReedem = collateralNeededToSettleDebt + liquidatorsBonus;
        _burnDSC(_debtToCover, _badUser, msg.sender);
        _reedemCollateral(_badUser, msg.sender, _collateralAddress, totalAmountToReedem);
        if (startingHealthfactor >= getHealthFactor(_badUser)) {
            revert DSCEngine__HealthFactorNotChanged();
        }
    }

    // internal functions

    function _burnDSC(uint256 _amountToBurn, address _forWho, address _dscFrom) internal {
        s_DscMinted[_forWho] -= _amountToBurn;
        bool success = i_dsc.transferFrom(_dscFrom, address(this), _amountToBurn);
        if (!success) {
            revert DSCEngine__BurnFailed();
        }
        i_dsc.burn(_amountToBurn);
    }

    function _reedemCollateral(address _from, address _to, address _collateralAddress, uint256 _amount) internal {
        s_collateralToUser[_from][_collateralAddress] -= _amount;
        emit CollateralReedemd(_from, _to, _collateralAddress, _amount);

        bool success = IERC20(_collateralAddress).transfer(_to, _amount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    function _convertDscToCollateral(address _collateralAddress, uint256 _debtToCover) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[_collateralAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (_debtToCover * PRECISION / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

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
    function _calculateHealthFactor(uint256 totalMinted, uint256 totalCollateralInUSD) internal view returns (uint256) {
        if (totalMinted == 0) return type(uint256).max;

        // watch again
        uint256 collateralAdjustedForLiquidationThreshold =
            (totalCollateralInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForLiquidationThreshold * PRECISION) / totalMinted;
    }

    function _checkHealthFactorAndRevert(address _user) internal view {
        // check the health factor
        // revert if less than 1
        uint256 healthfactor = getHealthFactor(_user);
        if (healthfactor < MIN_HEALTH_FACTOR) {
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
        return uint256(((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION);
    }

    function getCollateralToUser(address _collateralAddress) external view returns (uint256) {
        return s_collateralToUser[msg.sender][_collateralAddress];
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralToUser[user][token];
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_CollateralTokens;
    }

    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getDscMinted(address user) external view returns (uint256) {
        return s_DscMinted[user];
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getHealthFactor(address _user) public view returns (uint256) {
        (uint256 totalMinted, uint256 totalCollateralInUSD) = _getAccountInformation(_user);
        return _calculateHealthFactor(totalMinted, totalCollateralInUSD);
    }
}
