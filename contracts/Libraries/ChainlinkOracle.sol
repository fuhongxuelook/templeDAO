// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library ChainlinkOracle {

    function getLatestPrice(address priceFeed) internal view returns (int) {
        require(priceFeed != address(0), "E: error");

        // prettier-ignore
        (
            /* uint80 roundID */,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = AggregatorV3Interface(priceFeed).latestRoundData();
        return price;
    }
}

