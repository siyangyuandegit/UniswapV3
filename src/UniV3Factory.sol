// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./interfaces/IUniV3PoolDeployer.sol";
import "./UniV3Pool.sol";

contract UniV3Factory is IUniV3PoolDeployer {
    PoolParameters public parameters;
    mapping(address => mapping(address => mapping(uint24 => address)))
        public pools;
    mapping(uint24 => uint24) public fees;

    event PoolCreated(
        address indexed tokenA,
        address indexed tokenB,
        uint24 tickSpacing,
        address pool
    );

    constructor() {
        fees[500] = 10;
        fees[3000] = 60;
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) public returns (address pool) {
        require(tokenA != tokenB);
        require(fees[fee] != 0, "invalid fee");
        (tokenA, tokenB) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        require(tokenA != address(0), "invalid token address");
        require(
            pools[tokenA][tokenB][fee] == address(0),
            "exists pool"
        );

        parameters = PoolParameters({
            factory: address(this),
            token0: tokenA,
            token1: tokenB,
            tickSpacing: fees[fee],
            fee: fee
        });
        pool = address(
            new UniV3Pool{
                salt: keccak256(abi.encodePacked(tokenA, tokenB, fee))
            }()
        );
        delete parameters;

        pools[tokenA][tokenB][fee] = pool;
        pools[tokenB][tokenA][fee] = pool;

        emit PoolCreated(tokenA, tokenB, fee, pool);
    }
}
