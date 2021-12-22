// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

// VoltBar is the coolest bar in town. You come in with some Volt, and leave with more! The longer you stay, the more Joe you get.
//
// This contract handles swapping to and from xVolt, FuseFi's staking token.
contract VoltBar is ERC20("VoltBar", "xVOLT") {
    using SafeMath for uint256;
    IERC20 public volt;

    // Define the Volt token contract
    constructor(IERC20 _volt) public {
        volt = _volt;
    }

    // Enter the bar. Pay some VOLTs. Earn some shares.
    // Locks Joe and mints xVolt
    function enter(uint256 _amount) public {
        // Gets the amount of Joe locked in the contract
        uint256 totalVolt = volt.balanceOf(address(this));
        // Gets the amount of xJoe in existence
        uint256 totalShares = totalSupply();
        // If no xJoe exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalVolt == 0) {
            _mint(msg.sender, _amount);
        }
        // Calculate and mint the amount of xJoe the Joe is worth. The ratio will change overtime, as xJoe is burned/minted and Joe deposited + gained from fees / withdrawn.
        else {
            uint256 what = _amount.mul(totalShares).div(totalVolt);
            _mint(msg.sender, what);
        }
        // Lock the Joe in the contract
        volt.transferFrom(msg.sender, address(this), _amount);
    }

    // Leave the bar. Claim back your VOLTs.
    // Unlocks the staked + gained Volt and burns xVolt
    function leave(uint256 _share) public {
        // Gets the amount of xVolt in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Volt the xVolt is worth
        uint256 what = _share.mul(volt.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        volt.transfer(msg.sender, what);
    }
}
