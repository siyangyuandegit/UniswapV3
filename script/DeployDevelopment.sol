// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../test/ERC20Mintable.sol";
import "../src/UniV3Pool.sol";
import "../src/UniV3Manager.sol";

contract DeployDevelopment is Script {
    function setUp() public {}

    function run() public {
        uint256 wethBalance = 10 ether;
        uint256 usdcBalance = 10000 ether;
        int24 currentTick = 85176;
        uint160 currentSqrtP = 5602277097478614198912276234240;
        vm.startBroadcast();
        ERC20Mintable token0 = new ERC20Mintable("Wrapped Ether", "WETH", 18);
        ERC20Mintable token1 = new ERC20Mintable("USD Coin", "USDC", 18);

        UniV3Pool pool = new UniV3Pool(
            address(token0),
            address(token1),
            currentSqrtP,
            currentTick
        );

        UniV3Manager manager = new UniV3Manager();

        token0.mint(msg.sender, wethBalance);
        token1.mint(msg.sender, usdcBalance);
        console.log("WETH address", address(token0));
        console.log("USDC address", address(token1));
        console.log("Pool address", address(pool));
        console.log("Manager address", address(manager));
        vm.stopBroadcast();

        //   WETH address 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
        //   USDC address 0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0
        //   Pool address 0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9
        //   Manager address 0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9
        //   address: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
        //   privateKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    }
}
