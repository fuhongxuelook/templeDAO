// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Constants} from "./Libraries/Constants.sol";
import {TransferHelper} from "./Libraries/TransferHelper.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Factory} from "./Factory.sol";
import {Pool} from "./Pool.sol";

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


    constructor(address _factory) {
        factory = Factory(_factory);
    }
   
    receive() external payable {}

    function getReserve0() public view returns (uint256) {
        return reserve0;
    }

    function deposit(address token, uint256 amount, uint256 poolid) external {
        if(!allowed[token]) revert NotAllowedToken(token);

        if(amount == 0) revert DepositAmountCantBeZero();

        Pool pool = Pool(payable(factory.getPoolById(poolid)));
        if(address(pool) == address(0)) revert AddressCantBeZero();

        token.safeTransferFrom(msg.sender, address(this), amount);

        // token.safeTransferFrom(msg.sender, address(pool), tokenDeposited);
        pool.vault2Pool(amount);
        
        // low round
        uint256 manageFeeAmount = amount.mul(manageFeeRate).div(FEE_DENOMIRATOR);

        uint256 tokenDeposited = amount.sub(manageFeeAmount);

        gross = gross.add(amount);
        principal[msg.sender] = principal[msg.sender].add(tokenDeposited);

        pool.safeMint(msg.sender, tokenDeposited);
        pool.safeMint(feeTo, manageFeeAmount);

        emit Deposit(token, msg.sender, address(pool), amount, block.timestamp);
    }

    function withdraw(address token, uint256 amount, uint256 poolid) external {
        if(!allowed[token]) revert NotAllowedToken(token);
        if(amount == 0) revert WithdrawAmountCantBeZero();

        Pool pool = Pool(payable(factory.getPoolById(poolid)));
        if(address(pool) == address(0)) revert AddressCantBeZero();

        uint256 poolTokenBalance = pool.balanceOf(msg.sender);

        require(poolTokenBalance >= amount, "E: amount not enough");

        uint256 poolTokenSupply = pool.totalSupply();

        uint256 revenue = amount.mul(reserve0).div(poolTokenSupply);

        uint256 _partPrinciple = amount.mul(principal[msg.sender]).div(poolTokenBalance);

        uint256 tokenReserve = pool.tokenReserve(Constants.USDT);

        // require(tokenReserve >= revenue, "E: must liquidate");
        if(tokenReserve >= revenue) {
            pool.pool2Vault(revenue);
        } else {
            revert TokenReserveNotEnough(token);
        }

        uint256 profitFee;
        if(revenue > _partPrinciple) {
            profitFee = profitFeeRate * (revenue - _partPrinciple) / FEE_DENOMIRATOR;
            //Constants.USDT.safeTransfer(feeTo, profitFee);
            pool.safeMint(feeTo, profitFee);
        }

        Constants.USDT.safeTransfer(msg.sender, revenue - _partPrinciple);

        pool.safeBurn(msg.sender, amount);
    }

    /// @dev add allowed token
    function addTokenAllowed(address token) external onlyOwner {
        if(token == address(0)) {
            revert AddressCantBeZero();
        }

        allowed[token] = true;
    }

    /// @dev remove allowed token
    function removeTokenAllowed(address token) external onlyOwner {
        if(token == address(0)) {
            revert AddressCantBeZero();
        }

        allowed[token] = false;
    }

    function getTokenPrice(address token) internal view returns(uint256 price) {
        return price;
    }

    function liquidate(
        uint256 aggregatorIndex,
        address token,
        uint256 amount,
        uint256 poolid,
        bytes calldata data
    ) external {
        // mapping(address => uint256) public tokenReserve;
        Pool pool = Pool(payable(factory.getPoolById(poolid)));
        if(address(pool) == address(0))  revert AddressCantBeZero();

        uint256 needToBeLiquidateTokenAmount = tokenNeedLiquidate(token, msg.sender, pool);

        require(needToBeLiquidateTokenAmount > 0 && amount > 0, "E: error");

        if(needToBeLiquidateTokenAmount > amount) {
            needToBeLiquidateTokenAmount = amount;
        }        

        pool.liquidate(aggregatorIndex, token, needToBeLiquidateTokenAmount, data);

        return;
    }

    /// @dev token amount need to be liquidate in account
    function tokenNeedLiquidate(address token, address account, Pool pool) public view returns (uint256) {

        uint256 tokenReserve = pool.tokenReserve(token);
        uint256 usdtReserve = pool.tokenReserve(Constants.USDT);

        if(tokenReserve == 0) revert TokenReserveNotEnough(token);

        uint256 poolTokenBalance = pool.balanceOf(account);

        if(poolTokenBalance <= usdtReserve) return 0;

        uint256 needToBeLiquidate = poolTokenBalance - usdtReserve;

        uint256 needToBeLiquidateTokenAmount = needToBeLiquidate.div(uint256(pool.getLatestPrice(token)));

        if(needToBeLiquidateTokenAmount >= tokenReserve) {
            needToBeLiquidateTokenAmount = tokenReserve;
        } 

        return needToBeLiquidateTokenAmount;
    }


    /// @dev add pool allowed token
    function addPoolAllowedToken(address token, uint256 poolid) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        Pool pool = Pool(payable(factory.getPoolById(poolid)));
        if(address(pool) == address(0))  revert AddressCantBeZero();

        pool.addAllowed(token);
    }


    /// @dev remove allowned token
    function removePoolAllowedToken(address token, uint256 poolid) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        Pool pool = Pool(payable(factory.getPoolById(poolid)));
        if(address(pool) == address(0))  revert AddressCantBeZero();

        pool.removeAllowed(token);
    }

    /// @dev set pool's price feed
    function setPoolPriceFeed(address token, address priceFeed, uint256 poolid) external onlyOwner {
        // mapping(address => uint256) public tokenReserve;
        Pool pool = Pool(payable(factory.getPoolById(poolid)));
        if(address(pool) == address(0))  revert AddressCantBeZero();

        pool.setPriceFeed(token, priceFeed);
    }
}