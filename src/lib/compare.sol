




// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.14;
// import "prb-math/Core.sol";
// import "./FixedPoint96.sol";

// library Math {
//     function calcAmount0Delta(
//         uint160 sqrtPriceAX96,
//         uint160 sqrtPriceBX96,
//         uint128 liquidity
//     ) internal pure returns (uint256 amount0) {
//         if (sqrtPriceAX96 > sqrtPriceBX96)
//             (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);
//         require(sqrtPriceAX96 > 0);

//         amount0 = divRoundingUp(
//             mulDivRoundingUp(
//                 (uint256(liquidity) << FixedPoint96.RESOLUTION),
//                 (sqrtPriceBX96 - sqrtPriceAX96),
//                 sqrtPriceBX96
//             ),
//             sqrtPriceAX96
//         );
//     }

//     function calcAmount1Delta(
//         uint160 sqrtPriceAX96,
//         uint160 sqrtPriceBX96,
//         uint128 liquidity
//     ) internal pure returns (uint256 amount1) {
//         if (sqrtPriceAX96 > sqrtPriceBX96)
//             (sqrtPriceAX96, sqrtPriceBX96) = (sqrtPriceBX96, sqrtPriceAX96);

//         amount1 = mulDivRoundingUp(
//             liquidity,
//             (sqrtPriceBX96 - sqrtPriceAX96),
//             FixedPoint96.Q96
//         );
//     }

//     function mulDivRoundingUp(
//         uint256 a,
//         uint256 b,
//         uint256 denominator
//     ) internal pure returns (uint256 result) {
//         result = mulDiv(a, b, denominator);
//     }

//     function divRoundingUp(uint256 numerator, uint256 denominator)
//         internal
//         pure
//         returns (uint256 result)
//     {
//         assembly {
//             result := add(
//                 div(numerator, denominator),
//                 gt(mod(numerator, denominator), 0)
//             )
//         }
//     }

//     function getNextSqrtPriceFromInput(
//         uint160 sqrtPriceX96,
//         uint128 liquidity,
//         uint256 amountIn,
//         bool zeroForOne
//     ) public pure returns (uint160 sqrtPriceNextX96) {
//         sqrtPriceNextX96 = zeroForOne
//             ? getNextSqrtPriceFromAmount0RoundingUp(
//                 sqrtPriceX96,
//                 liquidity,
//                 amountIn
//             )
//             : getNextSqrtPriceFromAmount1RoundingDown(
//                 sqrtPriceX96,
//                 liquidity,
//                 amountIn
//             );
//     }

//     function getNextSqrtPriceFromAmount0RoundingUp(
//         uint160 sqrtPriceX96,
//         uint128 liquidity,
//         uint256 amountIn
//     ) internal pure returns (uint160) {
//         uint256 numerator = uint256(liquidity) << FixedPoint96.RESOLUTION;
//         uint256 product = amountIn * sqrtPriceX96;

//         if (product / amountIn == sqrtPriceX96) {
//             uint256 denominator = numerator + product;
//             if (denominator >= numerator) {
//                 return
//                     uint160(
//                         mulDivRoundingUp(numerator, sqrtPriceX96, denominator)
//                     );
//             }
//         }

//         return
//             uint160(
//                 divRoundingUp(numerator, (numerator / sqrtPriceX96) + amountIn)
//             );
//     }

//     function getNextSqrtPriceFromAmount1RoundingDown(
//         uint160 sqrtPriceX96,
//         uint128 liquidity,
//         uint256 amountIn
//     ) internal pure returns (uint160) {
//         return
//             sqrtPriceX96 +
//             uint160((amountIn << FixedPoint96.RESOLUTION) / liquidity);
//     }
// }
