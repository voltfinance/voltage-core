// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import './uniswap/interfaces/IWETH.sol';
import './interfaces/IMasterChef.sol';
import "./boringcrypto/BoringOwnable.sol";

/**
 * @title PoolRewardDistributor
 * @notice Distribute rewards to pools
 */
contract PoolRewardDistributor is BoringOwnable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable masterChef;
    address public immutable WETH;

    constructor(address _masterChef, address _WETH) public {
        masterChef = _masterChef;
        WETH = _WETH;
    }

    function recoverFuse() public onlyOwner {
        uint256 fuseBalance = address(this).balance;
        address payable _owner = address(this);
        _owner.call{value: fuseBalance}("");
    }

    function recoverToken(address token) public onlyOwner {
        uint256 tokenBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner, tokenBalance);
    }

    function _distributeRewards(uint256 rewardAmount) internal {
        uint256 pools = IMasterChef(masterChef).poolLength();
        uint256 totalAllocPoints = IMasterChef(masterChef).totalAllocPoint();

        for (uint256 i = 0; i < pools; i++) {
            IMasterChef.PoolInfo memory pool = IMasterChef(masterChef).poolInfo(i);
            uint256 amount = (pool.allocPoint.div(totalAllocPoints)).mul(rewardAmount);
            
            if (address(pool.rewarder) != address(0) && amount > 0) {
                IWETH(WETH).transfer(address(pool.rewarder), amount);
            }
        }
    }

    receive() external payable {
        require(msg.sender == owner);

        IWETH(WETH).deposit{value: msg.value}();
        _distributeRewards(msg.value);
    }
}
