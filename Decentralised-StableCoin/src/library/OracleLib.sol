// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StaleOracleData();

    function getLatestRoundDataAndRevertIfStale(AggregatorV3Interface _priceFeed)
        public
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            _priceFeed.latestRoundData();
        if (updatedAt == 0 || roundId > answeredInRound) {
            revert OracleLib__StaleOracleData();
        }
        uint256 startedSince = block.timestamp - startedAt;
        if (startedSince > 3 hours) {
            revert OracleLib__StaleOracleData();
        }

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
