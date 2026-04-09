// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/*************** INTERFACE (REBASE TOKEN) ***************/

interface I_RebaseToken {
    function mint(address _to, uint256 _amount) external;

    function burn(address _from, uint256 _amount) external;

    function grantMintAndBurnRole(address _user) external;

    function setIntrestRate(uint256 _newIntrestRate) external;

    function balanceOf(address _user) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
