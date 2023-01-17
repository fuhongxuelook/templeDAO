// SPDX-License-Identifier: GPL-3.0
/**
 * distribute token
 */

pragma solidity ^0.8.0;

import "./Libraries/Constants.sol";
import "./Libraries/TransferHelper.sol";
import "./Interface/FeeToInterface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract FeeTo is FeeToInterface, Ownable {

    using SafeMath for uint256;
    using Address for address payable;
    using TransferHelper for address;

    // record fee of tokens earned
    mapping(address => uint256) public earned; 

    /**
     * @dev 
     * address for receiving token fee
     * if address is a contract, notice to receive eth 
     */ 
    address payable public feeTo;

    /**
     * @dev fee rate
     * 
     * percent fee rate / 1000
     */ 
    uint public feeRate = 0;

    /**
     * @dev See FeeToInterface - setFeeTo
     *
     * Requirement 
     * - feeTo != newAddress to save gas
     */
    function setFeeTo(address payable newFeeTo) public override onlyOwner {
        require(
            newFeeTo != address(0), 
            "FeeTo::setFeeTo : feeTo Cant be zero"
        );
        require(
            feeTo != newFeeTo, 
            "FeeTo::setFeeTo: Address Cant be Same"
        );

        emit SetFeeTo(feeTo, newFeeTo, block.timestamp);

        feeTo = newFeeTo;
    }

    /**
     * @dev See FeeToInterface - setFeeRate
     * 
     * Requirement:
     * - feeRate != old Rate to save gas
     */ 
    function setFeeRate(uint newRate) external override onlyOwner {
        require(
            feeRate <= 100, 
            "FeeTo::setFeeRate : fee rate cant large than 100"
        );
            
        emit SetFeeRate(feeRate, newRate, block.timestamp);

        feeRate = newRate;
    }

    /**
     * @dev distribute ERC20 Token 
     * 
     * Params
     * - address token token address
     * - address recipient 
     * - uint256 amount
     * 
     * Requirements:
     * - amount cant be 0
     * 
     * NOTICE : USDT Cant be transfer by IERC20
     * So we use call to transfer token
     * 
     */ 
    function distributor(address token, address recipient, uint256 amount) internal {
        require(amount > 0, "FeeTo::distributor : token amount is zero");

        uint feeAmount = amount.mul(feeRate).div(1000);

        if(feeAmount > 0) {
            token.safeTransfer(feeTo, feeAmount);
            earned[token] = earned[token].add(feeAmount);
        }
        uint256 receiveAmount = amount.sub(feeAmount);
        token.safeTransfer(recipient, receiveAmount);

        emit Distribute(
            token, 
            feeTo, 
            feeAmount, 
            recipient, 
            receiveAmount, 
            block.timestamp
        );
    } 

    /**
     * @dev distribute ETH
     * 
     * Params :
     * - address payable recipient 
     * - uint256 balance
     * 
     * Requirements:
     * - balance can be zero
     */
    function distributorETH(address payable recipient, uint256 balance) internal {
        require(balance > 0, "FeeTo::distributorETH : eth can be zero");

        uint feeAmount = balance.mul(feeRate).div(1000);
        if(feeAmount > 0) {
            feeTo.sendValue(feeAmount);
            earned[Constants.ETH] = earned[Constants.ETH].add(feeAmount);
        }

        uint256 receiveAmount = balance.sub(feeAmount);
        recipient.sendValue(receiveAmount);

        emit Distribute(
            Constants.ETH, 
            feeTo, 
            feeAmount, 
            recipient, 
            receiveAmount, 
            block.timestamp
        );
    }

    /**
     * @dev FeeToInterface - syncEth
     * 
     */ 
    function syncEth() external override onlyOwner {
        uint256 amount = address(this).balance;
        feeTo.sendValue(amount);

        emit Sync(Constants.ETH, feeTo, amount, block.timestamp);
    }

    /**
     * @dev FeeToInterface - syncToken
     * 
     */ 
    function syncToken(address token) external override onlyOwner {
        uint256 amount = IERC20(token).balanceOf(address(this));
        token.safeTransfer(feeTo, amount);

        emit Sync(token, feeTo, amount, block.timestamp);
    }

}