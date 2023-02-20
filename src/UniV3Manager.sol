// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./interfaces/IUniV3Manager.sol";
import "./interfaces/IUniV3Pool.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./lib/LiquidityMath.sol";
import "./lib/TickMath.sol";
import "./lib/Path.sol";
import "./lib/PoolAddress.sol";

contract UniV3Manager is IUniV3Manager {
    using Path for bytes;
    error SlippageCheckFailed(uint256 amount0, uint256 amount1);

    address public immutable factory;

    constructor(address factory_) {
        factory = factory_;
    }

    function mint(MintParams calldata params)
        public
        returns (uint256 amount0, uint256 amount1)
    {
        IUniV3Pool pool = IUniV3Pool(params.poolAddress);
        (uint160 sqrtPriceX96, ) = pool.slot0();
        uint160 sqrtPriceLowerX96 = TickMath.getSqrtRatioAtTick(
            params.lowerTick
        );
        uint160 sqrtPriceUpperX96 = TickMath.getSqrtRatioAtTick(
            params.upperTick
        );
        // 计算出更小的流动性
        uint128 liquidity = LiquidityMath.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtPriceLowerX96,
            sqrtPriceUpperX96,
            params.amount0Desired,
            params.amount1Desired
        );
        (amount0, amount1) = pool.mint(
            msg.sender,
            params.lowerTick,
            params.upperTick,
            liquidity,
            abi.encode(
                IUniV3Pool.CallbackData({
                    token0: pool.token0(),
                    token1: pool.token1(),
                    payer: msg.sender
                })
            )
        );
        if (amount0 < params.amount0Min || amount1 < params.amount1Min)
            revert SlippageCheckFailed(amount0, amount1);
    }

    // function swap(address _poolAddress, bytes calldata data) public {
    //     UniV3Pool(_poolAddress).swap(msg.sender,  data);
    // }

    function uniV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) public {
        UniV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniV3Pool.CallbackData)
        );
        IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
        IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
    }

    function _swap(
        uint256 amountIn,
        address recipient,
        uint160 sqrtPriceLimitX96,
        SwapCallbackData memory data
    ) internal returns (uint256 amountOut) {
        // 第一步先从data中获取in, out 和tickspacing，来获取池子的address
        (address tokenIn, address tokenOut, uint24 tickSpacing) = data
            .path
            .decodeFirstPool();
        bool zeroForOne = tokenIn < tokenOut;
        // 获取pool，开始swap
        (int256 amount0, int256 amount1) = getPool(
            tokenIn,
            tokenOut,
            tickSpacing
        ).swap(
                recipient,
                zeroForOne,
                amountIn,
                sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : sqrtPriceLimitX96,
                abi.encode(data)
            );
        // 这里输出一定是负的，是池子给出去的钱
        amountOut = uint256(-(zeroForOne ? amount1 : amount0));
    }

    // 单池子交易
    function swapSingle(SwapSingleParams calldata params)
        public
        returns (uint256 amountOut)
    {
        amountOut = _swap(
            params.amountIn,
            msg.sender,
            params.sqrtPriceLimitX96,
            SwapCallbackData({
                path: abi.encodePacked(
                    params.tokenIn,
                    params.tickSpacing,
                    params.tokenOut
                ),
                payer: msg.sender
            })
        );
    }

    // 交易入口
    function swap(SwapParams memory params) public returns (uint256 amountOut) {
        // 第一次跨池子交易时/只有一个池子交易时：payer设置为用户，需要从用户手里拿到代币
        address payer = msg.sender;
        bool hasMultiplePools;

        while (true) {
            // 判断当前是否有多个池子
            hasMultiplePools = params.path.hasMultiplePools();
            
            params.amountIn = _swap(
                params.amountIn,
                // 跨池交易中管理合约保管代币，剩最后一次交易时，将代币发送给用户
                hasMultiplePools ? address(this) : params.recipient,
                0,
                SwapCallbackData({
                    path: params.path.getFirstPool(),
                    payer: payer
                })
            );
            if(hasMultiplePools){
                payer = address(this);
                params.path = params.path.skipToken();
            }else{
                amountOut = params.amountIn;
                break;
            }
        }

        require(amountOut >= params.minAmountOut, "Too little recieved");
    }

    function uniV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata _data
    ) public {
        SwapCallbackData memory data = abi.decode(_data, (SwapCallbackData));
        (address tokenIn, address tokenOut, ) = data.path.decodeFirstPool();
        bool zeroForOne = tokenIn < tokenOut;

        int256 amount = zeroForOne ? amount0 : amount1;
        // 判断代币接收者是管理合约还是用户，然后将tokenIn转入
        if(data.payer == address(this)){
            IERC20(tokenIn).transfer(msg.sender, amount);
        }else{
            IERC20(tokenIn).transferFrom(data.payer, msg.sender, amount);
        }
    }

    function getPool(
        address token0,
        address token1,
        uint24 tickSpacing
    ) internal view returns (IUniV3Pool pool) {
        (token0, token1) = token0 < token1
            ? (token0, token1)
            : (token1, token0);
        pool = IUniV3Pool(
            PoolAddress.computeAddress(factory, token0, token1, tickSpacing)
        );
    }
}
