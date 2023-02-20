// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Constants} from "./Libraries/Constants.sol";
import {TransferHelper} from "./Libraries/TransferHelper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Factory} from "./Factory.sol";
import {Pool} from "./Pool.sol";
import {IPool} from "./Interface/IPool.sol";

contract Vault is Ownable {

    using TransferHelper for address;
    using SafeMath for uint256;

    uint256 constant FEE_DENOMIRATOR = 10_000;

    uint256 public profitFeeRate = 1_000;
    // only take once
    uint256 public manageFeeRate = 100;
    Factory public factory;

    // address user => principal
    mapping(address => uint256) public principal;
    // address token => bool status
    mapping(address => bool) public allowed;
    // white list
    mapping(address => bool) public whitelist;
    // black list
    mapping(address => bool) public blacklist;

    // deposit event
    event Deposit(
        address token, 
        address account, 
        address pool, 
        uint256 amount,
        uint256 blockTime
    );

    error NotAllowedToken(address);
    error DepositAmountCantBeZero();
    error WithdrawAmountCantBeZero();
    error AddressCantBeZero();
    error TokenReserveNotEnough(address);
    error DontNeedLiquidate();


    constructor(address _factory) {
        factory = Factory(_factory);
        allowed[Constants.USDT] = true;
    }
   
    receive() external payable {}

    /// @dev deposit token to vault;
    /// @param token:  deposited token address;
    /// @param amount: deposit amount ;
    /// @param poolid: invest pool ;
    function invest(address token, uint256 amount, uint256 poolid) external {
        if(!allowed[token]) revert NotAllowedToken(token);

        if(amount == 0) revert DepositAmountCantBeZero();

        address pool = factory.getPool(poolid);
        if(pool == address(0)) revert AddressCantBeZero();

        token.safeTransferFrom(msg.sender, pool, amount);

        principal[msg.sender] = principal[msg.sender].add(amount);

        IPool(pool).safeMint(msg.sender);

        emit Deposit(token, msg.sender, address(pool), amount, block.timestamp);
    }

    function withdraw(uint256 poolid, uint256 amount) external {
        if(amount == 0) revert WithdrawAmountCantBeZero();

        address pool = factory.getPool(poolid);
        if(pool == address(0)) revert AddressCantBeZero();

        pool.safeTransferFrom(msg.sender, pool, amount);
        IPool(pool).safeBurn(msg.sender);
    }

    /// @dev add allowed token
    function addTokenAllowed(address token) external onlyOwner {
        if(token == address(0)) revert AddressCantBeZero();

        allowed[token] = true;
    }

    /// @dev remove allowed token
    function removeTokenAllowed(address token) external onlyOwner {
        if(token == address(0)) revert AddressCantBeZero();

        allowed[token] = false;
    }

    /// @dev liquidate token to usdt, and help investor to withdraw
    /// @param aggregatorIndex: liquidate dex option
    /// @param token: liquidate token in vault;
    /// @param amount: liquidate amount of token
    /// @param poolid: invest pool
    /// @param data: swap data
    function liquidate(
        uint256 aggregatorIndex,
        address token,
        uint256 amount,
        uint256 poolid,
        bytes calldata data
    ) external {
        require(token != Constants.USDT, "E: liquidate token cant be usdt");

        // mapping(address => uint256) public tokenReserve;
        Pool pool = Pool(payable(factory.getPool(poolid)));
        if(address(pool) == address(0)) revert AddressCantBeZero();

        uint256 value = verifyLiquidateAmount(msg.sender, token, amount, pool);

        pool.liquidate(aggregatorIndex, token, amount, data);

        uint256 usdtReserveNow = pool.tokenReserve(Constants.USDT);
        
        /// when liquidated, usdt amount must less than user balance's 105% amount
        uint256 overTokenBalance = value.mul(103).div(100);
        require(overTokenBalance >= usdtReserveNow, "E: amount too much");

        return;
    }


    /// @dev token amount need to be liquidate in account
    function verifyLiquidateAmount(
        address account, 
        address token, 
        uint256 amount, 
        Pool pool
    ) 
        internal 
        view 
        returns (
            uint256 value
        ) 
    {
        /// first check
        uint256 tokenReserve = pool.tokenReserve(token);
        if(tokenReserve < amount) revert TokenReserveNotEnough(token);
        
        /// second check      
        uint256 usdtReserve = pool.tokenReserve(Constants.USDT);
        uint256 liquidity = pool.balanceOf(account);
        value = pool.valueInPool(account);
        if(value <= usdtReserve) revert DontNeedLiquidate();


    }


    /// @dev add pool allowed token
    function addPoolAllowedToken(uint256 poolid, address token, address feed) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        address pool = factory.getPool(poolid);
        if(pool == address(0))  revert AddressCantBeZero();

        IPool(pool).addAllowed(token, feed);
    }


    /// @dev remove allowned token
    function removePoolAllowedToken(address token, uint256 poolid) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        address pool = factory.getPool(poolid);
        if(pool == address(0))  revert AddressCantBeZero();

        IPool(pool).removeAllowed(token);
    }

    /// @dev set pool's price feed
    function setPoolPriceFeed(address token, address priceFeed, uint256 poolid) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        address pool = factory.getPool(poolid);
        if(pool == address(0))  revert AddressCantBeZero();

        Pool(payable(pool)).setPriceFeed(token, priceFeed);
    }

    /// @dev keep enough allowance to vault
    function approveToPool(uint256 poolid) external {
        address pool = factory.getPool(poolid);
        if(pool == address(0))  revert AddressCantBeZero();
        Constants.USDT.safeApprove(pool, type(uint256).max);
    }

}