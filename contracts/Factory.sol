// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Pool} from "./Pool.sol";

contract Factory {

    address public feeTo;
    address public feeToSetter;
    address public vault;

    mapping(uint256 => address) public getPool;
    address[] public allPools;

    constructor(address _feeToSetter, address _vault) public {
        feeToSetter = _feeToSetter;
        vault = _vault;
    }

    function allPairsLength() external view returns (uint) {
        return allPools.length;
    }

    function createPool(string memory poolname) external returns (address pool) {
        bytes memory bytecode = type(Pool).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(poolname));
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IPool(pool).initialize(vault, poolname);

        require(getPool[pool] != 0, "E: pool existed");

        uint256 length = allPools.length;
        getPool[length + 1] = pool;
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
