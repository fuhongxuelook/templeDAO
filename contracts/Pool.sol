// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./Libraries/Constants.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Pool is Ownable {

    uint256 reserve;
    address factory;
    address vault;
    mapping(address => bool) allowed;

    error TokenNotAllowed(address token);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _vault) external {
        vault = _vault;
    }

    receive() external payable {}

    modifier onlyFactory {
        require(msg.sender == factory, "E: call must be factory");
        _;
    }

    function trade(
        address fromToken, 
        address toToken, 
        bytes calldata data, 
    ) external onlyOwner {
        if(!allowed[toToken]) {
            revert TokenNotAllowed(toToken);
        }
    }  

    function liquidate(address token, uint256 amount) external onlyFactory {

    }

    function toVault(uint256 amount) external onlyFactory {
        USDT.safeTransfer(msg.sender, amount);

        reserve -= amount;
    }

    function fromVault(uint256 amount) external onlyFactory {
        USDT.safeTransferFrom(msg.sender, address(this), amount);

        reserve += amount;
    }

    function skim() external {
        uint256 balance = ERC20(USDT).balanceOf(address(this));
        if(balance >= reserve) {
            USDT.safeTransfer(msg.sender, balance - reserve);
        }
    }

    // // force balances to match reserves
    // function skim(address to) external lock {
    //     address _token0 = token0; // gas savings
    //     address _token1 = token1; // gas savings
    //     _safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)).sub(reserve0));
    //     _safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)).sub(reserve1));
    // }

    // force reserves to match balances
    function sync() external {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}