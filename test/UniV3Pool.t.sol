// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniV3Pool.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract UniV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniV3Pool pool;
    bool shouldTransferInCallback;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool shouldTransferInCallback;
        bool mintLiqudity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
    }

    function testMintSuccess() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiqudity: true
        });

        bytes memory data = abi.encode(
            UniV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );

        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(
            params,
            data
        );

        bytes32 positionKey = keccak256(
            abi.encodePacked(address(this), params.lowerTick, params.upperTick)
        );

        uint128 posLiquidity = pool.positions(positionKey);

        console2.log(posLiquidity);

        (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(
            params.lowerTick
        );
        assertEq(tickInitialized, true, "error init ");
        assertEq(tickLiquidity, params.liquidity, "error liquidity");
        (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
        assertEq(tickInitialized, true, "error init ");
        assertEq(tickLiquidity, params.liquidity, "error liquidity");
        // (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
        // 二次mint
    }

    function setupTestCase(TestCaseParams memory params, bytes memory data)
        internal
        returns (uint256 poolBalance0, uint256 poolBalance1)
    {
        token0.mint(address(this), params.wethBalance * 5);
        token1.mint(address(this), params.usdcBalance * 5);

        pool = new UniV3Pool(
            address(token0),
            address(token1),
            params.currentSqrtP,
            params.currentTick
        );
        console2.log("the pool's address : ", address(pool));
        shouldTransferInCallback = params.shouldTransferInCallback;

        if (params.mintLiqudity) {
            (poolBalance0, poolBalance1) = pool.mint(
                address(this),
                params.lowerTick,
                params.upperTick,
                params.liquidity,
                data
            );
        }
        // 84222 bitPos: 254, wordPos: 328
        // 86129 bitPos: 113, wordPos: 336
        // 85176 bitPos: 184, wordPos: 332
        // 85247 bitPos: 255, wordPos: 332

        uint256 liquidity = pool.liquidity();
        console2.log("pool's liquidity: ", liquidity);
        uint256 lower_tick = pool.tickBitmap(328);
        uint256 upper_tick = pool.tickBitmap(336);
        uint256 current_tick = pool.tickBitmap(332);

        console2.log("current tickbitmap: ", current_tick);
        console2.log("lower tickbitmap: ", lower_tick);
        console2.log("upper tickbitmap: ", upper_tick);
        assertEq(params.liquidity, liquidity, "invalid liquidity");
    }

    function uniswapV3MintCallback(
        uint256 amount0,
        uint256 amount1,
        bytes calldata _data
    ) public {
        if (shouldTransferInCallback) {
            UniV3Pool.CallbackData memory extra = abi.decode(
                _data,
                (UniV3Pool.CallbackData)
            );

            // 这里使用了transferFrom，要检查从from到msg.sender的allowance，测试版extra.payer
            // 与该测试合约相同，所以需要approve(address(this));
            IERC20(extra.token0).approve(address(this), amount0);
            IERC20(extra.token1).approve(address(this), amount1);

            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
        }
    }

    function testSwapBuyEth() public {
        TestCaseParams memory params = TestCaseParams({
            wethBalance: 1 ether,
            usdcBalance: 5000 ether,
            currentTick: 85176,
            lowerTick: 84222,
            upperTick: 86129,
            liquidity: 1517882343751509868544,
            currentSqrtP: 5602277097478614198912276234240,
            shouldTransferInCallback: true,
            mintLiqudity: true
        });

        bytes memory data = abi.encode(
            UniV3Pool.CallbackData({
                token0: address(token0),
                token1: address(token1),
                payer: address(this)
            })
        );
        (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(
            params,
            data
        );

        uint256 ethRserve = token0.balanceOf(address(this));
        uint256 a = IERC20(address(token0)).balanceOf(address(pool));
        uint256 b = IERC20(address(token1)).balanceOf(address(pool));
        console2.log("pool ETH reserves: ", a);
        console2.log("pool USDC reserves: ", b);
        console2.log("this eth", ethRserve);
        (int256 amount0Delta, int256 amount1Delta) = pool.swap(
            address(this),
            false,
            1000 ether,
            data
        );
        console2.log("wtf?????: ", amount0Delta);

        uint256 userNowETH = token0.balanceOf(address(this));
        uint256 userNowUSDC = token1.balanceOf(address(this));
        uint256 _a = uint256(-amount0Delta);
        console2.log(_a);
        console2.log(userNowETH);

        assertEq(
            userNowETH,
            ethRserve + _a,
            "error eth reserves?"
        );


        pool.swap(
            address(this),
            false,
            1000 ether,
            data
        );
        uint256 ll_tick = pool.tickBitmap(333);
        console2.log("does it init?", ll_tick);
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        UniV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniV3Pool.CallbackData)
        );
        if (amount0 > 0) {
            IERC20(extra.token0).approve(address(this), uint256(amount0));
            IERC20(extra.token0).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount0)
            );
        }
        if (amount1 > 0) {
            IERC20(extra.token1).approve(address(this), uint256(amount1));

            IERC20(extra.token1).transferFrom(
                extra.payer,
                msg.sender,
                uint256(amount1)
            );
        }
    }

    // function invariant_example() external{}
}
