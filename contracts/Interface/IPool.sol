// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IPool {
    // mapping(address => uint256) public tokenReserve;

    function tokenReserve(address token) external view returns(uint256);

    function initialize(
        string memory _poolname, 
        address _vault, 
        address _swap,
        address _owner
    ) external;

    /// @dev add allowed token 
    function addAllowed(address token, address feed) external;

    /// @dev remove allowed token
    function removeAllowed(address token) external;

    /// @dev get pool name
    function getPoolName() external view returns (string memory);

    /// @dev value on pool
    function valueInPool(address account) external view returns (uint256 value);

    /// @dev trade token to other token
    function trade(
        uint aggregatorIndex,
        address tokenFrom,
        address tokenTo,
        uint256 amount,
        bytes calldata data
    ) external;

    /// @dev liquidate token to USDT
    function liquidate(
        uint aggregatorIndex,
        address token,
        uint256 amount,
        bytes calldata data
    ) external;

    /// @dev mint token
    function safeMint(address to) external returns (uint liquidity);
    /// @dev burn token
    function safeBurn(address to) external returns (uint amount0);

    function getReserves() external view returns (uint256 value);

}