// SPDX-License-Identifier: GPL-3.0
/**
 * @dev receive token from sender;
 *
 */

pragma solidity ^0.8.0;

import "./AdapterManage.sol";
import "./Performer.sol";
import "./Libraries/TransferHelper.sol";
import "./Libraries/Constants.sol";
import "./Interface/SwapInterface.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Swap is 
    SwapInterface, 
    AdapterManage, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    UUPSUpgradeable 
{    
    using TransferHelper for address;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
       _disableInitializers();
    }

    function initialize() external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
    }

    error AddressCantBeZero();

    /**
     * @dev See SwapInterface - swap
     * 
     * collect from token (or ether) from msg.sender
     * send token(ether) to performer address
     * execute swap by many aggregotor 
     * 
     * Requirements:
     *
     * - aggregatorId must be registered.
     * - we not check allowance for saving gas, but msg.sender must approve enough allownance
     * - perform must return true
     * - tokenFrom cant be 0
     * - tokenTo cant be 0
     */
    function swap(
        uint256 aggregatorIndex,
        address tokenFrom,
        address tokenTo,
        uint256 amount,
        bytes calldata data
    ) external payable override whenNotPaused nonReentrant {

        // get router by register index
        AdapterSet.Adapter memory adapter = getAdapterByIndex(aggregatorIndex);

        if(adapter._router == address(0)) revert AddressCantBeZero();
        if(tokenFrom == address(0)) revert AddressCantBeZero();
        if(tokenTo == address(0)) revert AddressCantBeZero();

        if (tokenFrom != Constants.ETH) {
            /// not check allowance  for save gas
            /// if allowance is not enough,
            /// will be revert
            /// use call for not standard erc20 and save gas
            /// deflationary tokens need to increase slippage
            tokenFrom.safeTransferFrom(msg.sender, address(this), amount);
        } 

        // check allowance and approve it max
        approveAllowance(adapter._router, tokenFrom, amount);

        // now cant deal this call return data
        // we dont know what's type each aggregator returns
        adapter._router.functionCallWithValue(data, msg.value);

        emit Swap(aggregatorIndex, tokenFrom, tokenTo, recipient, amount, block.timestamp);
    }

    /**
     * @dev See SwapInterface - setPerformer
     * 
     * Requirements:
     * - performer neq newPerformmer
     */ 
    function setPerformer(address newPerformer) external override onlyOwner {
        require(
            address(performer) != newPerformer, 
            "Swap::swap : Same address"
        );

        emit SetPerform(address(performer), newPerformer, block.timestamp);

        performer = PerformerInterface(newPerformer);
    }

    /**
     * @dev pause swap contract
     * 
     * Requirements
     * - onlyOwner
     * - whenNotPaused
     */ 
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev unpause swap contract
     * 
     * Requirements
     * - onlyOwner
     * - whenNotPaused
     */ 
    function unpause() external onlyOwner {
        _unpause();
    }

    // uups interface
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    receive() external payable {} 

}