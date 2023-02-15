// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// import "forge-std/Test.sol";
// import "./ERC20Mintable.sol";
// import "../src/UniV3Pool.sol";
// import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";


// contract UniV3PoolTest is Test {
//     ERC20Mintable token0;
//     ERC20Mintable token1;
//     UniV3Pool pool;
//     bool shouldTransferInCallback;
//     UniV3Pool.CallbackData  data;

//     struct TestCaseParams {
//         uint256 wethBalance;
//         uint256 usdcBalance;
//         int24 currentTick;
//         int24 lowerTick;
//         int24 upperTick;
//         uint128 liquidity;
//         uint160 currentSqrtP;
//         bool shouldTransferInCallback;
//         bool mintLiqudity;
//     }

//     function setUp() public {
//         token0 = new ERC20Mintable("Ether", "ETH", 18);
//         token1 = new ERC20Mintable("USDC", "USDC", 18);
//     }

//     function testMintSuccess() public {
//         TestCaseParams memory params = TestCaseParams({
//             wethBalance: 1 ether,
//             usdcBalance: 5000 ether,
//             currentTick: 85176,
//             lowerTick: 84222,
//             upperTick: 86129,
//             liquidity: 1517882343751509868544,
//             currentSqrtP: 5602277097478614198912276234240,
//             shouldTransferInCallback: true,
//             mintLiqudity: true
//         });

//         data = UniV3Pool.CallbackData({
//             token0: address(token0),
//             token1: address(token1),
//             payer: msg.sender
//         });

//         (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);

//         uint256 expectedAmount0 = 0.998976618347425280 ether;
//         uint256 expectedAmount1 = 5000 ether;
//         assertEq(
//             poolBalance0,
//             expectedAmount0,
//             "incorrect token0 deposited amount"
//         );
//         assertEq(
//             poolBalance1,
//             expectedAmount1,
//             "incorrect token1 deposited amount"
//         );

//         bytes32 positionKey = keccak256(
//             abi.encodePacked(address(this), params.lowerTick, params.upperTick)
//         );

//         uint128 posLiquidity = pool.positions(positionKey);
//         assertEq(posLiquidity, params.liquidity);

//         (bool tickInitialized, uint128 tickLiquidity) = pool.ticks(
//             params.lowerTick
//         );
//         assertTrue(tickInitialized);
//         assertEq(tickLiquidity, params.liquidity);

//         (tickInitialized, tickLiquidity) = pool.ticks(params.upperTick);
//         assertTrue(tickInitialized);
//         assertEq(tickLiquidity, params.liquidity);

//         (uint160 sqrtPriceX96, int24 tick) = pool.slot0();
//         assertEq(
//             sqrtPriceX96,
//             5602277097478614198912276234240,
//             "invalid current sqrtP"
//         );
//         assertEq(tick, 85176, "invalid current tick");
//         assertEq(
//             pool.liquidity(),
//             1517882343751509868544,
//             "invalid current liquidity"
//         );
//         console2.log("The user ETH reserves :", token0.balanceOf(address(this)));
//     }

//     function setupTestCase(TestCaseParams memory params)
//         internal
//         returns (uint256 poolBalance0, uint256 poolBalance1)
//     {
//         token0.mint(address(this), params.wethBalance);
//         token1.mint(address(this), params.usdcBalance);

//         pool = new UniV3Pool(
//             address(token0),
//             address(token1),
//             params.currentSqrtP,
//             params.currentTick
//         );
//         shouldTransferInCallback = params.shouldTransferInCallback;

//         if (params.mintLiqudity) {
//             (poolBalance0, poolBalance1) = pool.mint(
//                 address(this),
//                 params.lowerTick,
//                 params.upperTick,
//                 params.liquidity
//             );
//         }
//     }

//     function uniswapV3MintCallback(uint256 amount0, uint256 amount1,bytes calldata data) public {
//         if (shouldTransferInCallback) {
//             UniV3Pool.CallbackData memory extra = abi.decode(data, (UniV3Pool.CallbackData));
//             IERC20(extra.token0).transferFrom(extra.payer, msg.sender, amount0);
//             IERC20(extra.token1).transferFrom(extra.payer, msg.sender, amount1);
//         }
//     }



//     function testSwapBuyEth() public {
//     TestCaseParams memory params = TestCaseParams({
//         wethBalance: 1 ether,
//         usdcBalance: 5000 ether,
//         currentTick: 85176,
//         lowerTick: 84222,
//         upperTick: 86129,
//         liquidity: 1517882343751509868544,
//         currentSqrtP: 5602277097478614198912276234240,
//         shouldTransferInCallback: true,
//         mintLiqudity: true
//     });
//     (uint256 poolBalance0, uint256 poolBalance1) = setupTestCase(params);
//     token1.mint(address(this), 42 ether);
//     uint256 ethRserve = token0.balanceOf(address(this));
//     (int256 amount0Delta, int256 amount1Delta) =pool.swap(address(this));
//     assertEq(amount0Delta, -0.008396714242162444 ether, "invalid ETH output");
//     assertEq(amount1Delta, 42 ether, "invalid USDC input");
//     uint256 userNowETH = token0.balanceOf(address(this)) - ethRserve;
//     uint256 userNowUSDC = token1.balanceOf(address(this));
//     assertEq(userNowETH, 0.008396714242162444 ether, "user don't recieve eth");
//     assertEq(userNowUSDC, 0, "user don't transfer USDC");
//     // 测试代币被发到池子中
//     assertEq(token0.balanceOf(address(pool)), uint256(int256(poolBalance0) + amount0Delta), "contract don't transfer ETH to user");
//     assertEq(token1.balanceOf(address(pool)), uint256(int256(poolBalance1) + amount1Delta), "contract don't recieve USDC from user");
    
//     // 测试流动性
//     assertEq(pool.liquidity(), params.liquidity, "liquidity error");
//     }

//     function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) public {
//         UniV3Pool.CallbackData memory extra = abi.decode(data, (UniV3Pool.CallbackData));
//         if(amount0 >0){
//             IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
//         }
//         if(amount1 > 0){
//             IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
//         }
//     }

//     // function invariant_example() external{}

// }
