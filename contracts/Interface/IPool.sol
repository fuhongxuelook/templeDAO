// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

interface IPool {

    event TradeTrace(
        address fromToken, 
        address toToken, 
        uint256 fromAmount, 
        uint256 toAmount,
        uint256 blockTime
    );

    error TokenNotAllowed(address token);


    function initialize(address _vault, string _name) external;

    /// @dev add allowed token 
    function addAllowed(address token) external;

    /// @dev remove allowed token
    function removeAllowed(address token) external;

    /// @dev get pool name
    function getName() external view returns (string);

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

    /// @dev vault take USDT from pool
    function pool2Vault(uint256 amount) external;

    /// @dev vault send USDT to pool
    function vault2Pool(uint256 amount) external;

    /// @dev mint token
    function safeMint(address account, uint256 amount) external;
    /// @dev burn token
    function safeBurn(address account, uint256 amount) external;
}