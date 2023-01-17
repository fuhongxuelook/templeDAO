// SPDX-License-Identifier: GPL-3.0
/**
 * Adapter mananement
 *
 */
pragma solidity ^0.8.0;

import "./Interface/AdapterManageInterface.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

abstract contract AdapterManage is AdapterManageInterface, OwnableUpgradeable {

    using AdapterSet for AdapterSet.Set;

    AdapterSet.Set adapterSet;
    
    // add router to router group 
    // router was stored in Adaper
    function registerAdapter(address router, address proxy, bytes32 name) external override onlyOwner {
        require(router != address(0), "AdapterManage::registerAdapter : Router cant be zero");
        require(proxy != address(0), "AdapterManage::registerAdapter: Proxy cant be zero");

        AdapterSet.Adapter memory adapter = AdapterSet.Adapter(router, proxy, name);
        adapterSet.add(adapter);

        emit RegisterAdapter(router, proxy, name, block.timestamp);
    }

    // remove router from router group
    function removeAdapter(uint256 index) external override onlyOwner {
        AdapterSet.Adapter memory adapter = adapterSet.at(index);
        require(adapter._router != address(0), "AdapterManage::removeAdapter : Index not exists");

        adapterSet.remove(adapter);
        emit RemoveAdapter(adapter._router, adapter._proxy, adapter._name, block.timestamp);
    }

    // detect address is router and it's worked
    function isAdapter(AdapterSet.Adapter memory adapter) external view override returns(bool) {
        return adapterSet.contains(adapter);
    }

    // router amount
    function adapterAmount() external view override returns(uint) {
        return adapterSet.length();
    }

    function getAdapterByIndex(uint index) public view override returns(AdapterSet.Adapter memory) {
        return adapterSet.at(index);
    }

    function getAllAdapter() external view override returns(AdapterSet.Adapter[] memory) {
        return adapterSet.values();
    }

}