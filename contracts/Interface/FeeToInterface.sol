// SPDX-License-Identifier: GPL-3.0
/**
 * FeeToInterface interface
 */
pragma solidity ^0.8.0;

interface FeeToInterface {

    /**
     * @dev Log Distribute
     * 
     * Params
     * - address token 
     * - address feeTo
     * - uint256 feeAmount
     * - address recipient
     * - uint256 receiveAmount
     * - uint256 date
     */ 
    event Distribute(
        address token, 
        address feeTo, 
        uint256 feeAmount, 
        address recipient, 
        uint256 receiveAmount, 
        uint256 date
    );

    /**
     * @dev recode sync info
     * 
     * @param token token address
     * @param recipient token recevied address
     * @param amount token amount 
     * @param blockTime time
     */ 
    event Sync(address token, address recipient, uint256 amount, uint256 blockTime);

    /**
     * @dev Log fee address change
     * 
     * Params
     * - oldAddress 
     * - newAddress
     * - date block.timestamp
     */ 
    event SetFeeTo(address indexed oldAddress, address indexed newAddress, uint256 date);

    /**
     * @dev Log fee Rate change
     * 
     * Params
     * - oldRate 
     * - newRate
     * - date block.timestamp
     */ 
    event SetFeeRate(uint256 indexed oldRate, uint256 indexed newRate, uint256 date);

    /**
     * @dev set new receive address 
     * 
     * Params:
     * - feeTo new fee receive address
     */
    function setFeeTo(address payable newFeeTo) external;

    /**
     * @dev set new fee rate 
     * 
     * Params:
     * - feeTo new fee _newRate   
     */ 
    function setFeeRate(uint newRate) external;

    /**
     * @dev sync eth balance if eth not be distribute;
     * 
     */ 
    function syncEth() external;

    /**
     * @dev sync erc20 token balance if not be distribute;
     * 
     */ 
    function syncToken(address token) external;

}