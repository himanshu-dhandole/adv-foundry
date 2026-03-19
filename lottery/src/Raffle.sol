// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle
 * @author Himanshu Dhandole
 * @notice This is a simple raffle contract that allows users to enter the raffle by paying an entrance fee.
 * @dev This implements chainLink VRFV2.5.
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Events
     */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RandomWordsRequestId(uint256 indexed requestId);

    /**
     * Custom Errors
     */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleClosed();
    error Raffle__UpkeepNotNeeded(
        uint256 contractBalance,
        uint256 rafleState,
        uint256 playersLength
    );

    /**
     * Enums
     */
    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    /**
     * Type Declarations
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUMBER_OF_WORDS = 1;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_interval;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] public s_players;
    uint256 private s_lastBlockTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    constructor(
        uint256 _entranceFee,
        address _vrfCordinator,
        uint256 _interval,
        bytes32 _gasLane,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_keyHash = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;

        s_lastBlockTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughEthSent();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleClosed();
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * @notice Keeper Function.
     * @dev checks timestamp , state , player array
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool intervalPassed = ((block.timestamp - s_lastBlockTimeStamp) >=
            i_interval);
        bool has_OPEN_State = (s_raffleState == RaffleState.OPEN);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = (address(this).balance > 0);
        upkeepNeeded =
            intervalPassed &&
            has_OPEN_State &&
            hasPlayers &&
            hasBalance;
        return (upkeepNeeded, "");
    }

    /**
     * @notice Pick a winner Function.
     * @dev called by the keeper node (chainlink)
     */
    function performUpkeep(bytes calldata /* performData */) public {
        // if ((block.timestamp - s_lastBlockTimeStamp) < i_interval) revert();
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                uint256(s_raffleState),
                s_players.length
            );
        }
        s_raffleState = RaffleState.CALCULATING_WINNER;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUMBER_OF_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);

        emit RandomWordsRequestId(requestId);
    }

    function fulfillRandomWords(
        uint256,
        /*requestId*/
        uint256[] calldata randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_lastBlockTimeStamp = block.timestamp;
        s_players = new address payable[](0);
        emit WinnerPicked(s_recentWinner);

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) revert Raffle__TransferFailed();
    }

    /**
     * Getter Functions / View Functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayerByIndex(uint256 _index) external view returns (address) {
        return s_players[_index];
    }

    function getLatestWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastBlockTimestamp() external view returns (uint256) {
        return s_lastBlockTimeStamp;
    }
}
