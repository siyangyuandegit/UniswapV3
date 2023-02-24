// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "./interfaces/IUniV3Pool.sol";
import "./lib/Path.sol";
import "./lib/PoolAddress.sol";
import "./lib/TickMath.sol";

contract UniV3Quoter {
    using Path for bytes;
    struct QuoteParams {
        address tokenIn;
        address tokenOut;
        uint24 tickSpacing;
        uint256 amountIn;
        uint160 sqrtPriceLimitX96;
    }
    address public immutable factory;

    constructor(address factory_) {
        factory = factory_;
    }

    function quote(bytes memory path, uint256 amountIn)
        public
        returns (
            uint256 amountOut,
            uint160[] memory sqrtPriceX96AfterList,
            int24[] memory tickAfterList
        )
    {
        sqrtPriceX96AfterList = new uint160[](path.numPools());
        tickAfterList = new int24[](path.numPools());

        uint256 i = 0;
        while (true) {
            (address tokenIn, address tokenOut, uint24 tickSpacing) = path
                .decodeFirstPool();
            (uint256 amountOut_, uint160 sqrtPriceX96After, int24 tickAfter) = quoteSingle(
                QuoteParams({
                    tokenIn: tokenIn,
                    tokenOut: tokenOut,
                    tickSpacing: tickSpacing,
                    amountIn: amountIn,
                    sqrtPriceLimitX96: 0
                })
            );
            sqrtPriceX96AfterList[i] = sqrtPriceX96After;
            tickAfterList[i] = tickAfter;
            amountIn = amountOut_;
            i++;

            if(path.hasMultiplePools()){
                path = path.skipToken();
            }else{
                amountOut = amountIn;
                break;
            }
        }
    }

    function quoteSingle(QuoteParams memory params)
        public
        returns (
            uint256 amountIn,
            uint160 sqrtPriceX96After,
            int24 tickAfter
        )
    {
        IUniV3Pool pool = getPool(
            params.tokenIn,
            params.tokenOut,
            params.tickSpacing
        );
        bool zeroForOne = params.tokenIn < params.tokenOut;

        try
            pool.swap(
                address(this),
                zeroForOne,
                params.amountIn,
                params.sqrtPriceLimitX96 == 0
                    ? (
                        zeroForOne
                            ? TickMath.MIN_SQRT_RATIO + 1
                            : TickMath.MAX_SQRT_RATIO - 1
                    )
                    : params.sqrtPriceLimitX96,
                abi.encode(address(pool))
            ){}catch(bytes memory reason){
                return abi.decode(reason, (uint256, uint160, int24));
            }
    }

    function uniV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes memory data
    ) external view {
        address pool = abi.decode(data, (address));
        uint256 amountOut = amount0Delta > 0
            ? uint256(-amount1Delta)
            : uint256(-amount0Delta);

        (uint160 sqrtPriceX96After, int24 tickAfter, , , ) = IUniV3Pool(pool).slot0();
        // 这里实际上就是abi.encode做的（每个数据都是32字节，总共三个，所以96字节的偏移量）
        assembly {
            // 读取下一个可用memory slot的指针，EVM中memory组织成32字节的slot形式
            let ptr := mload(0x40)
            // 在该slot中，写入amountOut
            mstore(ptr, amountOut)
            // 在amount后边写入sqrtPrice
            mstore(add(ptr, 0x20), sqrtPriceX96After)
            // 在price后边写入tickAfter
            mstore(add(ptr, 0x40), tickAfter)
            // revert这个调用，并返回ptr指向位置的96字节数据
            revert(ptr, 96)
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
