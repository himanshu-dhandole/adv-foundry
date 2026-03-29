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
    error SCEngine__MintFailed();
    error SCEngine__HealthFactorTooLow();
    error SCEngine__UserCannotGetLiquidated();
    error SCEngine__DebtTooLow();

    ////////////    EVENTS    ////////////
    event CollateralDeposited(address indexed user, address indexed collateralAddrees, uint256 amount);
    event DSR_Minted(address indexed user, uint256 indexed amount);
    event CollateralWithdrawn(address indexed from, address indexed to, address collateralAddress, uint256 amount);
    event DSR_Burned(address indexed user, address burnedfrom, uint256 amount);

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
    uint256 private constant BONUS_FOR_LIQUIDATION = 10;
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

    function depositCollateralAndMintDRS(address _collateralAddress, uint256 _collateralAmount, uint256 _DRStoMint)
        public
    {
        _depositCollateral(_collateralAddress, _collateralAmount);
        _mint(_DRStoMint);
        _checkHealthFactorOrRevert(msg.sender);
    }

    function depositCollateral(address _collateralAddress, uint256 _amount) public validAmount(_amount) {
        _depositCollateral(_collateralAddress, _amount);
    }

    function mintDRS(uint256 _amount) public validAmount(_amount) {
        _mint(_amount);
        _checkHealthFactorOrRevert(msg.sender);
    }

    function burnAndReedemCollateral(address _collateralAddress, uint256 _collateralAmount, uint256 _amountDRStoBurn)
        public
    {
        _burn(msg.sender, msg.sender, _amountDRStoBurn);
        _reedemCollateral(msg.sender, msg.sender, _collateralAddress, _collateralAmount);
        _checkHealthFactorOrRevert(msg.sender);
    }

    function reedemCollateral(address _collateralAddress, uint256 _amount) public validAmount(_amount) {
        _reedemCollateral(msg.sender, msg.sender, _collateralAddress, _amount);
        _checkHealthFactorOrRevert(msg.sender);
    }

    function burnDRS(uint256 _amount) public validAmount(_amount) {
        _burn(msg.sender, msg.sender, _amount);
    }

    function liquidate(address _badUser, address _collateralAddress, uint256 _debtToCoverDRS)
        public
        validAmount(_debtToCoverDRS)
    {
        if (_debtToCoverDRS > s_userToDRSminted[_badUser]) {
            revert SCEngine__DebtTooLow();
        }
        uint256 startingHealthFactor = getHealthFactor(_badUser);
        if (startingHealthFactor > MINIMUM_HEALTH_FACTOR) {
            revert SCEngine__UserCannotGetLiquidated();
        }
        uint256 collateralNeededToSettleDebt = _convertDRStoCollateral(_collateralAddress, _debtToCoverDRS);

        // 10% bonus fro liquidator
        uint256 liquiadtorBonus = (collateralNeededToSettleDebt * BONUS_FOR_LIQUIDATION) / LIQUIDATION_PRECISION;
        uint256 totalAmountToReedem = liquiadtorBonus + collateralNeededToSettleDebt;
        _burn(msg.sender, _badUser, _debtToCoverDRS);
        _reedemCollateral(_badUser, msg.sender, _collateralAddress, totalAmountToReedem);

        if (startingHealthFactor >= getHealthFactor(_badUser)) {
            revert SCEngine__UserCannotGetLiquidated();
        }
    }

    ////////////    INTERNAL FUNCTIONS   ////////////

    function _convertDRStoCollateral(address _collateralAddress, uint256 _amount) internal view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenAddressToPriceFeed[_collateralAddress]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (_amount * PRECISION) / (uint256(price) * REMAINING_PRECISION);
    }

    function _isLiquidatable(address _user) internal view returns (bool) {
        (uint256 DRSMinted, uint256 totalCollateralInRs) = _getAccountInformation(_user);
        uint256 healthFactor = _getHealthFactor(DRSMinted, totalCollateralInRs);
        if (healthFactor > MINIMUM_HEALTH_FACTOR) {
            return false;
        }
        return true;
    }

    function _burn(address _burnFrom, address _badUser, uint256 _amount) internal {
        s_userToDRSminted[_badUser] -= _amount;
        emit DSR_Burned(_badUser, _burnFrom, _amount);
        bool success = i_DRS.transferFrom(_burnFrom, address(this), _amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
        i_DRS.burn(_amount);
    }

    function _reedemCollateral(address _from, address _to, address _collateralAddress, uint256 _amount)
        internal
        nonReentrant
    {
        s_CollateralToUser[_from][_collateralAddress] -= _amount;
        emit CollateralWithdrawn(_from, _to, _collateralAddress, _amount);
        bool success = ERC20Mock(_collateralAddress).transfer(_to, _amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function _mint(uint256 _amount) internal nonReentrant {
        s_userToDRSminted[msg.sender] += _amount;
        emit DSR_Minted(msg.sender, _amount);
        bool success = i_DRS.mint(msg.sender, _amount);
        if (!success) {
            revert SCEngine__MintFailed();
        }
    }

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
        // IERC20(_collateralAddress).approve(address(this), _amount);
        bool success = IERC20(_collateralAddress).transferFrom(msg.sender, address(this), _amount);
        if (!success) {
            revert SCEngine__TransferFailed();
        }
    }

    function _getAccountInformation(address _user) internal view returns (uint256, uint256) {
        uint256 DRSMinted = s_userToDRSminted[_user];
        uint256 totalCollateralInRs = _getCollateralInUSD(_user);
        return (DRSMinted, totalCollateralInRs);
    }

    function _getCollateralInUSD(address _user) internal view returns (uint256) {
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

    function getHealthFactor(address user) public view returns (uint256) {
        (uint256 totalMinted, uint256 totalCollateralInRupees) = _getAccountInformation(user);
        return _getHealthFactor(totalMinted, totalCollateralInRupees);
    }

    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalDrsMinted, uint256 totalCollateralInRupees)
    {
        return _getAccountInformation(user);
    }

    function getAccountCollateralValue(address user) external view returns (uint256) {
        return _getCollateralInUSD(user);
    }

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_CollateralToUser[user][token];
    }

    function getDrsMinted(address user) external view returns (uint256) {
        return s_userToDRSminted[user];
    }

    function getTokenPriceFeed(address token) external view returns (address) {
        return s_tokenAddressToPriceFeed[token];
    }

    function getAcceptedTokens() external view returns (address[] memory) {
        return s_AcceptedTokens;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinimumHealthFactor() external pure returns (uint256) {
        return MINIMUM_HEALTH_FACTOR;
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getDrsAddress() external view returns (address) {
        return address(i_DRS);
    }
}
