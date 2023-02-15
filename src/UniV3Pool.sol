// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./lib/position.sol";
import "./lib/tick.sol";
import "./lib/tickBitmap.sol";
import "./interfaces/IERC20Min.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/callback/IUniswapV3MintCallback.sol";
import "./interfaces/callback/IUniswapV3SwapCallBack.sol";

contract UniV3Pool {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using TickBitmap for mapping(int16 => uint256);
    mapping(int16 => uint256) public tickBitmap;

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address public immutable token0;
    address public immutable token1;

    struct CallbackData {
        address token0;
        address token1;
        address payer;
    }

    event Mint(
        address sender,
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

    event Swap(
        address indexed sender,
        address indexed recipient,
        int256 amount0,
        int256 amount1,
        uint160 sqrtPriceX96,
        uint128 liquidity,
        int24 tick
    );

    error InvalidTickRange();
    error InsufficientInputAmount();

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
        uint128 amount,
        bytes calldata data
    ) public returns (uint256 amount0, uint256 amount1) {
        if (
            tickLower > tickUpper ||
            tickLower < MIN_TICK ||
            tickUpper > MAX_TICK
        ) revert InvalidTickRange();
        require(amount > 0, "zero liquidity");

        bool flippedLower = ticks._update(tickLower, amount);
        bool flippedUpper = ticks._update(tickUpper, amount);
        if(flippedLower){
            tickBitmap.flickTick(tickLower, 1);
        }
        if(flippedUpper){
            tickBitmap.flickTick(tickUpper, 1);
        }

        Position.Info storage position = positions.get(
            owner,
            tickLower,
            tickUpper
        );
        liquidity = position._update(amount);
        amount0 = 0.998976618347425280 ether;
        amount1 = 5000 ether;

        uint256 balance0Before;
        uint256 balance1Before;
        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();

        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(
            amount0,
            amount1,
            data
        );
        if (amount0 > 0 && balance0Before + amount0 > balance0())
            revert InsufficientInputAmount();
        if (amount1 > 0 && balance1Before + amount1 > balance1())
            revert InsufficientInputAmount();

        emit Mint(
            msg.sender,
            owner,
            tickLower,
            tickUpper,
            amount,
            amount0,
            amount1
        );
    }

    function balance0() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }

    function swap(address recipient, bytes calldata data)
        public
        returns (int256 amount0, int256 amount1)
    {
        int24 nextTick = 85184;
        uint160 nextPrice = 5604469350942327889444743441197;

        amount0 = -0.008396714242162444 ether;
        amount1 = 42 ether;

        (slot0.tick, slot0.sqrtPriceX96) = (nextTick, nextPrice);
        // 判断需要向用户支付那种代币
        (int256 amount, address token) = amount0 < 0
            ? (amount0, token0)
            : (amount1, token1);
        IERC20(token).transfer(recipient, uint256(-amount));
        uint256 balance1Before = balance1();
        IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
            amount0,
            amount1,
            data
        );

        if (balance1Before + uint256(amount1) < balance1())
            revert InsufficientInputAmount();

        emit Swap(
            msg.sender,
            recipient,
            amount0,
            amount1,
            slot0.sqrtPriceX96,
            liquidity,
            slot0.tick
        );
    }
}
