// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Constants} from "./Libraries/Constants.sol";
import {Token} from "./Token.sol";
import {Swap} from "./Swap.sol";

contract Pool is Token {

    uint256 public reserve;
    address public factory;
    address public vault;
    string name;

    event TradeTrace(
        address fromToken, 
        address toToken, 
        uint256 fromAmount, 
        uint256 toAmount,
        uint256 blockTime
    );

    mapping(address => bool) public allowed;
    mapping(address => uint256) public tokenReserve;

    error TokenNotAllowed(address token);

    constructor() {
        factory = msg.sender;
    }

    receive() external payable {}

    modifier onlyVault{
        require(msg.sender == vault, "E: FORBIDDEN");
        _;
    }

    function initialize(address _vault, string _name) external {
        require(msg.sender == factory, 'E: FORBIDDEN');
        vault = _vault;
        name = _name;
    }

    function getName() external view returns (string) {
        return name;
    }

    function trade(
        uint aggregatorIndex,
        address tokenFrom,
        address tokenTo,
        uint256 amount,
        bytes calldata data
    ) external onlyOwner {
        if(!allowed[toToken]) {
            revert TokenNotAllowed(toToken);
        }

        uint256 balanceBefore = ERC20(toToken).balanceOf(address(this));

        Swap.swap(aggregatorIndex, tokenFrom, tokenTo, amount, data);

        uint256 balanceAfter = ERC20(toToken).balanceOf(address(this));
        uint256 realTradeAmount = balanceAfter - balanceBefore;
        emit TradeTrace(fromToken, toToken, amount, realTradeAmount, block.timestamp);
    }  

    function liquidate(address token, uint256 amount) external {
        // mapping(address => uint256) public tokenReserve;
        if(tokenReserve[token] >= amount) {
            revert TokenReserveNotEnough(token);
        }

        token.swap(token, Constants.USDT, amount);
        return;
    }

    function pool2Vault(uint256 amount) external onlyVault {
        USDT.safeTransfer(msg.sender, amount);

        reserve -= amount;
    }

    function vault2Pool(uint256 amount) external onlyVault {
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
        reserve = ERC20(USDT).balanceOf(address(this));
    }
}