// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library Position {
    struct Info {
        uint128 liquidity;
    }

    function _update(Info storage self, uint128 _liquidityDelta) internal {
        uint128 liquidityBefore = self.liquidity;
        uint128 liquidityAfter = liquidityBefore + _liquidityDelta;

        self.liquidity = liquidityAfter;
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
