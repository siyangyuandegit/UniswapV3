// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/attack.sol";
import "../src/attackTest.sol";
import "../test/ERC20Mintable.sol";

contract DeployDevelopment is Script {
    function setUp() public {}

    function run() public {

        vm.startBroadcast();
        TestAttack token1 = new TestAttack();
        attack token0 = new attack(address(token1));
        ERC20Mintable token = new ERC20Mintable("eth", "ether", 18);

        token.mint(address(this), 100000 ether);
        console.log("Attack address", address(token0));
        console.log("TestAttack address", address(token1));

        vm.stopBroadcast();

        //   WETH address 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
        //   USDC address 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
        //   Pool address 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
        //   Manager address 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
        //   address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        //   privateKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    }
}
