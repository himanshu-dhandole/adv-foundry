// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

contract LowLevelCall {
    // state variables
    address public s_someAddress;
    uint256 public s_someAmount;

    function transferFrom(address from, uint256 amount) public {
        s_someAddress = from;
        s_someAmount = amount;
    }

    function getFunctionSelector() public pure returns (bytes4) {
        return bytes4(keccak256(bytes("transferFrom(address,uint256)")));
    }

    function getEncodedArgs(
        address _from,
        uint256 amount
    ) public pure returns (bytes memory) {
        return abi.encodeWithSelector(getFunctionSelector(), _from, amount);
    }

    function callTransferLowLevel(
        address _from,
        uint256 amount
    ) public returns (bool) {
        (bool success, ) = address(this).call(getEncodedArgs(_from, amount));
        return (success);
    }
}
