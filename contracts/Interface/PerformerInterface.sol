// SPDX-License-Identifier: GPL-3.0
/**
 * PerformerInterface interface
 *
 */

pragma solidity ^0.8.0;

import "../Libraries/AdapterSet.sol";


interface PerformerInterface {

    /**
     * @dev Log perform info
     * 
     * Params
     * - address tokenFrom 
     * - address tokenTo
     * - address recipient
     * - uint256 fromAmount
     * - uint256 toAmount
     * - uint256 date 
     */ 
    event Perform(
        address tokenFrom, 
        address tokenTo, 
        address recipient,
        uint256 fromAmount,
        uint256 toAmount,
        uint256 date 
    );

    /**
     * @dev record swap address set in perform
     * 
     */ 
    event SetSwap(address swap, uint256 blocktime);
    
    /**
     * @dev router call data to execute swap
     * 
     * Params:
     * - tokenFrom: sell token
     * - tokenTo: buy token
     * - recipient: recipient address
     * - adapter: aggregator router
     * - data: call data
     * 
     **/
    function perform(
        address tokenFrom, 
        address tokenTo, 
        uint256 amount,
        address recipient, 
        AdapterSet.Adapter memory adapter, 
        bytes calldata data
    ) external payable returns(bool);
}

