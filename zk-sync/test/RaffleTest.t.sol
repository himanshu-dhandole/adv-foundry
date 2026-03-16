// SPDX-Licanse-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/Deploy.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract RaffleTest is Test {
    error Raffle__NotEnoughEthSent();

    Raffle raffle;
    HelperConfig helperConfig;
    address USER = makeAddr("user");

    function setUp() public {
        DeployRaffle deploy = new DeployRaffle();
        (raffle, helperConfig) = deploy.deployRaffle();
        vm.deal(USER, 50e18);
    }

    function testGetEntranceFee() public {
        assertEq(raffle.getEntranceFee(), 0.01 ether);
    }

    function testRaffleLowEthRevert() public {
        vm.prank(USER);
        vm.expectRevert();
        raffle.enterRaffle();
    }

    function testRaffleEntersUserAndRegisters() public {
        vm.prank(USER);
        raffle.enterRaffle{value: 1 ether}();
        assertEq(raffle.getPlayerByIndex(0), USER);
    }
}
