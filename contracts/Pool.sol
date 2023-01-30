// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Swap} from "./Dex/Swap.sol";
import {Token} from "./Token.sol";
import {IPool} from "./Interface/IPool.sol";
import {TransferHelper} from "./Libraries/TransferHelper.sol";
import {Constants} from "./Libraries/Constants.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ChainlinkOracle} from "./ChainlinkOracle.sol";

contract Pool is IPool, Token, ChainlinkOracle {

    using TransferHelper for address;
    using SafeMath for uint256;

    uint256 public usdtIN;
    uint256 public usdtOUT;
    address public factory;
    address public vault;
    string poolname;
    Swap public swap;

    mapping(address => bool) public allowed;
    address[] public allAllowed;                                // less change, can be complex
    mapping(address => uint256) public override tokenReserve;

    event TradeTrace(
        address fromToken, 
        address toToken, 
        uint256 fromAmount, 
        uint256 toAmount,
        uint256 blockTime
    );

    error TokenNotAllowed(address token);
    error AddressCantBeZero();
    error TokenReserveNotEnough(address);
    error SwapError();


    constructor() {
        factory = msg.sender;
    }

    receive() external payable {}

    modifier onlyVault {
        require(msg.sender == vault, "E: FORBIDDEN");
        _;
    }

    function initialize(string memory _poolname, address _vault, address _swap) external override {
        require(msg.sender == factory, 'E: FORBIDDEN');
        vault = _vault;
        poolname = _poolname;
        swap = Swap(payable(_swap));

        Constants.USDT.safeApprove(vault, type(uint256).max);
    }

    /// @dev keep enough allowance to vault
    function approveToVault() external {
        Constants.USDT.safeApprove(vault, type(uint256).max);
    }

    /**
     * @dev 
     * 
     * If Token is ETH, skip this
     * Token Will be check allowance of address(this)
     * if less than amount, approve max(uint256)
     * 
     */ 
    function approveAllowance(address router, address token, uint256 amount) internal {
        if(token == Constants.ETH) return;

        uint256 allowance = IERC20(token).allowance(address(this), router);
        if(allowance >= amount) {
            return;
        }
        token.safeApprove(router, type(uint256).max);
    }

    /// @dev add allowed token 
    function addAllowed(address token) external override onlyVault {
        require(!allowed[token], "E: token has already been allowed");

        allowed[token] = true;
        allAllowed.push(token);
    }

    /// @dev remove allowed token
    function removeAllowed(address token) external override onlyVault {
        require(allowed[token], "E: token is not allowed");

        allowed[token] = false;
    }

    /// @dev get pool name
    function getPoolName() external view override returns (string memory) {
        return poolname;
    }

    /// @dev trade token to other token
    function trade(
        uint aggregatorIndex,
        address fromToken,
        address toToken,
        uint256 amount,
        bytes calldata data
    ) external override {
        if(!allowed[toToken]) revert TokenNotAllowed(toToken);
        approveAllowance(address(swap), fromToken, amount);

        uint256 balanceBefore = currentBalance(toToken);

        swap.swap(aggregatorIndex, fromToken, toToken, amount, data);

        uint256 balanceAfter = currentBalance(toToken);
        uint256 realTradeAmount = balanceAfter - balanceBefore;

        if(realTradeAmount == 0) revert SwapError();

        tokenReserve[fromToken] -= amount;
        tokenReserve[toToken] += realTradeAmount;

        emit TradeTrace(fromToken, toToken, amount, realTradeAmount, block.timestamp);
    }  

    /// @dev get token balance 
    function currentBalance(address token) internal view returns (uint256) {
        require(token != address(0), "E: error");

        if(token == Constants.ETH) {
            return address(this).balance;
        }

        return IERC20(token).balanceOf(address(this));
    }

    /// @dev liquidate token to USDT
    function liquidate(
        uint aggregatorIndex,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override onlyVault {
        require(token != Constants.USDT, "E: token cant be USDT");

        // mapping(address => uint256) public tokenReserve;
        if(amount > tokenReserve[token]) revert TokenReserveNotEnough(token);

        uint256 balanceBefore = IERC20(Constants.USDT).balanceOf(address(this));

        swap.swap(aggregatorIndex, token, Constants.USDT, amount, data);

        uint256 balanceAfter = IERC20(Constants.USDT).balanceOf(address(this));

        uint256 realTradeAmount = balanceAfter - balanceBefore;

         if(realTradeAmount == 0) revert SwapError();

        tokenReserve[token] -= amount;
        tokenReserve[Constants.USDT] += realTradeAmount;

        return;
    }


    /// @dev vault take USDT from pool
    function pool2Vault(uint256 amount) external override onlyVault {
        Constants.USDT.safeTransfer(msg.sender, amount);

        usdtOUT += amount;
    }

    /// @dev vault send USDT to pool
    function vault2Pool(uint256 amount) external override onlyVault {
        Constants.USDT.safeTransferFrom(msg.sender, address(this), amount);

        usdtIN += amount;
    }

    /// @dev mint token
    function safeMint(address account, uint256 amount) external override onlyVault {
        _mint(account, amount);
    }

    /// @dev burn token
    function safeBurn(address account, uint256 amount) external override onlyVault {
        _burn(account, amount);
    }


    /// @dev get pool tokens value
    function getTokenReserveValue() public view returns (uint256 value) {
        uint256 allAllowedLength = allAllowed.length;

        if(allAllowedLength == 0) return 0;

        for(uint256 i; i < allAllowedLength; ++i) {
            address t_token = allAllowed[i];
            uint256 t_tokenReserve = tokenReserve[t_token];
            if(t_tokenReserve <= 1000) continue;
            if(t_token == Constants.USDT) {
                value  = value.add(t_tokenReserve);
                continue;
            }
            uint256 t_tokenPrice = uint256(getLatestPrice(t_token));
            value = value.add(t_tokenReserve.mul(t_tokenPrice).div(1E8));
        }
    }


    /// @dev set token to chainlink price feed
    /// @dev to save gas, so set in every pool except external contract
    function setPriceFeed(address token, address feed) external override onlyVault {
        require(token == address(0) || feed == address(0), "E: error");

        priceFeeds[token] = feed;
    }

}