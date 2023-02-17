// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/solmate/src/tokens/ERC20.sol";
import "forge-std/Test.sol";


contract ERC20Mintable is ERC20, Test{
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol, _decimals){}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

}