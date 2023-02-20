// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "./BytesLib.sol";

library Path{

    using BytesLib for bytes;
    uint256 private constant ADDR_SIZE = 20;
    uint256 private constant TICKSPACING_SIZE = 3;
    // 到下一个地址的偏移量
    uint256 private constant NEXT_OFFSET = ADDR_SIZE + TICKSPACING_SIZE;
    // 一个池子的偏移量
    uint256 private constant POP_OFFSET = NEXT_OFFSET + ADDR_SIZE;
    // 多池子参数的最小长度
    uint256 private constant MULTIPLE_POOLS_MIN_LENGETH = POP_OFFSET + NEXT_OFFSET;

    // 计算池子的数量
    function numPools(bytes memory path) internal pure returns(uint256) {
        return (path.length - ADDR_SIZE) / NEXT_OFFSET;
    }

    // 判断某个路径是否有多个池子
    function hasMultiplePools(bytes memory path) internal pure returns(bool) {
        return path.length >= MULTIPLE_POOLS_MIN_LENGETH;
    }

    function getFirstPool(bytes memory path) internal pure returns(bytes memory){
        return path.slice(0, POP_OFFSET);
    }    

    // 跳过上一个处理过的池子(addr + tick)
    function skipToken(bytes memory path) internal pure returns(bytes memory){
        return path.slice(NEXT_OFFSET, path.length - NEXT_OFFSET);
    }

    // 解码池子的参数
    function decodeFirstPool(bytes memory path) internal pure returns(address tokenIn, address tokenOut, uint24 tickSpacing) {
        tokenIn = path.toAddress(0);
        tickSpacing = path.toUint24(ADDR_SIZE);
        tokenOut = path.toAddress(NEXT_OFFSET);
    }

}