// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IBar.sol";
import "./interfaces/IERC20.sol";

interface IMasterChef {
    function userInfo(uint256 pid, address owner) external view returns (uint256, uint256);
}

contract VoltVote {
    using SafeMath for uint256;

    IBar bar;
    IERC20 volt;
    IMasterChef chef;
    uint256 pid; // Pool ID of xVOLT in MasterChefV3

    function name() public pure returns(string memory) {
        return "VoltVote";
    }

    function symbol() public pure returns (string memory) {
        return "VOLTVOTE";
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    constructor(
        address _bar,
        address _volt,
        address _chef,
        uint256 _pid
    ) public {
        bar = IBar(_bar);
        volt = IERC20(_volt);
        chef = IMasterChef(_chef);
        pid = _pid;
    }

    function balanceOf(address owner) public view returns (uint256) {
        (uint256 xvoltStakedBalance, ) = chef.userInfo(pid, owner);
        uint256 xvoltStakedBalancePowah = xvoltStakedBalance.mul(150).div(100);

        uint256 xvoltBalance = bar.balanceOf(owner);
        uint256 xvoltBalancePowah = xvoltBalance.mul(2);

        uint256 voltBalance = volt.balanceOf(owner);

        return xvoltStakedBalancePowah.add(xvoltBalancePowah).add(voltBalance);
    }

    function allowance(address, address) public pure returns (uint256) {
        return 0;
    }

    function transfer(address, uint256) public pure returns (bool) {
        return false;
    }

    function approve(address, uint256) public pure returns (bool) {
        return false;
    }

    function transferFrom(
        address,
        address,
        uint256
    ) public pure returns (bool) {
        return false;
    }
}
