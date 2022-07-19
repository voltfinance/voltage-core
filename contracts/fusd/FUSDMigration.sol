// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IPegswap.sol";
import "../interfaces/IStablePool.sol";
import "../interfaces/IFasset.sol";

contract FUSDMigration {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public fusdV1;
    address public fusdV2;
    
    address public constant usdc = 0x620fd5fa44BE6af63715Ef4E65DDFA0387aD13F5;
    address public constant busd = 0x6a5F6A8121592BeCd6747a38d67451B310F7f156;
    address public constant usdt = 0xFaDbBF8Ce7D5b7041bE672561bbA99f79c532e10;
    IStablePool public stablePool = IStablePool(0x2a68D7C6Ea986fA06B2665d08b4D08F5e7aF960c);
    IPegswap public pegswap = IPegswap(0xdfE016328E7BcD6FA06614fE3AF3877E931F7e0a);

    constructor(
        address _fusdV1,
        address _fusdV2
    ) public {
        fusdV1 = _fusdV1;
        fusdV2 = _fusdV2;
    }

    function migrate(uint256 _amountIn) external {
        _migrate(_amountIn);
    }

    function outputAmount(uint256 _amountIn) public view returns (uint256) {

    }

    function _approveTokenIfNeeded(address token, address spender) private {
        if (IERC20(token).allowance(address(this), spender) == 0) {
            IERC20(token).safeApprove(spender, uint256(~0));
        }
    }

    function _burn(uint256 _amountIn) private {
        pegswap.swap(_amountIn, usdc, fusdV1);
    }

    function _mint() private {
        uint256 busdAmount = IERC20(busd).balanceOf(address(this));
        uint256 usdtAmount = IERC20(usdt).balanceOf(address(this));
        uint256 usdcAmount = IERC20(usdc).balanceOf(address(this));

        _approveTokenIfNeeded(usdc, fusdV2);
        _approveTokenIfNeeded(usdt, fusdV2);
        _approveTokenIfNeeded(busd, fusdV2);

        address[] memory inputs = new address[](3);
        inputs[0] = usdt;
        inputs[1] = busd;
        inputs[2] = usdc;

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = usdtAmount;
        amounts[1] = busdAmount;
        amounts[2] = usdcAmount; 

        IFasset(fusdV2).mintMulti(
            inputs,
            amounts,
            0,
            msg.sender
        );
    }

    function _swap(address _from, address _to, uint256 _amountIn) private {
        uint256 minAmountOut = stablePool.calculateSwap(
            stablePool.getTokenIndex(_from),
            stablePool.getTokenIndex(_to),
            _amountIn
        );

        stablePool.swap(
            stablePool.getTokenIndex(_from),
            stablePool.getTokenIndex(_to),
            _amountIn,
            minAmountOut,
            block.timestamp + 30000
        );
    }

    function _migrate(uint256 _amountIn) private {
        IERC20(fusdV1).safeTransferFrom(msg.sender, address(this), _amountIn);

        _burn(_amountIn);

        uint256 usdcAmount = IERC20(usdc).balanceOf(address(this));
        uint256 usdcPortionAmount = usdcAmount.mul(33).div(100);

        _approveTokenIfNeeded(usdc, address(stablePool));

        _swap(usdc, usdt, usdcPortionAmount);
        _swap(usdc, busd, usdcPortionAmount);

        _mint();
    }
}