// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./lib/position.sol";
import "./lib/tick.sol";
import "./interfaces/IERC20Min.sol";
import "./interfaces/callback/IUniswapV3CallBack.sol";

contract UniV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address public immutable token0;
    address public immutable token1;

    error InvalidTickRange();

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    Slot0 public slot0;

    uint128 public liquidity;

    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;

    constructor(
        address _token0,
        address _token1,
        uint160 _sqrtPriceX96,
        int24 _tick
    ) {
        (token0, token1) = (_token0, _token1);
        slot0 = Slot0({sqrtPriceX96: _sqrtPriceX96, tick: _tick});
    }

    function mint(
        address owner,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) public returns (uint256 amount0, uint256 amount1) {
        if (
            tickLower > tickUpper ||
            tickLower < MIN_TICK ||
            tickUpper > MAX_TICK
        ) revert InvalidTickRange();
        require(amount > 0, "zero liquidity");

        ticks._update(tickLower, amount);
        ticks._update(tickUpper, amount);

        Position.Info storage position = positions.get(
            owner,
            tickLower,
            tickUpper
        );
        position._update(amount);
        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1);
        if (amount0 > 0 && balance0Before + amount0 > balance0());
    }

    function balance0() internal returns (uint256 balance) {
    balance = IERC20(token0).balanceOf(address(this));
}

function balance1() internal returns (uint256 balance) {
    balance = IERC20(token1).balanceOf(address(this));
}
}
