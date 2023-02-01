// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {

    constructor(string memory poolid) ERC20(
        string.concat("pool_", poolid), 
        string.concat("pool_", poolid)
    ) {}
}