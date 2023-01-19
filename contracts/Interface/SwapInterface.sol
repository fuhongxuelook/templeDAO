// SPDX-License-Identifier: GPL-3.0
/**
 * SwapInterface
 * 
 */

pragma solidity ^0.8.0;

interface SwapInterface {

    /**
     * @dev comfirmed swap info
     * 
     * Params:
     * - aggregatorId: registered aggregator
     * - tokenFrom: sell token address
     * - tokenTo: buy token address
     * - trader: msg.sender
     * - amount: sell token amount
     * - date: swap timestamp
     */
    event Swap(
        uint256 indexed aggregatorId, 
        address indexed tokenFrom,
        address indexed tokenTo,
        address trader,
        uint256 amount,
        uint256 date
    );

    event SetPerform(address indexed performer, address indexed newPerformer, uint256 date);

    /**
     * @dev start of swap 
     * 
     * collect from token (or ether) from msg.sender
     * send token(ether) to performer address
     * execute swap by many aggregotor 
     * 
     * Params:
     * - aggregatorId: registered aggregator
     * - tokenFrom: sell token address
     * - tokenTo: buy token address
     * - amount: sell token amount
     * - data: aggregator swap data
     **/
    function swap(
        uint aggregatorId,
        address tokenFrom,
        address tokenTo,
        uint256 amount,
        bytes calldata data
    ) external payable;


  
}