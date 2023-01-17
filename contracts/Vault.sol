// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Constants} from "./Libraries/Constants.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {Factory} from "./Factory.sol";

contract Vault is Ownable {

    using Address for address;
    using TransferHelper for address;

    uint256 constant FEE_DENOMIRATOR = 10_000;

    uint256 profitFeeRate = 1_000;
    // only take once
    uint256 manageFeeRate = 100;
    uint256 reserve0;
    uint256 gross;
    Factory factory;

    address feeTo;

    error NotAllowedToken(address);
    error DepositAmountCantBeZero();
    error AddressCantBeZero();
    error TokenReserveNotEnough(address);

    // address token => reserve amount
    mapping(address => uint256) public poolSend;
    mapping(address => uint256) public poolGet;
    // address user => principal
    mapping(address => uint256) public principal;
    // address token => bool status
    mapping(address => bool) public allowed;

    // function depositETH() external payable {
    //     uint256 ethWorth = price * msg.value;
    //     tvl += ethWorth;

    //     tokens[Constants.ETH] += amount;
    //     lp.safeMint(msg.sender, amount);
    // }

    constructor(address _factory) {
        factory = _factory;
    }
   
    receive() external payable {}


    function getReserve0() public view returns (uint256) {
        return reserve0;
    }

    function deposit(address token, uint256 amount, uint256 poolID) external {
        if(!allowed[token]) {
            revert NotAllowedToken(token);
        }

        if(amount == 0) {
            revert DepositAmountCantBeZero();
        }

        // low round
        uint256 manageFeeAmount = amount * manageFee / FEE_DENOMIRATOR;

        if(manageFeeAmount > 0) {
            token.safeTransferFrom(msg.sender, feeTo, manageFeeAmount);
        }

        uint256 tokenDeposited = amount - manageFeeAmount

        uint256 tokenBalanceBefore = ERC20(token).balanceOf(address(this));

        token.safeTransferFrom(msg.sender, address(this), tokenDeposited);
        
        uint256 tokenBalanceAfter = ERC20(token).balanceOf(address(this));

        require(
            tokenBalanceAfter - tokenBalanceBefore >= tokenDeposited, 
            "E: balance error"
        );

        tokenReserve[token] += tokenDeposited;
        reserve0 += tokenDeposied;
        lp.safeMint(msg.sender, tokenDeposited);
    }

      // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint256 amount) private returns (bool feeOn) {
        address feeTo = IUniswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _reserve0 = reserve0; // gas savings
        uint _reserve0Last = _reserve0 - amount;
        if (feeOn) {
            if (_reserve0Last != 0) {
                if (_reserve0 > _reserve0Last) {
                    uint numerator = totalSupply.mul(_reserve0.sub(_reserve0Last));
                    uint denominator = _reserve0.mul(5).add(_reserve0Last);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } 
    }

    // function withdrawETH() external {
    //     uint256 fundTokenAmount = ERC20(address(this)).balanceOf(msg.sender);
    //     uint256 amount = fundTokenAmount * reserve0 / totalSupply();
    //     uint256 ethAmount = amount / price;

    //     payable(msg.sender).transfer(ethAmount);

    //     lp.safeBurn(msg.sender, fundTokenAmount);
    // }

    function withdraw(address token, uint256 amount) external {
        if(!allowed[token]) {
            revert NotAllowedToken(token);
        }

        uint256 fundTokenAmount = lp.balanceOf(msg.sender);

        require(fundTokenAmount >= amount, "E: amount");

        uint256 revenue = amount * reserve0 / totalSupply();

        uint256 _partPrinciple = amount * principal[msg.sender] / fundTokenAmount;

        require(tokenReserve[USDT] >= revenue, "E: must liquidate");
        uint256 profitFee;
        if(revenue > _partPrinciple) {
            profitFee = profitFeeRate * (revenue - _partPrinciple) / FEE_DENOMIRATOR;
            USDT.safeTransfer(feeTo, profitFee);
        }

        USDT.safeTransfer(msg.sender, revenue - _partPrinciple);

        lp.safeBurn(msg.sender, amount);
    }

    function addTokenAllowed(address token) external onlyOwner {
        if(token == address(0)) {
            revert AddressCantBeZero();
        }

        allowed[token] = true;
    }

    function removeTokenAllowed(address token) external onlyOwner {
        if(token == address(0)) {
            revert AddressCantBeZero();
        }

        allowed[token] = false;
    }

    function getTokenPrice(address token) internal view returns(uint256 price) {
        return price;
    }

    function liquidate(address token, uint256 poolid) external {
        // mapping(address => uint256) public tokenReserve;
        address pool = Factory(factory).getPool(poolid);

        if(pool.tokenReserve[token] == 0) {
            revert TokenReserveNotEnough(token);
        }

        uint256 liquidateAmount = pool.balanceOf(msg.sender);

        uint256 reserved = pool.tokenReserve[Constants.USDT];

        require(liquidateAmount > reserved, "E: needn't to liquidate");

        uint256 needToBeLiquidate = liquidateAmount - reserved;

        uint256 needToBeLiquidateTokenAmount = needToBeLiquidate / getTokenPrice(token);

        if(needToBeLiquidateTokenAmount >= tokenReserve[token]) {
            needToBeLiquidateTokenAmount = tokenReserve[token];
        } 

        pool.liquidate(token, needToBeLiquidateTokenAmount);

        return;
    }
}