// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import {Swap} from "./Swap.sol";
import {Token} from "./Token.sol";
import {IPool} from "./Interface/IPool.sol";
import {TransferHelper} from "./Libraries/TransferHelper.sol";
import {Constants} from "./Libraries/Constants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pool is IPool, Token {

    using TransferHelper for address;

    uint256 public reserve;
    address public factory;
    address public vault;
    Swap public swap;
    string poolname;

    mapping(address => bool) public allowed;
    address[] public allAllowed;// less change, can be complex
    mapping(address => uint256) public override tokenReserve;

    constructor() {
        factory = msg.sender;
    }

    receive() external payable {}

    modifier onlyVault {
        require(msg.sender == vault, "E: FORBIDDEN");
        _;
    }

    function initialize(address _vault, string memory _poolname, address _swap) external override {
        require(msg.sender == factory, 'E: FORBIDDEN');
        vault = _vault;
        poolname = _poolname;
        swap = Swap(payable(_swap));

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
        if(!allowed[toToken]) {
            revert TokenNotAllowed(toToken);
        }
        approveAllowance(address(swap), fromToken, amount);

        uint256 balanceBefore = IERC20(toToken).balanceOf(address(this));

        swap.swap(aggregatorIndex, fromToken, toToken, amount, data);

        uint256 balanceAfter = IERC20(toToken).balanceOf(address(this));
        uint256 realTradeAmount = balanceAfter - balanceBefore;


        tokenReserve[fromToken] -= amount;
        tokenReserve[toToken] += realTradeAmount;

        emit TradeTrace(fromToken, toToken, amount, realTradeAmount, block.timestamp);
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
        if(amount > tokenReserve[token]) {
            revert TokenReserveNotEnough(token);
        }

        uint256 balanceBefore = IERC20(Constants.USDT).balanceOf(address(this));

        swap.swap(aggregatorIndex, token, Constants.USDT, amount, data);

        uint256 balanceAfter = IERC20(Constants.USDT).balanceOf(address(this));

        uint256 realTradeAmount = balanceAfter - balanceBefore;
        tokenReserve[token] -= amount;
        tokenReserve[Constants.USDT] += realTradeAmount;

        return;
    }


    /// @dev vault take USDT from pool
    function pool2Vault(uint256 amount) external override onlyVault {
        Constants.USDT.safeTransfer(msg.sender, amount);

        reserve -= amount;
    }

    /// @dev vault send USDT to pool
    function vault2Pool(uint256 amount) external override onlyVault {
        Constants.USDT.safeTransferFrom(msg.sender, address(this), amount);

        reserve += amount;
    }

    /// @dev skim reserve and balance;
    function skim() external {
        uint256 balance = IERC20(Constants.USDT).balanceOf(address(this));
        if(balance >= reserve) {
            Constants.USDT.safeTransfer(msg.sender, balance - reserve);
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
        reserve = IERC20(Constants.USDT).balanceOf(address(this));
    }

    /// @dev mint token
    function safeMint(address account, uint256 amount) external override onlyVault {
        _mint(account, amount);
    }

    /// @dev burn token
    function safeBurn(address account, uint256 amount) external override onlyVault {
        _burn(account, amount);
    }
}