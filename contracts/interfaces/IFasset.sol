// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IFasset {
    function mintMulti(
        address[] calldata _inputs,
        uint256[] calldata _inputQuantities,
        uint256 _minOutputQuantity,
        address _recipient
    ) external returns (uint256 mintOutput);
}
