// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "prb-math/Core.sol";
import "./FixedPoint128.sol";
import "./LiquidityMath.sol";

library Position {
    struct Info {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function _update(
        Info storage self,
        int128 _liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        // 通过手续费(这里手续费记录的是总手续费/总流动性得出的)和position的流动性计算未领取的代币数量
        uint128 tokensOwed0 = uint128(
            mulDiv(
                feeGrowthInside0X128 - self.feeGrowthInside0LastX128,
                self.liquidity,
                FixedPoint128.Q128
            )
        );
        uint128 tokensOwed1 = uint128(
            mulDiv(
                feeGrowthInside1X128 - self.feeGrowthInside1LastX128,
                self.liquidity,
                FixedPoint128.Q128
            )
        );
        // 更新position中的last fee
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128;
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128;

        self.liquidity = LiquidityMath.addLiquidity(
            self.liquidity,
            _liquidityDelta
        );
        // 源码这里写的可以接受溢出，但在达到uint128的最大值之前必须withdraw，暂时不清楚为什么
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            self.tokensOwed0 += tokensOwed0;
            self.tokensOwed1 += tokensOwed1;
        }
    }

    function get(
        mapping(bytes32 => Info) storage self,
        address _owner,
        int24 _tickLower,
        int24 _tickUpper
    ) internal view returns (Position.Info storage position) {
        position = self[
            keccak256(abi.encodePacked(_owner, _tickLower, _tickUpper))
        ];
    }
}
