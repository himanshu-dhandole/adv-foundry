// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle contract
 * @notice we let people take entry and pick a winner
 * @dev we use chainlink VRF for random numbers
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__NotEnoughEthSent(uint256 amountSent);
    error Raffle__RaffleStateISNotOPEN();
    error Raffle__NotEnoughTimePassed();
    error Raffle__WinnerCannotBePaid();

    /**
     * Events
     */
    event PlayerEntered(address indexed player);

    /**
     * Enums
     */
    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    /**
     * State variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private constant INTERVAL = 3000;
    uint32 private constant NO_OF_WORDS = 1;
    uint256 private immutable ENTRANCE_FEE = 0.01 ether;
    RaffleState private s_raffleState;
    address payable[] s_players;
    bytes32 private s_keyHash;
    uint256 private s_subId;
    uint32 private s_callbackGasLimit;
    uint256 private s_lastBlockTimeStamp;
    address payable s_latestWinner;

    constructor(
        address _vrfCoordinatorAddress,
        bytes32 _keyHash,
        uint256 _subId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinatorAddress) {
        s_raffleState = RaffleState.OPEN;
        s_keyHash = _keyHash;
        s_subId = _subId;
        s_callbackGasLimit = _callbackGasLimit;
        s_lastBlockTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < ENTRANCE_FEE) {
            revert Raffle__NotEnoughEthSent(msg.value);
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleStateISNotOPEN();
        }

        s_players.push(payable(msg.sender));
        emit PlayerEntered(msg.sender);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool intervalCheck = (block.timestamp - s_lastBlockTimeStamp) >
            INTERVAL;
        bool stateCheck = s_raffleState == RaffleState.OPEN;
        bool playersCheck = s_players.length != 0;
        bool balanceCheck = address(this).balance != 0;
        return (
            intervalCheck && stateCheck && playersCheck && balanceCheck,
            ""
        );
    }

    function performUpkeep(bytes calldata /* performData */) public {
        if ((block.timestamp - s_lastBlockTimeStamp) < INTERVAL) {
            revert Raffle__NotEnoughTimePassed();
        }
        s_raffleState = RaffleState.CALCULATING_WINNER;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: s_callbackGasLimit,
                numWords: NO_OF_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 winnerIndex = randomWords[0] % s_players.length;
        s_latestWinner = s_players[winnerIndex];
        (bool success, ) = s_latestWinner.call{value: address(this).balance}(
            ""
        );
        if (success != true) revert Raffle__WinnerCannotBePaid();
        s_raffleState = RaffleState.OPEN;
        s_lastBlockTimeStamp = block.timestamp;
        s_players = new address payable[](0);
    }

    /**
     * View / Getter functions
     */
    function getPlayerByIndex(uint256 _index) external view returns (address) {
        return s_players[_index];
    }

    function getEntranceFee() external view returns (uint256) {
        return ENTRANCE_FEE;
    }
}
