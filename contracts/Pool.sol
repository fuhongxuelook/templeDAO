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

    uint256 public constant PRICE_DECIMAL = 8;

    uint256 public constant MINIMUM_LIQUIDITY = 10**3;

    uint256 public constant FEE_DENOMIRATOR = 10_000;

    uint256 public constant ONE_ETHER = 1 ether;

    uint256 public profitFeeRate = 1_000;
    // only take once
    uint256 public manageFeeRate = 100;

    uint256 public reserve;
    uint256 public kLast;

    address public factory;
    address public vault;
    address public swaper;
    address public owner;

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
    error DecimalIsZero(address token);

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

    modifier onlyOwner {
        require(msg.sender == owner, "E: FORBIDDEN");
        _;
    }

    /// @dev initialize
    function initialize(
        string memory _poolname, 
        address _vault, 
        address _swaper,
        address _owner
    ) external override {
        require(msg.sender == factory, 'E: FORBIDDEN');
        vault = _vault;
        poolname = _poolname;
        swaper = _swaper;  
        owner = _owner;

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
    function approveAllowance(address swaper, address token, uint256 amount) internal {
        if(token == Constants.ETH) return;

        uint256 allowance = IERC20(token).allowance(address(this), swaper);
        if(allowance >= amount) {
            return;
        }
        token.safeApprove(swaper, type(uint256).max);
    }

    /// @dev add allowed token 
    function addAllowed(address token, address feed) public override onlyVault {
        require(allAllowed.length() <= maxAllowed, "E: allowed number is max");

        _addAllowed(token);
        _setPriceFeed(token, feed);
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
    ) external override onlyOwner {
        if(!allowed[toToken]) revert TokenNotAllowed(toToken);

        _swap(aggregatorIndex, fromToken, toToken, amount, data);
    }  

    /// @dev get token balance 
    function currentBalance(address token) internal view returns (uint256) {
        if(token == Constants.ETH) {
            return address(this).balance;
        }
        return IERC20(token).balanceOf(address(this));
    }

    function _swap(
        uint256 aggregatorIndex,
        address fromToken,
        address toToken,
        uint256 amount,
        bytes calldata data
    ) internal {
        approveAllowance(swaper, fromToken, amount);

        // mapping(address => uint256) public tokenReserve;
        if(amount > tokenReserve[fromToken]) revert TokenReserveNotEnough(fromToken);

        uint256 swapBefore = IERC20(toToken).balanceOf(address(this));
        ISwap(swaper).swap(aggregatorIndex, fromToken, toToken, amount, data);
        uint256 swapAfter = IERC20(toToken).balanceOf(address(this));

        uint256 realAmountIn = swapAfter - swapBefore;
        if(realAmountIn == 0) revert SwapError();

        tokenReserve[fromToken] -= amount;
        tokenReserve[toToken] += realAmountIn;

        emit TradeTrace(fromToken, toToken, amount, realAmountIn, block.timestamp);
    }

    /// @dev liquidate token to USDT
    /// @notice force call by vault to liquidate any token to usdt
    function liquidate(
        uint256 aggregatorIndex,
        address token,
        uint256 amount,
        bytes calldata data
    ) external override onlyVault {
        require(token != Constants.USDT, "E: token cant be USDT");
        if(!allowed[token]) revert TokenNotAllowed(token);

        _swap(aggregatorIndex, token, Constants.USDT, amount, data);
    }

    /// @dev mint token
    function safeMint(address to) external override returns (uint liquidity) {
        uint256 _reserve = getReserves();
        /// only support usdt token
        uint balance = IERC20(Constants.USDT).balanceOf(address(this));
        uint amount = balance.sub(tokenReserve[Constants.USDT]);
        require(amount > 0, "E: amount cant be zero");

        (bool feeOn, address feeTo) = _mintFeeV2(_reserve);
        uint _totalSupply = totalSupply; // gas savings,
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount.mul(ONE_ETHER)).sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = amount.mul(_totalSupply) / _reserve;
        }
        require(liquidity > 0, 'E: INSUFFICIENT_LIQUIDITY_MINTED');
            
        // directly fee 
        uint256 manageFee = liquidity.mul(manageFeeRate).div(FEE_DENOMIRATOR);
        _mint(feeTo, manageFee);
        _mint(to, liquidity.sub(manageFee));
        
        _update(Constants.USDT, balance);

        _reserve += amount;
        reserve = _reserve;
        if (feeOn) kLast = _reserve.mul(ONE_ETHER); // reserve is up-to-date
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(address _token, uint _balance) private {
        tokenReserve[_token] = _balance;
    }

    // if fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k)
    function _mintFee(uint _reserve) private returns (bool feeOn, address feeTo) {
        feeTo = IFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = Math.sqrt(_reserve.mul(ONE_ETHER));
                uint rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(9).add(rootKLast);
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    function _mintFeeV2(uint256 _reserve) private returns (bool feeOn, address feeTo) {
        feeTo = IFactory(factory).feeTo();
        feeOn = feeTo != address(0);
        if (feeOn) {
            if (_reserve > reserve) {
                uint numerator = totalSupply.mul(_reserve.sub(reserve)).mul(profitFeeRate);
                uint denominator = _reserve.mul(FEE_DENOMIRATOR);
                uint liquidity = numerator / denominator;
                if (liquidity > 0) _mint(feeTo, liquidity);
            }
        } else if (reserve != 0) {
            reserve = 0;
        }
    }

    /// @dev burn token
    function safeBurn(address to) external override returns (uint amount) {
        uint256 _reserve = getReserves();  
        address _token0 = Constants.USDT;

        uint liquidity = balanceOf[address(this)];

        (bool feeOn, ) = _mintFeeV2(_reserve);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount = liquidity.mul(_reserve) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount > 0, 'E: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _token0.safeTransfer(to, amount);
        
        uint256 balance = IERC20(_token0).balanceOf(address(this));

        _update(Constants.USDT, balance);

        _reserve -= amount;
        reserve = _reserve;
        if (feeOn) kLast = _reserve.mul(ONE_ETHER); // reserve and reserve1 are up-to-date
    }

    /// liquidity value in pool
    function valueInPool(address account) public view override returns (uint256 value) {
        uint256 liquidity = balanceOf[account];
        uint256 _reserve = getReserves();  

        value = liquidity.mul(_reserve) / totalSupply; // using balances ensures pro-rata distribution
    }

    /// @dev get pool tokens value
    function getReserves() public view override returns (uint256 value) {
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
            // literally
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
            if(t_value < 1E16) {
                continue;
            }
            value = value.add(t_value);
        }
    }

    function cacheTokenDecimal(address token) public {
        if(cachedDecimals[token] > 0) {
            return;
        }
        (bool success, bytes memory res) = token.staticcall(abi.encodeWithSignature("decimals()"));
        require(success, "E: call error");
        uint256 decimal = uint256(abi.decode(res, (uint8)));
        cachedDecimals[token] = decimal;
    }


    /// @dev set token to chainlink price feed
    /// @dev to save gas, so set in every pool except external contract
    function setPriceFeed(address token, address feed) external override onlyVault {
       _setPriceFeed(token, feed);
    }

    function _setPriceFeed(address token, address feed) private {
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

    // force balances to match reserves
    function skim(address to, address token) external {
        token.safeTransfer(to, IERC20(token).balanceOf(address(this)).sub(tokenReserve[token]));
    }

    // force reserves to match balances
    function sync(address token) external {
        _update(token, IERC20(token).balanceOf(address(this)));
    }
}