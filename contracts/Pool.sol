// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {ISwap} from "./Interface/ISwap.sol";
import {Token} from "./Token.sol";
import {IPool} from "./Interface/IPool.sol";
import {TransferHelper} from "./Libraries/TransferHelper.sol";
import {Constants} from "./Libraries/Constants.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ChainlinkOracle} from "./ChainlinkOracle.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IFactory} from "./Interface/IFactory.sol";

contract Pool is IPool, Token, ChainlinkOracle {

    using TransferHelper for address;
    using SafeMath for uint256;
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Math for uint256;

    uint256 public constant PRICE_DECIMAL = 8;
    uint public constant MINIMUM_LIQUIDITY = 10**3;

    uint256 public constant FEE_DENOMIRATOR = 10_000;

    uint256 public profitFeeRate = 1_000;
    // only take once
    uint256 public manageFeeRate = 100;

    uint256 public usdtIN;
    uint256 public usdtOUT;
    uint256 public reserve0;
    address public factory;
    address public vault;
    address public swap;

    uint256 kLast;

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
        _addAllowed(Constants.USDT);
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

        require(allAllowed.length() <= maxAllowed, "E: allowed number is max");

        _addAllowed(token);
    }

    function _addAllowed(address token) private {
        require(!allowed[token], "E: token has already been allowed");

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
    function safeMint(address to) external override returns (uint liquidity) {
        uint256 _reserve0 = getTokenReserveValue();
        /// only support usdt token
        uint balance0 = IERC20(Constants.USDT).balanceOf(address(this));
        uint amount0 = balance0.sub(tokenReserve[Constants.USDT]);

        (bool feeOn, address feeTo) = _mintFee(_reserve0);
        uint _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = amount0.sqrt().sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = amount0.mul(_totalSupply) / _reserve0;
        }
        require(liquidity > 0, 'E: INSUFFICIENT_LIQUIDITY_MINTED');
        
        uint256 manageFee = liquidity.mul(manageFeeRate).div(FEE_DENOMIRATOR);
        _mint(to, liquidity);
        _mint(feeTo, liquidity.sub(manageFee));
        if (feeOn) kLast = _reserve0; // reserve0 is up-to-date
        
        _update(balance0);
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint _balance0) private {
        tokenReserve[Constants.USDT] = _balance0;
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint _reserve0) private returns (bool feeOn, address feeTo) {
        feeTo = IFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = _reserve0.sqrt();
                uint rootKLast = _kLast.sqrt();
                if (rootK > rootKLast) {
                    uint numerator = totalSupply().mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(9).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
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
        for(uint256 i = 0; i < allAllowedLength; ++i) {
            // save gas
            t_token = allAllowed.at(i);
            // save gas
            t_tokenReserve = tokenReserve[t_token];
            if(t_tokenReserve == 0) continue;
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

            // value less than 1 usdt, neglect ;
            if(t_value < 1E18) {
                continue;
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

    function getAllowedTokenByIndex(uint256 index) public view returns(address token) {
        require(index < allAllowed.length(), "E: exceed border");

        token = allAllowed.at(index);
    }

    function allAllowedTokens() public view returns(address[] memory tokens) {
        tokens = allAllowed.values();
    }
}