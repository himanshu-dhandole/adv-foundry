// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract TestRaffle is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    uint256 entranceFee;
    address vrfCordinator;
    uint256 interval;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address USER = makeAddr("user");
    address PLAYER1 = makeAddr("player");

    // SETUP

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployRaffle();
        console.log(address(raffle));
        vm.deal(USER, 50e18);
        vm.deal(PLAYER1, 50e18);
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        entranceFee = config.entranceFee;
        vrfCordinator = config.vrfCordinator;
        interval = config.interval;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
    }

    // MODIFIER for PlaayerEntry
    modifier raffleEntered() {
        vm.prank(USER);
        raffle.enterRaffle{value: 0.01 ether}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testRaffleStateOPEN() public {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testIntervalTime() public {
        assert(interval == 30);
    }

    function testLowAmountSentinRaffle() public {
        vm.prank(USER);
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle{value: 0.00001 ether}();
    }

    function testPlayerEnteryInRaffle() public {
        vm.prank(USER);
        raffle.enterRaffle{value: 0.01 ether}();
        assert(raffle.getPlayerByIndex(0) == USER);
    }

    function testExpectEmitAtPlayerEntry() public {
        vm.prank(USER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(USER);
        raffle.enterRaffle{value: 0.01 ether}();
    }

    // CHECK UPKEEP

    function testDontAllowPlayersWhenCALCULATING_WINNER() public raffleEntered {
        raffle.performUpkeep("");
        vm.expectRevert();
        vm.prank(USER);
        raffle.enterRaffle{value: 1 ether}();
    }

    // PERFORM UPKEEP

    function testUpkeepEmitsRandomWordsRequestId() public raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        console.log("Number of logs recorded:", entries.length);
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(requestId > 0);
        assert(uint256(rState) == 1);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testRaffleFullFillRandomWordsRevert(
        uint256 request
    ) public raffleEntered skipFork {
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCordinator).fulfillRandomWords(
            request,
            address(raffle)
        );
    }

    function testRafflePicksWinnerAndResetsArraySendsMoneyToWinner()
        public
        raffleEntered
        skipFork
    {
        //Arrange
        uint256 satartingIndex = 1;
        uint256 additionalParticipants = 3;
        address expectedWinner = address(1);
        for (
            uint256 i = satartingIndex;
            i < additionalParticipants + satartingIndex;
            i++
        ) {
            address players = address(uint160(i));
            hoax(players, 0.01 ether);
            raffle.enterRaffle{value: 0.01 ether}();
        }

        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 recipt = entries[1].topics[1];

        VRFCoordinatorV2_5Mock(vrfCordinator).fulfillRandomWords(
            uint256(recipt),
            address(raffle)
        );

        //Assert
        address winner = raffle.getLatestWinner();
        assert(winner == expectedWinner);
    }
}
