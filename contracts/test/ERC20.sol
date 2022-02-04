pragma solidity =0.5.16;

import '../VoltageERC20.sol';

contract ERC20 is VoltageERC20 {
    constructor(uint _totalSupply) public {
        _mint(msg.sender, _totalSupply);
    }
}
