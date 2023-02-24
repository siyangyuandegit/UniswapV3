// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import "forge-std/Test.sol";


contract TestAttack is Test{
    using Address for address;

    uint256 public a = 1;
    function noContractAddress(uint256 x) public {
        bool nc = msg.sender.isContract();
        
        console2.log("msg.sender", msg.sender);
        console2.log("tx.origin: ", tx.origin);
        require(!nc, "contract account forbiden");
        a = x;
    }
}

