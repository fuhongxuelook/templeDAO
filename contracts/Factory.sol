// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Pool} from "./Pool.sol";
import {IPool} from "./Interface/IPool.sol";

contract Factory { 
    /// fee recipient address
    address public feeTo;

    /// fee recipient address setter
    address public feeToSetter;

    /// vault address
    address public vault;

    /// inter swap address
    address public swap;

    /// keccak256(poolname) => pool
    mapping(bytes32 => address) poolMap;
    
    /// all pools
    address[] allPools;

    constructor(address _feeToSetter, address _vault, address _swap) {
        feeToSetter = _feeToSetter;
        vault = _vault;
        swap = _swap;
    }

    /// @dev all pools length 
    function allPoolsLength() external view returns (uint) {
        return allPools.length;
    }

    function getPoolById(uint256 id) public view returns (address) {
        if(id > allPools.length - 1) {
            return address(0); 
        }

        return allPools[id];
    }


    /// @dev get pool address by poolname
    function getPoolByName(string memory poolname) public view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(poolname));

        return poolMap[salt];
    }

    /// @dev create new pool
    function createPool(string memory poolname) external returns (address pool) {
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(poolname));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPool(pool).initialize(poolname, vault, swap);

        poolMap[salt] = pool;
        allPools.push(pool);
    }
   
    /// @dev set fee to
    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    /// @dev set feeTo setter
    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
