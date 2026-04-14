// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AuraToken} from "src/AuraToken.sol";
import {MerkleAirdrop} from "src/MerkleAirdrop.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployScript is Script {
    bytes32 private s_Root = 0xb1e815a99ee56f7043ed94e7e2316238187a59d85c211d06f9be7c5f94424aec;

    function deployMerkleAirdropAndToken() public returns (MerkleAirdrop, AuraToken) {
        AuraToken tkn = new AuraToken();
        MerkleAirdrop merkle = new MerkleAirdrop(s_Root, IERC20(address(tkn)));
        tkn.mint(tkn.owner(), 100000 ether);
        tkn.transfer(address(merkle), 100000 ether);
        console.log("token Address : ", address(tkn));
        console.log("Merkle Airdrop Address : ", address(merkle));
        return (merkle, tkn);
    }

    function run() public returns (MerkleAirdrop, AuraToken) {
        return deployMerkleAirdropAndToken();
    }
}
