// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DecentralisedStableCoin} from "src/DecentralisedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";

contract Handler is Test {
    DecentralisedStableCoin dsc;
    DSCEngine dscEngine;
    address[] validCollateralAddresses;
    address wETH;
    address wBTC;

    constructor(DecentralisedStableCoin _dsc, DSCEngine _dscEngine) {
        dsc = _dsc;
        dscEngine = _dscEngine;
        validCollateralAddresses = dscEngine.getCollateralTokens();
        wETH = validCollateralAddresses[0];
        wBTC = validCollateralAddresses[1];
    }

    function depositCollateral(uint256 _seed, uint256 _amount) public {
        // dscEngine.depositCollateral(_collateralAddress, _amount);
        _amount = bound(_amount, 1, type(uint96).max);
        ERC20Mock collateral = _getCollateralFromSeed(_seed);
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, _amount);
        collateral.approve(address(dscEngine), _amount);
        dscEngine.depositCollateral(address(collateral), _amount);
        vm.stopPrank();
    }

    function _getCollateralFromSeed(uint256 _seed) private returns (ERC20Mock) {
        if (_seed % 2 == 0) {
            return ERC20Mock(wETH);
        }
        return ERC20Mock(wBTC);
    }
}
