// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Token is ERC20, Ownable {

    constructor() {}

    function safeMint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function safeBurn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}