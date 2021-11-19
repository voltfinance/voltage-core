// SPDX-License-Identifier: GPL-3.0

pragma solidity =0.6.12;

import "./libraries/FuseFiLibrary.sol";
import "./libraries/SafeMath.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IFuseFiRouter02.sol";
import "./interfaces/IFuseFiFactory.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWFUSE.sol";

contract FuseFiRouter02 is IFuseFiRouter02 {
    using SafeMathFuseFi for uint256;

    address public immutable override factory;
    address public immutable override WFUSE;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "FuseFiRouter: EXPIRED");
        _;
    }

    constructor(address _factory, address _WFUSE) public {
        factory = _factory;
        WFUSE = _WFUSE;
    }

    receive() external payable {
        assert(msg.sender == WFUSE); // only accept AVAX via fallback from the WAVAX contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IFuseFiFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IFuseFiFactory(factory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = FuseFiLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = FuseFiLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "FuseFiRouter: INSUFFICIENT_B_AMOUNT");
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = FuseFiLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, "FuseFiRouter: INSUFFICIENT_A_AMOUNT");
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = FuseFiLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IFuseFiPair(pair).mint(to);
    }

    function addLiquidityFUSE(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountFUSEMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountFUSE,
            uint256 liquidity
        )
    {
        (amountToken, amountFUSE) = _addLiquidity(
            token,
            WFUSE,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountFUSEMin
        );
        address pair = FuseFiLibrary.pairFor(factory, token, WFUSE);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWFUSE(WFUSE).deposit{value: amountFUSE}();
        assert(IWFUSE(WFUSE).transfer(pair, amountFUSE));
        liquidity = IFuseFiPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountFUSE) TransferHelper.safeTransferFUSE(msg.sender, msg.value - amountFUSE);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = FuseFiLibrary.pairFor(factory, tokenA, tokenB);
        IFuseFiPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IFuseFiPair(pair).burn(to);
        (address token0, ) = FuseFiLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, "FuseFiRouter: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "FuseFiRouter: INSUFFICIENT_B_AMOUNT");
    }

    function removeLiquidityFUSE(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountFUSEMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountFUSE) {
        (amountToken, amountFUSE) = removeLiquidity(
            token,
            WFUSE,
            liquidity,
            amountTokenMin,
            amountFUSEMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWFUSE(WFUSE).withdraw(amountFUSE);
        TransferHelper.safeTransferFUSE(to, amountFUSE);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        address pair = FuseFiLibrary.pairFor(factory, tokenA, tokenB);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IFuseFiPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }

    function removeLiquidityFUSEWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountFUSEMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountFUSE) {
        address pair = FuseFiLibrary.pairFor(factory, token, WFUSE);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IFuseFiPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountFUSE) = removeLiquidityFUSE(token, liquidity, amountTokenMin, amountFUSEMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityFUSESupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountFUSEMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountFUSE) {
        (, amountFUSE) = removeLiquidity(
            token,
            WFUSE,
            liquidity,
            amountTokenMin,
            amountFUSEMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20FuseFi(token).balanceOf(address(this)));
        IWFUSE(WFUSE).withdraw(amountFUSE);
        TransferHelper.safeTransferFUSE(to, amountFUSE);
    }

    function removeLiquidityFUSEWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountFUSEMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external virtual override returns (uint256 amountFUSE) {
        address pair = FuseFiLibrary.pairFor(factory, token, WFUSE);
        uint256 value = approveMax ? uint256(-1) : liquidity;
        IFuseFiPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountFUSE = removeLiquidityFUSESupportingFeeOnTransferTokens(
            token,
            liquidity,
            amountTokenMin,
            amountFUSEMin,
            to,
            deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = FuseFiLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2 ? FuseFiLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IFuseFiPair(FuseFiLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = FuseFiLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "FuseFiRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, FuseFiLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        amounts = FuseFiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "FuseFiRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, FuseFiLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactFUSEForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WFUSE, "FuseFiRouter: INVALID_PATH");
        amounts = FuseFiLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "FuseFiRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWFUSE(WFUSE).deposit{value: amounts[0]}();
        assert(IWFUSE(WFUSE).transfer(FuseFiLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactFUSE(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WFUSE, "FuseFiRouter: INVALID_PATH");
        amounts = FuseFiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, "FuseFiRouter: EXCESSIVE_INPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, FuseFiLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWFUSE(WFUSE).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferFUSE(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForFUSE(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WFUSE, "FuseFiRouter: INVALID_PATH");
        amounts = FuseFiLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, "FuseFiRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        TransferHelper.safeTransferFrom(path[0], msg.sender, FuseFiLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWFUSE(WFUSE).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferFUSE(to, amounts[amounts.length - 1]);
    }

    function swapFUSEForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WFUSE, "FuseFiRouter: INVALID_PATH");
        amounts = FuseFiLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, "FuseFiRouter: EXCESSIVE_INPUT_AMOUNT");
        IWFUSE(WFUSE).deposit{value: amounts[0]}();
        assert(IWFUSE(WFUSE).transfer(FuseFiLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferFUSE(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = FuseFiLibrary.sortTokens(input, output);
            IFuseFiPair pair = IFuseFiPair(FuseFiLibrary.pairFor(factory, input, output));
            uint256 amountInput;
            uint256 amountOutput;
            {
                // scope to avoid stack too deep errors
                (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
                (uint256 reserveInput, uint256 reserveOutput) = input == token0
                    ? (reserve0, reserve1)
                    : (reserve1, reserve0);
                amountInput = IERC20FuseFi(input).balanceOf(address(pair)).sub(reserveInput);
                amountOutput = FuseFiLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOutput)
                : (amountOutput, uint256(0));
            address to = i < path.length - 2 ? FuseFiLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(path[0], msg.sender, FuseFiLibrary.pairFor(factory, path[0], path[1]), amountIn);
        uint256 balanceBefore = IERC20FuseFi(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20FuseFi(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            "FuseFiRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactFUSEForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable virtual override ensure(deadline) {
        require(path[0] == WFUSE, "FuseFiRouter: INVALID_PATH");
        uint256 amountIn = msg.value;
        IWFUSE(WFUSE).deposit{value: amountIn}();
        assert(IWFUSE(WFUSE).transfer(FuseFiLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint256 balanceBefore = IERC20FuseFi(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20FuseFi(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            "FuseFiRouter: INSUFFICIENT_OUTPUT_AMOUNT"
        );
    }

    function swapExactTokensForFUSESupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WFUSE, "FuseFiRouter: INVALID_PATH");
        TransferHelper.safeTransferFrom(path[0], msg.sender, FuseFiLibrary.pairFor(factory, path[0], path[1]), amountIn);
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint256 amountOut = IERC20FuseFi(WFUSE).balanceOf(address(this));
        require(amountOut >= amountOutMin, "FuseFiRouter: INSUFFICIENT_OUTPUT_AMOUNT");
        IWFUSE(WFUSE).withdraw(amountOut);
        TransferHelper.safeTransferFUSE(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure virtual override returns (uint256 amountB) {
        return FuseFiLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountOut) {
        return FuseFiLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) public pure virtual override returns (uint256 amountIn) {
        return FuseFiLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint256 amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return FuseFiLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint256 amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint256[] memory amounts)
    {
        return FuseFiLibrary.getAmountsIn(factory, amountOut, path);
    }
}
