// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./LiquidityMath.sol";

library Tick {
    struct Info {
        bool initialized;
        // total liquidity at tick
        uint128 liquidityGross;
        // amount of liquidity added or subtracted when tick is crossed
        int128 liquidityNet;
        uint256 feeGrowthOutside0X128;
        uint256 feeGrowthOutside1X128;
    }

    // upper true更新tickUpper，false更新tickLower
    function _update(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        int24 currentTick,
        int128 liquidityDelta,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128,
        bool upper
    ) internal returns (bool flipped) {
        Tick.Info storage tickInfo = self[tick];
        uint128 liquidityBefore = tickInfo.liquidityGross;
        uint128 liquidityAfter = LiquidityMath.addLiquidity(
            liquidityBefore,
            liquidityDelta
        );

        if (liquidityBefore == 0) {
            tickInfo.initialized = true;
        }
        if (liquidityBefore == 0) {
            if (tick <= currentTick) {
                tickInfo.feeGrowthOutside0X128 = feeGrowthGlobal0X128;
                tickInfo.feeGrowthOutside1X128 = feeGrowthGlobal1X128;
            }
            tickInfo.initialized = true;
        }

        tickInfo.liquidityGross = liquidityAfter;
        flipped = (liquidityAfter == 0) != (liquidityBefore == 0);
        // 当前tick若作为区间的上限时，需要减去流动性，下限加
        tickInfo.liquidityNet = upper
            ? int128(int256(tickInfo.liquidityNet) - liquidityDelta)
            : int128(int256(tickInfo.liquidityNet) + liquidityDelta);
    }

    function cross(
        mapping(int24 => Tick.Info) storage self,
        int24 tick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    ) internal returns (int128 liquidityDelta) {
        Tick.Info storage info = self[tick];
        // 如果tick被超越将tick上记录的手续费反转记录另一侧的手续费，也就是F_g - F_o
        info.feeGrowthOutside0X128 =
            feeGrowthGlobal0X128 -
            info.feeGrowthOutside0X128;
        info.feeGrowthOutside1X128 =
            feeGrowthGlobal1X128 -
            info.feeGrowthOutside1X128;
        liquidityDelta = info.liquidityNet;
    }

    // 计算两个tick中间的手续费即position所积累的手续费
    function getFeeGrowthInside(
        mapping(int24 => Tick.Info) storage self,
        int24 lowerTick_,
        int24 upperTick_,
        int24 currentTick,
        uint256 feeGrowthGlobal0X128,
        uint256 feeGrowthGlobal1X128
    )
        internal
        view
        returns (uint256 feeGrowthInside0X128, uint256 feeGrowthInside1X128)
    {
        Tick.Info storage lowerTick = self[lowerTick_];
        Tick.Info storage upperTick = self[upperTick_];

        // 计算tick左侧的手续费
        uint256 feeGrowthBelow0X128;
        uint256 feeGrowthBelow1X128;
        if (currentTick >= lowerTick_) {
            // ?
            feeGrowthBelow0X128 = lowerTick.feeGrowthOutside0X128;
            feeGrowthBelow1X128 = upperTick.feeGrowthOutside1X128;
        } else {
            feeGrowthBelow0X128 =
                feeGrowthGlobal0X128 -
                lowerTick.feeGrowthOutside0X128;
            feeGrowthBelow1X128 =
                feeGrowthGlobal1X128 -
                lowerTick.feeGrowthOutside1X128;
        }

        // 计算tick右侧的手续费
        uint256 feeGrowthAbove0X128;
        uint256 feeGrowthAbove1X128;
        if(currentTick < upperTick_){
            feeGrowthAbove0X128 = upperTick.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = upperTick.feeGrowthOutside1X128;
        }else{
            feeGrowthAbove0X128 = feeGrowthGlobal0X128 - upperTick.feeGrowthOutside0X128;
            feeGrowthAbove1X128 = feeGrowthGlobal1X128 - upperTick.feeGrowthOutside1X128;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0X128 - feeGrowthAbove0X128 - feeGrowthBelow0X128;
        feeGrowthInside1X128 = feeGrowthGlobal1X128 - feeGrowthAbove1X128 - feeGrowthBelow1X128;
    }
}
