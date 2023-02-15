// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./UniV3Pool.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract UniV3Manager {
    function mint(
        address _poolAdress,
        int24 tickLower,
        int24 tickUpper,
        uint128 liquidity,
        bytes calldata data
    ) public {
        UniV3Pool(_poolAdress).mint(
            msg.sender,
            tickLower,
            tickUpper,
            liquidity,
            data
        );
    }

    function swap(address _poolAddress, bytes calldata data) public {
        UniV3Pool(_poolAddress).swap(msg.sender, data);
    }

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

    function uniV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata data
    ) public {
        UniV3Pool.CallbackData memory extra = abi.decode(
            data,
            (UniV3Pool.CallbackData)
        );
        if (amount0 > 0){
            IERC20(extra.token0).transferFrom(extra.payer, msg.sender, uint256(amount0));
        }
        if (amount1 > 0){
            IERC20(extra.token1).transferFrom(extra.payer, msg.sender, uint256(amount1));
        }
    }
}
