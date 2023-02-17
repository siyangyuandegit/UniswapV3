// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./lib/position.sol";
import "./lib/tick.sol";
import "./lib/tickBitmap.sol";
import "./interfaces/IERC20Min.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/callback/IUniswapV3MintCallback.sol";
import "./interfaces/callback/IUniswapV3SwapCallBack.sol";
import "./lib/Math.sol";
import "./lib/TickMath.sol";
import "./lib/SwapMath.sol";
import "forge-std/Test.sol";


contract UniV3Pool is Test {
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

    struct SwapState {
        // 还需要从池子中获取的token数量
        uint256 amountSpecifiedRemaining;
        // 由合约计算出的token输出量
        uint256 amountCalculated;
        // 交易结束后的价格
        uint160 sqrtPriceX96;
        // 交易结束后的tick
        int24 tick;
    }

    struct StepState {
        // 循环开始的价格
        uint160 sqrtPriceStartX96;
        // 下一个能够提供流动性的初始化的tick
        int24 nextTick;
        // 下一个tick的价格
        uint160 sqrtPriceNextX96;
        // 当前流动性能提供的数量
        uint256 amountIn;
        uint256 amountOut;
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
        console2.log("ticklower: ", tickLower);
        console2.log("tick lower init: ", flippedLower);
        console2.log("tickupper: ", tickUpper);
        console2.log("tick upper init: ", flippedUpper);

        console2.log(ticks[85247].initialized);
        if (flippedLower) {
            tickBitmap.flickTick(tickLower, 1);
        }
        if (flippedUpper) {
            tickBitmap.flickTick(tickUpper, 1);
        }

        Position.Info storage position = positions.get(
            owner,
            tickLower,
            tickUpper
        );
        liquidity = position._update(amount);
        amount0 = Math.calcAmount0Delta(
            slot0.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
        amount1 = Math.calcAmount1Delta(
            slot0.sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            liquidity
        );

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

    // zeroForOne为true时，token0交换token1，即卖出token0
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        Slot0 memory slot0_ = slot0;

        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0_.sqrtPriceX96,
            tick: slot0_.tick
        });

        // struct SwapState {
        //     uint256 amountSpecifiedRemaining;
        //     uint256 amountCalculated;
        //     uint160 sqrtPriceX96;
        //     int24 tick;
        // }

        // struct StepState {
        //     uint160 sqrtPriceStartX96;
        //     int24 nextTick;
        //     uint160 sqrtPriceNextX96;
        //     uint256 amountIn;
        //     uint256 amountOut;
        // }
        while (state.amountSpecifiedRemaining > 0) {
            console2.log("--------strat step-----------");
            // 初始化step
            StepState memory step;
            // 将state的当前价格赋给step的本次开始价格
            step.sqrtPriceStartX96 = state.sqrtPriceX96;
            // 使用当前价格计算出下一个可用的被初始化的tick
            console2.log("current tick: ", state.tick);
            (step.nextTick, ) = tickBitmap.nextInitializedTickWithinOneWord(
                state.tick,
                1,
                zeroForOne
            );
            console2.log("next tick: ", step.nextTick);
            // 将step.nexttick计算出精确价格，赋予step.sqrtPriceNextX96
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);
            console2.log("now price", state.sqrtPriceX96);
            console2.log("next price", step.sqrtPriceNextX96);
            console2.log("remaining ", state.amountSpecifiedRemaining);
            console2.log("liquidity ", liquidity);
            (state.sqrtPriceX96, step.amountIn, step.amountOut) = SwapMath
                .computeSwapStep(
                    state.sqrtPriceX96,
                    step.sqrtPriceNextX96,
                    liquidity,
                    state.amountSpecifiedRemaining
                );
            

            console2.log("now price", state.sqrtPriceX96);
            console2.log("step.amountIn: ", step.amountIn);
            console2.log("step.amountOut: ", step.amountOut);
            require(step.amountIn > 0, "invaild num");
            state.amountSpecifiedRemaining -= step.amountIn;

            state.amountCalculated += step.amountOut;
            state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            console2.log("-------step done------------");
        }

        if (state.tick != slot0_.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
            console2.log("now the lastet tick is : ", slot0.tick);
        }

        (amount0, amount1) = zeroForOne
            ? (
                int256(amountSpecified - state.amountSpecifiedRemaining),
                -int256(state.amountCalculated)
            )
            : (
                -int256(state.amountCalculated),
                int256(amountSpecified - state.amountSpecifiedRemaining)
            );

        if (zeroForOne) {
            IERC20(token1).transfer(recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );
            if (balance0Before + uint256(amount0) > balance0())
                revert InsufficientInputAmount();
        } else {
            IERC20(token0).transfer(recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(
                amount0,
                amount1,
                data
            );
            if (balance1Before + uint256(amount1) > balance1())
                revert InsufficientInputAmount();
        }

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
