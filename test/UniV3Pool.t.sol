// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./ERC20Mintable.sol";
import "../src/UniV3Pool.sol";
import "../src/UniV3Factory.sol";
import "../src/interfaces/IUniV3Pool.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract UniV3PoolTest is Test {
    ERC20Mintable token0;
    ERC20Mintable token1;
    UniV3Pool pool;
    UniV3Factory factory;
    bool shouldTransferInCallback;

    struct TestCaseParams {
        uint256 wethBalance;
        uint256 usdcBalance;
        int24 currentTick;
        int24 lowerTick;
        int24 upperTick;
        uint128 liquidity;
        uint160 currentSqrtP;
        bool shouldTransferInCallback;
        bool mintLiqudity;
    }

    function setUp() public {
        token0 = new ERC20Mintable("Ether", "ETH", 18);
        token1 = new ERC20Mintable("USDC", "USDC", 18);
        factory = new UniV3Factory();
    }

    function testInitialize()public{
        pool = UniV3Pool(factory.createPool(address(token0), address(token1), 500));
    }
}