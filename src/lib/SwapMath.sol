// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;
import "./Math.sol";

library SwapMath {
    function computeSwapStep(
        uint160 sqrtPriceCurrentX96,
        uint160 sqrtPriceTargetX96,
        uint128 liquidity,
        uint256 amountRemaining,
        uint24 fee
    )
        internal
        pure
        returns (
            uint160 sqrtPriceNextX96,
            uint256 amountIn,
            uint256 amountOut,
            uint256 feeAmount
        )
    {
        bool zeroForOne = sqrtPriceCurrentX96 >= sqrtPriceTargetX96;
        // 计算扣除手续费的剩余代币,因为fee的基础单位是百万分之一
        // 所以用(100w - fee) / 100w就是剩余的代币量
        uint256 amountRemainingLessFee = mulDiv(
            amountRemaining,
            1e6 - fee,
            1e6
        );
        // 根据当前价格和目标价格计算出当前区间可提供的amountIn
        amountIn = zeroForOne
            ? Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity,
                true
            )
            : Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceTargetX96,
                liquidity,
                true
            );
        // 与remaining比较，判断当前区间是否能满足swap需求
        // 不能满足的话，下一个sqrtPrice就是当前区间的边界
        if (amountRemainingLessFee >= amountIn)
            sqrtPriceNextX96 = sqrtPriceTargetX96;
            // 能满足的话，下一个sqrtPrice就根据公式进行计算
        else {
            // 根据当前pool的流动性，当前价格，所要兑换的代币数量，计算出下一个价格
            sqrtPriceNextX96 = Math.getNextSqrtPriceFromInput(
                sqrtPriceCurrentX96,
                liquidity,
                amountRemainingLessFee,
                zeroForOne
            );
        }
        // 判断价格是否移动到激活tick区间的边界,如果没有，则说明有足够的流动性填满交易
        bool max = sqrtPriceNextX96 == sqrtPriceTargetX96;
        if (!max) {
            feeAmount = amountRemaining - amountIn;
        } else {
            // 这里是简化后的公式
            // 收取的总费用 total_fee = fee / 1e6 * amountRemaining
            // 假设没有完成全部交易，则收取的费用应为总费用的 amountIn / amountRemainingLessFee * total_fee
            // 简化后可得 fee = amoutIn * fee / 1e6 - fee
            feeAmount = Math.mulDivRoundingUp(amountIn, fee, 1e6 - fee);
        }

        if (zeroForOne) {
            amountIn = max
                ? amountIn
                : Math.calcAmount0Delta(
                    sqrtPriceCurrentX96,
                    sqrtPriceNextX96,
                    liquidity,
                    true
                );
            amountOut = Math.calcAmount1Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96,
                liquidity,
                false
            );
        } else {
            amountIn = max
                ? amountIn
                : Math.calcAmount1Delta(
                    sqrtPriceCurrentX96,
                    sqrtPriceNextX96,
                    liquidity,
                    true
                );
            amountOut = Math.calcAmount0Delta(
                sqrtPriceCurrentX96,
                sqrtPriceNextX96,
                liquidity,
                false
            );
        }

        if (!zeroForOne) {
            (amountIn, amountOut) = (amountOut, amountIn);
        }
    }
}
