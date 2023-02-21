// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "../interfaces/IERC20Min.sol";

library TransferHelper{
    function safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(IERC20Minimal.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }
}