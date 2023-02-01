// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./Token.sol";

contract DEMO is Token {

    constructor() Token("Token") {
        _mint(msg.sender, 1000 * 1e18);
    }
}