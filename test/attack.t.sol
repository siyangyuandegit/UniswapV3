// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.13;

import "../src/attackTest.sol";
import "../src/attack.sol";
import "forge-std/Test.sol";

contract attackT is Test {
    TestAttack attack_;
    attack a;

    function setUp() public {
        attack_ = new TestAttack();
        vm.prank(address(2));
        a = new attack(address(attack_));
        console2.log("addresTestAttack: ", address(attack_));
        console2.log("addresAttack: ", address(a));
    }

    function testX() public {
        assertEq(attack_.a(), 500, "false call");
    }
}
