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
    uint256 public reserve0;
    uint256 public gross;
    Factory public factory;

    address public feeTo;
  
    // address token => reserve amount
    mapping(address => uint256) public poolSend;
    mapping(address => uint256) public poolGet;
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
        feeTo = factory.feeTo();
        allowed[Constants.USDT] = true;
    }
   
    receive() external payable {}

    /// @dev get token reserve in vault
    function getReserve0() public view returns (uint256) {
        return reserve0;
    }

    /// @dev deposit token to vault;
    /// @param token:  deposited token address;
    /// @param amount: deposit amount ;
    /// @param poolid: invest pool ;
    function deposit(address token, uint256 amount, uint256 poolid) external {
        if(!allowed[token]) revert NotAllowedToken(token);

        if(amount == 0) revert DepositAmountCantBeZero();

        address pool = factory.getPool(poolid);
        if(pool == address(0)) revert AddressCantBeZero();

        token.safeTransferFrom(msg.sender, pool, amount);

        principal[msg.sender] = principal[msg.sender].add(amount);

        IPool(pool).safeMint(msg.sender);

        emit Deposit(token, msg.sender, address(pool), amount, block.timestamp);
    }

    /// @dev withdraw token from vault
    /// @param token:  withdraw token address
    /// @param amount: withdraws amount 
    /// @param poolid: invest pool 
    // function withdraw(address token, uint256 amount, uint256 poolid) external {
    //     if(!allowed[token]) revert NotAllowedToken(token);
    //     if(amount == 0) revert WithdrawAmountCantBeZero();

    //     Pool pool = Pool(payable(factory.getPool(poolid)));
    //     if(address(pool) == address(0)) revert AddressCantBeZero();

    //     uint256 poolTokenBalance = pool.balanceOf(msg.sender);

    //     require(poolTokenBalance >= amount, "E: amount not enough");

    //     uint256 poolTokenSupply = pool.totalSupply();
    //     uint256 poolReserveValue = pool.getTokenReserveValue();

    //     uint256 revenue = amount.mul(poolReserveValue).div(poolTokenSupply);

    //     /// principle
    //     uint256 partPrincipal = amount.mul(principal[msg.sender]).div(poolTokenBalance);
    //     uint256 tokenReserve = pool.tokenReserve(token);

    //     // require(tokenReserve >= revenue, "E: must liquidate");
    //     if(tokenReserve < revenue) revert TokenReserveNotEnough(token);

    //     uint256 profitFee;
    //     if(revenue > partPrincipal && !whitelist[msg.sender]) {
    //         profitFee = revenue.sub(partPrincipal).mul(profitFeeRate).div(FEE_DENOMIRATOR);
    //         //Constants.USDT.safeTransfer(feeTo, profitFee);
    //         pool.safeMint(feeTo);
    //     }

    //     uint256 withdrawAmount = revenue.sub(profitFee);
    //     pool.pool2Vault(withdrawAmount);
    //     token.safeTransfer(msg.sender, withdrawAmount);
    //     pool.safeBurn(msg.sender);
    // }

    function withdraw(address token, uint256 amount, uint256 poolid) external {
        if(!allowed[token]) revert NotAllowedToken(token);
        if(amount == 0) revert WithdrawAmountCantBeZero();

        address pool = factory.getPool(poolid);
        if(pool == address(0)) revert AddressCantBeZero();

        pool.safeTransfer(msg.sender, amount);
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

        uint256 poolTokenBalance = verifyLiquidateAmount(msg.sender, token, amount, pool);

        pool.liquidate(aggregatorIndex, token, amount, data);

        uint256 usdtReserveNow = pool.tokenReserve(Constants.USDT);
        
        /// when liquidated, usdt amount must less than user balance's 105% amount
        uint256 overTokenBalance = poolTokenBalance.mul(105).div(100);
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
        public 
        view 
        returns (
            uint256 poolTokenBalance
        ) 
    {
        uint256 tokenReserve = pool.tokenReserve(token);
        if(tokenReserve < amount) revert TokenReserveNotEnough(token);

        uint256 usdtReserve = pool.tokenReserve(Constants.USDT);
        poolTokenBalance = pool.balanceOf(account);

        if(poolTokenBalance <= usdtReserve) revert DontNeedLiquidate();

        // uint256 tokenPrice = uint256(pool.getLatestPrice(token));

        // uint256 tokenAmount = tokenPrice.mul(amount);

        // /// token amount less than usdt amount * 1.05
        // require(tokenAmount <= needLiquidatedUsdt.mul(105).div(100), "amount not enough"); 
    }


    /// @dev add pool allowed token
    function addPoolAllowedToken(address token, uint256 poolid) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        Pool pool = Pool(payable(factory.getPool(poolid)));
        if(address(pool) == address(0))  revert AddressCantBeZero();

        pool.addAllowed(token);
    }


    /// @dev remove allowned token
    function removePoolAllowedToken(address token, uint256 poolid) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        Pool pool = Pool(payable(factory.getPool(poolid)));
        if(address(pool) == address(0))  revert AddressCantBeZero();

        pool.removeAllowed(token);
    }

    /// @dev set pool's price feed
    function setPoolPriceFeed(address token, address priceFeed, uint256 poolid) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        Pool pool = Pool(payable(factory.getPool(poolid)));
        if(address(pool) == address(0))  revert AddressCantBeZero();

        pool.setPriceFeed(token, priceFeed);
    }

    /// @dev keep enough allowance to vault
    function approveToPool(uint256 poolid) external {
        address pool = factory.getPool(poolid);
        if(pool == address(0))  revert AddressCantBeZero();
        Constants.USDT.safeApprove(pool, type(uint256).max);
    }

}