// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IPegswap {
    function swap(uint256 sourceAmount, address source, address target) external;
}
