// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AuraToken} from "src/AuraToken.sol";
import {MerkleAirdrop} from "src/MerkleAirdrop.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployScript is Script {
    bytes32 private s_Root = 0xca5d007637195a890bfdc01c41230aa4c86e32f61e89c0aa7319b5f0f4634274;

    function deployMerkleAirdropAndToken() public returns (MerkleAirdrop, AuraToken) {
        vm.startBroadcast();
        AuraToken tkn = new AuraToken();
        MerkleAirdrop merkle = new MerkleAirdrop(s_Root, IERC20(address(tkn)));
        tkn.mint(tkn.owner(), 100000 ether);
        tkn.transfer(address(merkle), 100000 ether);
        vm.stopBroadcast();
        console.log("token Address : ", address(tkn));
        console.log("Merkle Airdrop Address : ", address(merkle));
        return (merkle, tkn);
    }

    function run() public returns (MerkleAirdrop, AuraToken) {
        return deployMerkleAirdropAndToken();
    }
}
