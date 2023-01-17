// SPDX-License-Identifier: GPL-3.0
/**
 * AdapterManageInterface interface
 *
 */
pragma solidity ^0.8.0;

import "../Libraries/AdapterSet.sol";

interface AdapterManageInterface {
    /**
     * @dev log register aggreagtor adapter
     * 
     * Params 
     * - address router aggregator's router 
     * - address proxy  router's proxy, like paraswap
     * - address name aggregator name
     * - uint date block.timestamp
     */ 
    event RegisterAdapter(address indexed router, address indexed proxy, bytes32 name, uint256 date);
    
    /**
     * @dev log remove aggreagtor adapter
     * 
     * Params 
     * - address router aggregator's router 
     * - address proxy  router's proxy, like paraswap
     * - address name aggregator name
     * - uint date block.timestamp
     */ 
    event RemoveAdapter(address indexed router, address indexed proxy, bytes32 name, uint256 date);

    /**
     * @dev register aggreagtor adapter
     * 
     * Params 
     * - address router aggregator's router 
     * - address proxy  router's proxy, like paraswap
     * - address name aggregator name
     */ 
    function registerAdapter(address router, address proxy, bytes32 name) external;

    /**
     * @dev remove aggreagtor adapter
     * 
     * Params 
     * - AdapterSet.Adapter adapter
     */ 
    function removeAdapter(uint256 index) external;

    /**
     * @dev is aggreagtor adapter
     * 
     * Params 
     * - AdapterSet.Adapter adapter
     * 
     * Returns
     * - bool 
     */ 
    function isAdapter(AdapterSet.Adapter memory adapter) external returns(bool);

    // aggregator amount
    function adapterAmount() external returns(uint);

    /**
     * @dev get adapter by index
     * 
     * Params:
     * - uint index 
     * 
     * Returns:
     * - AdapterSet.Adapter memory
     */
    function getAdapterByIndex(uint index) external returns(AdapterSet.Adapter memory);

     /**
     * @dev get all adapters
     * 
     * Returns:
     * - AdapterSet.Adapter[] memory
     */
    function getAllAdapter() external view returns(AdapterSet.Adapter[] memory);

}