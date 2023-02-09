// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {ISwap} from "./Interface/ISwap.sol";
import {Token} from "./Token.sol";
import {IPool} from "./Interface/IPool.sol";
import {TransferHelper} from "./Libraries/TransferHelper.sol";
import {Constants} from "./Libraries/Constants.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ChainlinkOracle} from "./ChainlinkOracle.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Pool is IPool, Token, ChainlinkOracle {

    using TransferHelper for address;
    using SafeMath for uint256;
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant PRICE_DECIMAL = 8;

    uint256 public usdtIN;
    uint256 public usdtOUT;
    address public factory;
    address public vault;
    address public swap;

    string poolname;

    uint256 public maxAllowed = 10;
    mapping(address => bool) public allowed;
    EnumerableSet.AddressSet allAllowed;
                              // less change, can be complex
    mapping(address => uint256) public override tokenReserve;
    mapping(address => uint256) public cachedDecimals; 


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


    constructor(uint256 poolid) Token(poolid.toString()) {
        factory = msg.sender;
        cachedDecimals[Constants.USDT] = Constants.USDTDecimal;
        addAllowed(Constants.USDT);
    }

    receive() external payable {}

    modifier onlyVault {
        require(msg.sender == vault, "E: FORBIDDEN");
        _;
    }


    /// @dev initialuze
    function initialize(string memory _poolname, address _vault, address _swap) external override {
        require(msg.sender == factory, 'E: FORBIDDEN');
        vault = _vault;
        poolname = _poolname;
        swap = _swap;

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
    function addAllowed(address token) public override onlyVault {
        require(!allowed[token], "E: token has already been allowed");

        require(allAllowed.length() <= maxAllowed, "E: allowed number is max");

        allowed[token] = true;
        allAllowed.add(token);

        cacheTokenDecimal(token);
    }

    /// @dev remove allowed token
    function removeAllowed(address token) external override onlyVault {
        require(allowed[token], "E: token is not allowed");

        allowed[token] = false;
        allAllowed.remove(token);
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
        approveAllowance(swap, fromToken, amount);

        uint256 swapBefore = currentBalance(toToken);
        ISwap(swap).swap(aggregatorIndex, fromToken, toToken, amount, data);
        uint256 swapAfter = currentBalance(toToken);
        
        uint256 realAmountIn = swapAfter - swapBefore;
        if(realAmountIn == 0) revert SwapError();

        tokenReserve[fromToken] -= amount;
        tokenReserve[toToken] += realAmountIn;

        emit TradeTrace(fromToken, toToken, amount, realAmountIn, block.timestamp);
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
        uint256 aggregatorIndex,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override onlyVault {
        require(token != Constants.USDT, "E: token cant be USDT");

        // mapping(address => uint256) public tokenReserve;
        if(amount > tokenReserve[token]) revert TokenReserveNotEnough(token);

        uint256 swapBefore = IERC20(Constants.USDT).balanceOf(address(this));
        ISwap(swap).swap(aggregatorIndex, token, Constants.USDT, amount, data);
        uint256 swapAfter = IERC20(Constants.USDT).balanceOf(address(this));

        uint256 realAmountIn = swapAfter - swapBefore;
        if(realAmountIn == 0) revert SwapError();

        tokenReserve[token] -= amount;
        tokenReserve[Constants.USDT] += realAmountIn;

        return;
    }


    /// @dev vault take USDT from pool
    function pool2Vault(uint256 amount) external override onlyVault {
        Constants.USDT.safeTransfer(msg.sender, amount);

        usdtOUT += amount;
        tokenReserve[Constants.USDT] -= amount;
    }

    /// @dev vault send USDT to pool
    function vault2Pool(uint256 amount) external override onlyVault {
        Constants.USDT.safeTransferFrom(msg.sender, address(this), amount);

        usdtIN += amount;
        tokenReserve[Constants.USDT] += amount;
    }

    /// @dev mint token
    function safeMint(address account, uint256 amount) external override onlyVault {
        _mint(account, amount);
    }

    /// @dev burn token
    function safeBurn(address account, uint256 amount) external override onlyVault {
        _burn(account, amount);
    }

    error DecimalIsZero(address token);

    /// @dev get pool tokens value
    function getTokenReserveValue() public view returns (uint256 value) {
        uint256 allAllowedLength = allAllowed.length();

        if(allAllowedLength == 0) return 0;

        // save gas
        uint256 t_usdtDecimal = Constants.USDTDecimal;
        address t_token;
        uint256 t_tokenReserve;
        uint256 t_decimal;
        uint256 t_tokenPrice;
        uint256 t_span;
        uint256 t_value;
        bool t_more;

        /// @nitice allAllowed start from 1;
        for(uint256 i = 1; i <= allAllowedLength; ++i) {
            // save gas
            t_token = allAllowed.at(i);
            // save gas
            t_tokenReserve = tokenReserve[t_token];
            if(t_tokenReserve < 1000) continue;
            // if(t_token == Constants.USDT) {
            //     value  = value.add(t_tokenReserve);
            //     continue;
            // }
            t_decimal = cachedDecimals[t_token];
            if(t_decimal == 0) revert DecimalIsZero(t_token);

            // 8 is price oracle decimal
            if(t_decimal.add(PRICE_DECIMAL) >= t_usdtDecimal) {
                t_more = false;
                t_span = t_decimal.add(PRICE_DECIMAL).sub(t_usdtDecimal);
            } else {
                t_more = true;
                t_span =  t_usdtDecimal.sub(t_decimal.add(PRICE_DECIMAL));
            }

            t_tokenPrice = uint256(getLatestPrice(t_token));
            if(t_more) {
                t_value = t_tokenReserve.mul(t_tokenPrice).mul(10 ** t_span);
            } else {
                t_value = t_tokenReserve.mul(t_tokenPrice).div(10 ** t_span);
            }
            value = value.add(t_value);
        }
    }

    function cacheTokenDecimal(address token) public {
        if(cachedDecimals[token] > 0) {
            return;
        }
        (bool success, bytes memory res) = token.delegatecall(abi.encodeWithSignature("decimals()"));
        require(success, "E: call error");
        uint256 decimal = uint256(abi.decode(res, (uint8)));
        cachedDecimals[token] = decimal;
    }


    /// @dev set token to chainlink price feed
    /// @dev to save gas, so set in every pool except external contract
    function setPriceFeed(address token, address feed) external override onlyVault {
        require(token != address(0) && feed != address(0), "E: error");

        priceFeeds[token] = feed;
    }

}