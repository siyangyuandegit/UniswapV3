// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./lib/position.sol";
import "./lib/FixedPoint128.sol";
import "./lib/tick.sol";
import "./lib/tickBitmap.sol";
import "./interfaces/IERC20Min.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./interfaces/callback/IUniswapV3MintCallback.sol";
import "./interfaces/callback/IUniswapV3SwapCallBack.sol";
import "./interfaces/callback/IUniV3FlashCallBack.sol";
import "./interfaces/IUniV3PoolDeployer.sol";
import "./lib/Math.sol";
import "./lib/TickMath.sol";
import "./lib/SwapMath.sol";
import "forge-std/Test.sol";
import "./lib/LiquidityMath.sol";

contract UniV3Pool is Test {
    using Tick for mapping(int24 => Tick.Info);
    using Position for mapping(bytes32 => Position.Info);
    using Position for Position.Info;
    using TickBitmap for mapping(int16 => uint256);

    mapping(int16 => uint256) public tickBitmap;

    int24 internal constant MIN_TICK = -887272;
    int24 internal constant MAX_TICK = -MIN_TICK;

    address public immutable factory;
    address public immutable token0;
    address public immutable token1;
    uint24 public immutable tickSpacing;
    // uint24 public immutable fee;
    mapping(int24 => Tick.Info) public ticks;
    mapping(bytes32 => Position.Info) public positions;
    uint128 public liquidity;
    // 设置池子的手续费
    uint24 public immutable fee;
    uint256 public feeGrowthGlobal0X128;
    uint256 public feeGrowthGlobal1X128;

    struct Slot0 {
        uint160 sqrtPriceX96;
        int24 tick;
    }

    Slot0 public slot0;

    struct ModifyPositionParams {
        address owner;
        int24 lowerTick;
        int24 upperTick;
        int128 liquidityDelta;
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
        // 全局手续费
        uint256 feeGrowthGlobalX128;
        // 池子被激活的总流动性
        uint128 liquidity;
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
        uint256 feeAmount;
    }

    event Burn(
        address indexed owner,
        int24 indexed tickLower,
        int24 indexed tickUpper,
        uint128 amount,
        uint256 amount0,
        uint256 amount1
    );

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

    event Flash(address indexed recipient, uint256 amount0, uint256 amount1);

    error InvalidTickRange();
    error InsufficientInputAmount();
    error NotEnoughLiquidity();
    error InvalidPriceLimit();
    error FlashLoanNotPaid();

    constructor() {
        (factory, token0, token1, tickSpacing, fee) = IUniV3PoolDeployer(msg.sender).parameters();
    }

    function initialize(uint160 sqrtPriceX96) public {
        require(slot0.sqrtPriceX96 == 0, "already init");
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        slot0 = Slot0({sqrtPriceX96: sqrtPriceX96, tick: tick});
    }

    function _modifyPosition(ModifyPositionParams memory params)
        internal
        returns (Position.Info storage position, int256 amount0, int256 amount1)
    {
        Slot0 memory slot0_ = slot0;
        uint256 feeGrowthGlobal0X128_ = feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128_ = feeGrowthGlobal1X128;

        // 获取position
        position = positions.get(params.owner, params.lowerTick, params.upperTick);

        // 更新上下边界的数据，得到是否需要反转的bool值
        bool flippedLower = ticks._update(
            params.lowerTick, slot0_.tick, params.liquidityDelta, feeGrowthGlobal0X128_, feeGrowthGlobal1X128_, false
        );
        bool flippedUpper = ticks._update(
            params.upperTick, slot0_.tick, params.liquidityDelta, feeGrowthGlobal0X128_, feeGrowthGlobal1X128, true
        );

        if (flippedLower) {
            tickBitmap.flickTick(params.lowerTick, int24(tickSpacing));
        }
        if (flippedUpper) {
            tickBitmap.flickTick(params.upperTick, int24(tickSpacing));
        }

        // 计算position中的手续费
        (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128) = ticks.getFeeGrowthInside(
            params.lowerTick, params.upperTick, slot0_.tick, feeGrowthGlobal0X128_, feeGrowthGlobal1X128_
        );
        // 更新position数据
        position._update(params.liquidityDelta, feeGrowthInside0X128, feeGrowthInside1X128);
        // 根据流动性和价格区间与current tick的关系计算amount0/amount1的数量
        if (slot0_.tick < params.lowerTick) {
            // 如果当前tick小于lowerTick，该区间若想被激活，只能提供amount0，以供用户买入
            amount0 = Math.calcAmount0Delta(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                TickMath.getSqrtRatioAtTick(params.upperTick),
                params.liquidityDelta
            );
        } else if (slot0_.tick < params.upperTick) {
            // 如果当前价格在position中，则需要同时提供amount0和1,并且增加当前激活的流动性
            amount0 = Math.calcAmount0Delta(
                slot0_.sqrtPriceX96, TickMath.getSqrtRatioAtTick(params.upperTick), params.liquidityDelta
            );
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.lowerTick), slot0_.sqrtPriceX96, params.liquidityDelta
            );
            liquidity = LiquidityMath.addLiquidity(liquidity, params.liquidityDelta);
        } else {
            // 如果当前tick大于upperTick，该区间想被激活，只能提供amount1，供用户卖出amount0
            amount1 = Math.calcAmount1Delta(
                TickMath.getSqrtRatioAtTick(params.lowerTick),
                TickMath.getSqrtRatioAtTick(params.upperTick),
                params.liquidityDelta
            );
        }
    }

    function mint(address owner, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        public
        returns (uint256 amount0, uint256 amount1)
    {
        if (tickLower > tickUpper || tickLower < MIN_TICK || tickUpper > MAX_TICK) revert InvalidTickRange();
        require(amount > 0, "zero liquidity");

        (, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: owner,
                lowerTick: tickLower,
                upperTick: tickUpper,
                liquidityDelta: int128(amount)
            })
        );

        amount0 = uint256(amount0Int);
        amount1 = uint256(amount1Int);

        uint256 balance0Before;
        uint256 balance1Before;

        if (amount0 > 0) balance0Before = balance0();
        if (amount1 > 0) balance1Before = balance1();
        IUniswapV3MintCallback(msg.sender).uniswapV3MintCallback(amount0, amount1, data);

        if (amount0 > 0 && balance0Before + amount0 > balance0()) {
            revert InsufficientInputAmount();
        }
        if (amount1 > 0 && balance1Before + amount1 > balance1()) {
            revert InsufficientInputAmount();
        }

        emit Mint(msg.sender, owner, tickLower, tickUpper, amount, amount0, amount1);
    }

    function burn(int24 lowerTick, int24 upperTick, uint128 amount) public returns (uint256 amount0, uint256 amount1) {
        (Position.Info storage position, int256 amount0Int, int256 amount1Int) = _modifyPosition(
            ModifyPositionParams({
                owner: msg.sender,
                lowerTick: lowerTick,
                upperTick: upperTick,
                liquidityDelta: -(int128(amount))
            })
        );

        amount0 = uint256(-amount0Int);
        amount1 = uint256(-amount1Int);

        if (amount0 > 0 || amount1 > 0) {
            (position.tokensOwed0, position.tokensOwed1) =
                (position.tokensOwed0 + uint128(amount0), position.tokensOwed1 + uint128(amount1));
        }

        emit Burn(msg.sender, lowerTick, upperTick, amount, amount0, amount1);
    }

    function balance0() internal view returns (uint256 balance) {
        balance = IERC20(token0).balanceOf(address(this));
    }

    function balance1() internal view returns (uint256 balance) {
        balance = IERC20(token1).balanceOf(address(this));
    }

    // zeroForOne为true时，token0交换token1，即卖出token0
    // sqrtPriceLimitX96为滑点保护价格
    function swap(
        address recipient,
        bool zeroForOne,
        uint256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) public returns (int256 amount0, int256 amount1) {
        Slot0 memory slot0_ = slot0;
        uint128 liquidity_ = liquidity;
        if (
            zeroForOne
                ? sqrtPriceLimitX96 > slot0_.sqrtPriceX96 || sqrtPriceLimitX96 < TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 < slot0_.sqrtPriceX96 || sqrtPriceLimitX96 > TickMath.MAX_SQRT_RATIO
        ) revert InvalidPriceLimit();
        SwapState memory state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: slot0_.sqrtPriceX96,
            tick: slot0_.tick,
            // sold token0 pay token0 for fee
            feeGrowthGlobalX128: zeroForOne ? feeGrowthGlobal0X128 : feeGrowthGlobal1X128,
            liquidity: liquidity_
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
        while (state.amountSpecifiedRemaining > 0 && state.sqrtPriceX96 != sqrtPriceLimitX96) {
            console2.log("--------strat step-----------");
            // 初始化step
            StepState memory step;
            // 将state的当前价格赋给step的本次开始价格
            step.sqrtPriceStartX96 = state.sqrtPriceX96;
            // 使用当前价格计算出下一个可用的被初始化的tick
            console2.log("current tick: ", state.tick);
            (step.nextTick,) = tickBitmap.nextInitializedTickWithinOneWord(state.tick, 1, zeroForOne);

            // 将step.nexttick计算出精确价格，赋予step.sqrtPriceNextX96
            step.sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(step.nextTick);

            // 将当前价格和下一个被激活的tick对应的价格传入，用于计算当前激活区间可提供的amountin
            (state.sqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
                state.sqrtPriceX96,
                // 根据交易方向，和滑点价格计算
                (zeroForOne ? step.sqrtPriceNextX96 < sqrtPriceLimitX96 : step.sqrtPriceNextX96 > sqrtPriceLimitX96)
                    ? sqrtPriceLimitX96
                    : step.sqrtPriceNextX96,
                state.liquidity,
                state.amountSpecifiedRemaining,
                fee
            );

            require(step.amountIn > 0, "invaild num");
            // 这里累计的是单位流动性的fee，也就是总手续费/总流动性
            state.feeGrowthGlobalX128 += mulDiv(step.feeAmount, FixedPoint128.Q128, state.liquidity);
            state.amountSpecifiedRemaining -= step.amountIn;

            state.amountCalculated += step.amountOut;
            // 若现价为区间tick边界，说明该区间流动性为0，需要跨越区间
            if (state.sqrtPriceX96 == step.sqrtPriceNextX96) {
                int128 liquidityDelta = ticks.cross(
                    step.nextTick,
                    (zeroForOne ? state.feeGrowthGlobalX128 : feeGrowthGlobal0X128),
                    (zeroForOne ? feeGrowthGlobal1X128 : state.feeGrowthGlobalX128)
                );
                // 从左到右穿越tick，穿越下界需要增加流动性，穿越上界要降低流动性ƒ
                // 若从右到左穿越，即zeroForOne为false，则相反
                if (zeroForOne) liquidityDelta = -liquidityDelta;
                state.liquidity = LiquidityMath.addLiquidity(state.liquidity, liquidityDelta);

                if (state.liquidity == 0) revert NotEnoughLiquidity();
                // tick区间设置的是左闭右开的，如果价格降低，需要-1到下一个区间，
                // 如果升高，则已经到了下一个区间
                state.tick = zeroForOne ? step.nextTick - 1 : step.nextTick;
            } else {
                state.tick = TickMath.getTickAtSqrtRatio(state.sqrtPriceX96);
            }
            console2.log("-------step done------------");
        }

        if (state.tick != slot0_.tick) {
            (slot0.sqrtPriceX96, slot0.tick) = (state.sqrtPriceX96, state.tick);
            console2.log("now the lastet tick is : ", slot0.tick);
        }

        if (liquidity_ != state.liquidity) liquidity = state.liquidity;

        (amount0, amount1) = zeroForOne
            ? (int256(amountSpecified - state.amountSpecifiedRemaining), -int256(state.amountCalculated))
            : (-int256(state.amountCalculated), int256(amountSpecified - state.amountSpecifiedRemaining));

        if (zeroForOne) {
            IERC20(token1).transfer(recipient, uint256(-amount1));

            uint256 balance0Before = balance0();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            if (balance0Before + uint256(amount0) > balance0()) {
                revert InsufficientInputAmount();
            }
        } else {
            IERC20(token0).transfer(recipient, uint256(-amount0));

            uint256 balance1Before = balance1();
            IUniswapV3SwapCallback(msg.sender).uniswapV3SwapCallback(amount0, amount1, data);
            if (balance1Before + uint256(amount1) > balance1()) {
                revert InsufficientInputAmount();
            }
        }

        emit Swap(msg.sender, recipient, amount0, amount1, slot0.sqrtPriceX96, state.liquidity, slot0.tick);
    }

    function flash(uint256 amount0, uint256 amount1, bytes calldata data) public {
        uint256 balance0Before = IERC20(token0).balanceOf(address(this));
        uint256 balance1Before = IERC20(token1).balanceOf(address(this));

        if (amount0 > 0) IERC20(token0).transfer(msg.sender, amount0);
        if (amount1 > 0) IERC20(token1).transfer(msg.sender, amount1);

        IUniswapV3FlashCallback(msg.sender).uniswapV3FlashCallback(data);
        require(IERC20(token0).balanceOf(address(this)) >= balance0Before, "FlashLoanNotPaid");
        require(IERC20(token1).balanceOf(address(this)) >= balance1Before, "FlashLoanNotPaid");

        emit Flash(msg.sender, amount0, amount1);
    }
}
