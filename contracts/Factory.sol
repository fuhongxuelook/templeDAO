// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Pool} from "./Pool.sol";
import {IPool} from "./Interface/IPool.sol";
import {IFactory} from "./Interface/IFactory.sol";

contract Factory is IFactory { 
    /// fee recipient address
    address public override feeTo;

    /// fee recipient address setter
    address public override owner;

    /// vault address
    address public override vault;

    /// inter swap address
    address public override swap;

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
    function allPoolsLength() external view override returns (uint) {
        return allPools.length;
    }


    /// @dev get pool address via id
    function getPool(uint256 id) public view override returns (address) {
        return pools[id];
    }

    /// @dev create new pool
    function createPool(string memory poolname) external override returns (address pool) {
        bytes32 salt = keccak256(abi.encodePacked(poolname));
        uint256 poolid = allPools.length;
        
        bytes memory bytecode = type(Pool).creationCode;
        bytecode = abi.encodePacked(bytecode, abi.encode(poolid));

        assembly {
            pool := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        IPool(pool).initialize(poolname, vault, swap);

        pools[poolid] = pool;
        allPools.push(pool);
    }
   
    /// @dev set fee to
    function setFeeTo(address _feeTo) external override onlyOwner {
        require(_feeTo != address(0), "E: error");
        feeTo = _feeTo;
    }

    /// @dev vault
    function setVault(address _vault) external override onlyOwner {
        require(_vault != address(0), "E: error");
        vault = _vault;
    }

    /// @dev swap
    function setSwap(address _swap) external override onlyOwner {
        require(_swap != address(0), "E: error");
        swap = _swap;
    }

}
