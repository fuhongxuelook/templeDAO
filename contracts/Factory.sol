// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./Pool.sol";

contract Factory {

    address public feeTo;
    address public feeToSetter;

    mapping(address => uint256) public getPool;
    address[] public allPools;

    constructor(address _feeToSetter) public {
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external view returns (uint) {
        return allPools.length;
    }

    function createPool() external returns (address pool) {
        pool = new Pool();

        uint256 length = allPools.length;
        getPool[pool] = length;
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
