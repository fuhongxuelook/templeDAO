// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IFactory {
    /// fee recipient address
    function feeTo() external view returns (address);

    /// fee recipient address setter
    function owner() external view returns (address);

    /// vault address
    function vault() external view returns (address);

    /// inter router address
    function swaper() external view returns (address);

    /// @dev all pools length 
    function allPoolsLength() external view returns (uint);

    /// @dev get pool address via id
    function getPool(uint256 id) external view returns (address);

    /// @dev create new pool
    function createPool(string memory poolname) external returns (address pool);
   
    /// @dev set fee to
    function setFeeTo(address _feeTo) external;

    /// @dev vault
    function setVault(address _vault) external;

    /// @dev swap
    function setSwaper(address _router) external;
}