// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Pool} from "./Pool.sol";
import {IPool} from "./Interface/IPool.sol";

contract Factory {

    address public feeTo;
    address public feeToSetter;
    address public vault;
    address public swap;

    mapping(uint256 => Pool) public getPool;
    Pool[] public allPools;

    constructor(address _feeToSetter, address _vault) public {
        feeToSetter = _feeToSetter;
        vault = _vault;
    }

    function allPairsLength() external view returns (uint) {
        return allPools.length;
    }

    function createPool(string memory poolname, address _swap) external returns (Pool pool) {
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(poolname));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPool(pool).initialize(vault, poolname, _swap);

        uint256 length = allPools.length;
        getPool[length] = pool;
        allPools.push(pool);
    }
   

    function setFeeTo(address _feeTo) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external {
        require(msg.sender == feeToSetter, 'UniswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
