// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

interface IUniV3Pool {

    function slot0() external view returns (uint160 sqrtPriceX96, int24 tick);
    function token0() external view returns (address);
    function token1() external view returns (address);
    
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256, int256);

    function mint(
        address owner,
        int24 lowerTick,
        int24 upperTick,
        uint128 amount,
        bytes calldata data
    ) external returns(uint256 amount0, uint256 amount1);
}