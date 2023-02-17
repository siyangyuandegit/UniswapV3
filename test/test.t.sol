// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "../src/lib/BitMath.sol";
import "forge-std/Test.sol";
import "../src/lib/tickBitmap.sol";

contract a is Test{
    using BitMath for uint256;

    using TickBitmap for mapping(int16 => uint256);

    mapping(int16 => uint256) public tickBitmap;

    function test_help () public {
        int24 tick = 2;
        // uint8 bitPos = 3;
        int16 wordPos = 0;
        uint256 word = 10;

        
        tickBitmap[wordPos] = word;
        (int24 next,) = tickBitmap.nextInitializedTickWithinOneWord(tick, 1, true);
        // console2.log(tickBitmap[3]);
        // console2.log(next);
    }
}