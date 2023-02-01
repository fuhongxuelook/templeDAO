// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Pool} from "./Pool.sol";
import {IPool} from "./Interface/IPool.sol";

contract Factory { 
    /// fee recipient address
    address public feeTo;

    /// fee recipient address setter
    address public owner;

    /// vault address
    address public vault;

    /// inter swap address
    address public swap;

    // pools poolid => pool address
    mapping(uint256 => address) pools;
    
    /// all pools
    address[] allPools;

    constructor() {
        owner = msg.sender;
        feeTo = 0x3D2C9c796a1BFdBC803775CfffA1DeB3F78228Bb;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "E: error");
        _; 
    }

    /// @dev all pools length 
    function allPoolsLength() external view returns (uint) {
        return allPools.length;
    }


    /// @dev get pool address via id
    function getPool(uint256 id) public view returns (address pool) {
        pool = pools[id];
        require(pool != address(0), "E: pool is not existed");
    }

    /// @dev create new pool
    function createPool(string memory poolname) external returns (address pool) {
        bytes32 salt = keccak256(abi.encodePacked(poolname));
        
        bytes memory bytecode = type(Pool).creationCode;
        uint256 poolid = allPools.length;
        bytecode = abi.encodePacked(bytecode, abi.encode(poolid));

        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPool(pool).initialize(poolname, vault, swap);

        pools[poolid] = pool;
        allPools.push(pool);
    }
   
    /// @dev set fee to
    function setFeeTo(address _feeTo) external onlyOwner {
        feeTo = _feeTo;
    }

    /// @dev vault
    function setVault(address _vault) external onlyOwner {
        require(_vault != address(0), "E: error");
        vault = _vault;
    }

    /// @dev swap
    function setSwap(address _swap) external onlyOwner {
        require(_swap != address(0), "E: error");
        swap = _swap;
    }

}
