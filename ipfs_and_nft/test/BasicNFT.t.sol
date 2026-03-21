// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {BasicNFT} from "src/BasicNFT.sol";
import {DeployBasicNFT} from "script/DeployBasicNFT.s.sol";

contract TestBasicNFT is Test {
    BasicNFT public basicNFT;
    DeployBasicNFT public deployer;
    address public USER = makeAddr("user");

    function setUp() public {
        deployer = new DeployBasicNFT();
        basicNFT = deployer.run();
        vm.deal(USER, 50 ether);
    }

    function testMintingNFT() public {
        // arrange
        vm.prank(USER);

        // act
        basicNFT.mintNFT("cyphrin is the best teacher");
        uint256 currentTokenNumber = basicNFT.getCurrentTokenNumber();
        string memory uri = basicNFT.getTokenToURI(0);
        console.log(uri);

        // assert
        assert(currentTokenNumber - 1 == 0);
        assert(basicNFT.balanceOf(USER) == 1);
        assert(
            keccak256(abi.encodePacked(uri)) ==
                keccak256(abi.encodePacked(basicNFT.getTokenToURI(0)))
        );
    }

    function testNFTname() public {
        string memory name = basicNFT.name();
        string memory expectedname = "Non Fungible Friends";
        console.log("name : ", name);
        console.log("Expectedname : ", expectedname);
        assert(
            keccak256(abi.encodePacked(name)) ==
                keccak256(abi.encodePacked(expectedname))
        );
    }
}
