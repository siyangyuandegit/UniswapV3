// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library Position {
    struct Info {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    function _update(Info storage self, uint128 _liquidityDelta) internal returns(uint128) {
        uint128 liquidityBefore = self.liquidity;
        uint128 liquidityAfter = liquidityBefore + _liquidityDelta;

        self.liquidity = liquidityAfter;
        return self.liquidity;
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
