// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

////////////    IMPORTS    ////////////
import { Test, console } from "forge-std/Test.sol";
import { HelperConfig } from "script/HelperConfig.s.sol";
import { StableCoin } from "src/StableCoin.sol";
import { StableCoinEngine } from "src/StableCoinEngine.sol";
import { DeployStableCoin } from "script/Deploy.s.sol";

contract TestStableCoinEngine is Test {
    HelperConfig config;
    StableCoin drs;
    StableCoinEngine scEngine;
    address USER = makeAddr("user");

    function setUp() public {
        DeployStableCoin deployer = new DeployStableCoin();
        (drs, scEngine, config) = deployer.run();
    }

    function testDeployment() public {
        console.log("drs :", address(drs));
        console.log("scEngine :", address(scEngine));
    }
}
