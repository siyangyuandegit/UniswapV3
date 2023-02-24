// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "./attackTest.sol";

contract attack is Test{
    constructor(address addr){
        (bool success, bytes memory data) = addr.call((abi.encodeWithSignature("noContractAddress(uint256)", 500)));
        console2.log(success);
        console2.log(data.length);
    }
}

