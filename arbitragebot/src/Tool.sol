// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Tool {

    function convert_bytes32_2_uint(bytes32 input) external pure returns (uint256) {
        return uint(input);
    }

    function convert_bytes32_2_address(bytes32 input) external pure returns (address) {
        return address(uint160(uint256(input)));
    }

}
