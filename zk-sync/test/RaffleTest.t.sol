// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {DeployRaffle} from "script/Deploy.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {LinkToken} from "./mocks/LinkToken.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    error Raffle__NotEnoughEthSent();

    Raffle raffle;
    HelperConfig helperConfig;
    address USER = makeAddr("user");
    uint56 interval = 30;

    function setUp() public {
        DeployRaffle deploy = new DeployRaffle();
        (raffle, helperConfig) = deploy.deployRaffle();
        vm.deal(USER, 50e18);
        LinkToken token = new LinkToken();
        token.mint(USER, 500000 ether);
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

    modifier enteredRaffle() {
        vm.prank(USER);
        raffle.enterRaffle{value: 0.01 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleRevertsWhenNoUpkeepNeeded() public enteredRaffle {
        vm.prank(USER);
        (bool needed, ) = raffle.checkUpkeep("0x00");
        //assert
        assert(needed == true);
    }

    function testRaffleExecutesThePerformUpkeepAndSpitsOutWinner()
        public
        enteredRaffle
    {
        uint160 startingIndex = 1;
        uint160 noOfPlayers = 4;
        for (uint160 i = startingIndex; i < noOfPlayers + startingIndex; i++) {
            hoax(address(i), 0.01 ether);
            raffle.enterRaffle{value: 0.01 ether}();
        }

        vm.recordLogs();
        vm.prank(USER);
        raffle.performUpkeep("0x00");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 requestId = uint256(entries[1].topics[1]);
        console2.log(uint256(requestId));

        VRFCoordinatorV2_5Mock(helperConfig.getConfig().vrfCoordinatorAddress)
            .fulfillRandomWords(requestId, address(raffle));

        address winner = raffle.getLatestWinner();
        console2.log("winner : ", winner);
    }

    function testGetSubId() public enteredRaffle {
        vm.recordLogs();
        vm.prank(USER);
        raffle.performUpkeep("0x00");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        console2.log(uint256(requestId));
    }
}
