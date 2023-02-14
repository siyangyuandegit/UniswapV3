// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
interface IUniswapV3MintCallback {
    /// @dev In the implementation you must pay the pool tokens owed for the minted liquidity.
    /// The caller of this method must be checked to be a UniswapV3Pool deployed by the canonical UniswapV3Factory.
    /// @param amount0Owed The amount of token0 due to the pool for the minted liquidity
    /// @param amount1Owed The amount of token1 due to the pool for the minted liquidity
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed
        // bytes calldata data
    ) external;
}