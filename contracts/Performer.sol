// SPDX-License-Identifier: GPL-3.0
/**
 * @dev get bytecode data and run it to perform a swap
 */

pragma solidity ^0.8.0;

import "./FeeTo.sol";
import "./Interface/PerformerInterface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Performer is PerformerInterface, FeeTo {

    using Address for address;
    using TransferHelper for address;


    address swap;

    constructor(address _feeTo) {
        setFeeTo(payable(_feeTo));
    }

    receive() external payable {}

    /**
     * @dev set swap address, only execute once
     * 
     * Requires:
     * - swap must be address(0)
     * - _swap cant be address(0);
     * 
     **/ 
    function setSwap(address _swap) external onlyOwner {
        require(
            _swap != address(0), 
            "Performer::setSwap : _swap adddress cant be zero"
        );
        require(
            swap == address(0), 
            "Performer::setSwap : Error: swap has been set"
        );

        swap = _swap;
        emit SetSwap(swap, block.timestamp);
    }

    modifier onlySwap() {
        require(
            msg.sender == swap, 
            "Performer::onlySwap : caller must be swap"
        );
        _;
    }


    /**
     * @dev See PerformerInterface - perform
     * 
     * router call data with eth
     * 
     * Requires:
     * - adapter cant be address(0)
     * - call returns must be true
     * - tokenTo balance must greeter than 0 after swap
     * 
     **/ 
    function perform(
        address tokenFrom, 
        address tokenTo, 
        uint256 amount,
        address recipient, 
        AdapterSet.Adapter memory adapter, 
        bytes calldata data
    ) external payable override onlySwap returns(bool) {
        require(
            adapter._router != address(0), 
            "Performer::perform : Adapter is not support"
        );

        // check allowance and approve it max
        approveAllowance(adapter._proxy, tokenFrom, amount);

        // now cant deal this call return data
        // we dont know what's type each aggregator returns
        adapter._router.functionCallWithValue(data, msg.value);

        uint256 receiveAmount = distribute(tokenTo, recipient);

        emit Perform(
            tokenFrom, 
            tokenTo, 
            recipient,
            amount,
            receiveAmount,
            block.timestamp
        );

        return true;
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

    /**
     * @dev 
     * 
     * check token amount and distrubute 
     * 
     * Requires:
     * - if target token is ETH, ETH balance can be zero
     * - if target token is Token, Token amount can be zero
     * 
     * NOTICE: 
     * - Reentrant
     * 
     */ 
    function distribute(address token, address recipient) private returns(uint256 amount) {
        if (token == Constants.ETH) {
            amount = address(this).balance;
            require(
                amount > 0, 
                "Performer::distribute : Did not receive eth"
            );
            distributorETH(payable(recipient), amount);
        } else {
            amount = IERC20(token).balanceOf(address(this));
            require(
                amount > 0, 
                "Performer::distribute : Did not receive token"
            );
            distributor(token, recipient, amount);
        }
        return amount;
    }
}