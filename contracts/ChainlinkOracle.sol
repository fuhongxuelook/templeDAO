// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

abstract contract ChainlinkOracle {

    mapping(address => address) public priceFeeds;


    function setPriceFeed(address token, address feed) external virtual;

    /**
     * Returns the latest price.
     */
    function getLatestPrice(address token) public view returns (int) {

        address priceFeed = priceFeeds[token];
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