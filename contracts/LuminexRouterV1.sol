// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {ILuminexRouterV1} from './ILuminexRouterV1.sol';
import {IWROSE} from './IWROSE.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LuminexRouterV1 is ILuminexRouterV1 {
    address public immutable override factory;
    address public immutable override WROSE;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'LuminexRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WROSE) {
        factory = _factory;
        WROSE = _WROSE;
    }

    receive() external payable {
        assert(msg.sender == WROSE);
    }

    function precalculateAmounts(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) external view override returns (uint amountA, uint amountB) {
        return (0, 1);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = LuminexLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = ILuminexPair(pair).mint(to);
    }

    function addLiquidityROSE(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountROSEMin,
        address to,
        uint deadline
    ) external payable override ensure(deadline) returns (uint amountToken, uint amountROSE, uint liquidity) {
        (amountToken, amountROSE) = _addLiquidity(token, WROSE, amountTokenDesired, msg.value, amountTokenMin, amountROSEMin);
        address pair = LuminexLibrary.pairFor(factory, token, WROSE);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWROSE(WROSE).deposit{value: amountROSE}();
        assert(IWROSE(WROSE).transfer(pair, amountROSE));
        liquidity = ILuminexPair(pair).mint(to);
        if (msg.value > amountROSE) TransferHelper.safeTransferROSE(msg.sender, msg.value - amountROSE);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = LuminexLibrary.pairFor(factory, tokenA, tokenB);
        ILuminexPair(pair).transferFrom(msg.sender, pair, liquidity);
        (uint amount0, uint amount1) = ILuminexPair(pair).burn(to);
        (address token0,) = LuminexLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'LuminexRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'LuminexRouter: INSUFFICIENT_B_AMOUNT');
    }

    function removeLiquidityROSE(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountROSEMin,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountToken, uint amountROSE) {
        (amountToken, amountROSE) = removeLiquidity(token, WROSE, liquidity, amountTokenMin, amountROSEMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, amountToken);
        IWROSE(WROSE).withdraw(amountROSE);
        TransferHelper.safeTransferROSE(to, amountROSE);
    }

    function removeLiquidityROSESupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountROSEMin,
        address to,
        uint deadline
    ) public override ensure(deadline) returns (uint amountROSE) {
        (, amountROSE) = removeLiquidity(token, WROSE, liquidity, amountTokenMin, amountROSEMin, address(this), deadline);
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWROSE(WROSE).withdraw(amountROSE);
        TransferHelper.safeTransferROSE(to, amountROSE);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        amounts = LuminexLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'LuminexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, LuminexLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) returns (uint[] memory amounts) {
        amounts = LuminexLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'LuminexRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, LuminexLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, to);
    }

    function swapExactROSEForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WROSE, 'LuminexRouter: INVALID_PATH');
        amounts = LuminexLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'LuminexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWROSE(WROSE).deposit{value: amounts[0]}();
        assert(IWROSE(WROSE).transfer(LuminexLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactROSE(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WROSE, 'LuminexRouter: INVALID_PATH');
        amounts = LuminexLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'LuminexRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, LuminexLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWROSE(WROSE).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferROSE(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForROSE(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WROSE, 'LuminexRouter: INVALID_PATH');
        amounts = LuminexLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'LuminexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(path[0], msg.sender, LuminexLibrary.pairFor(factory, path[0], path[1]), amounts[0]);
        _swap(amounts, path, address(this));
        IWROSE(WROSE).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferROSE(to, amounts[amounts.length - 1]);
    }

    function swapROSEForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WROSE, 'LuminexRouter: INVALID_PATH');
        amounts = LuminexLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'LuminexRouter: EXCESSIVE_INPUT_AMOUNT');
        IWROSE(WROSE).deposit{value: amounts[0]}();
        assert(IWROSE(WROSE).transfer(LuminexLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        if (msg.value > amounts[0]) TransferHelper.safeTransferROSE(msg.sender, msg.value - amounts[0]);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) {
        TransferHelper.safeTransferFrom(path[0], msg.sender, LuminexLibrary.pairFor(factory, path[0], path[1]), amountIn);
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin, 'LuminexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
    }

    function swapExactROSEForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable override ensure(deadline) {
        require(path[0] == WROSE, 'LuminexRouter: INVALID_PATH');
        uint amountIn = msg.value;
        IWROSE(WROSE).deposit{value: amountIn}();
        assert(IWROSE(WROSE).transfer(LuminexLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin, 'LuminexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
    }

    function swapExactTokensForROSESupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external override ensure(deadline) {
        require(path[path.length - 1] == WROSE, 'LuminexRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(path[0], msg.sender, LuminexLibrary.pairFor(factory, path[0], path[1]), amountIn);
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WROSE).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'LuminexRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWROSE(WROSE).withdraw(amountOut);
        TransferHelper.safeTransferROSE(to, amountOut);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) public pure override returns (uint amountB) {
        return LuminexLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure override returns (uint amountOut) {
        return LuminexLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) public pure override returns (uint amountIn) {
        return LuminexLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path) public view override returns (uint[] memory amounts) {
        return LuminexLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path) public view override returns (uint[] memory amounts) {
        return LuminexLibrary.getAmountsIn(factory, amountOut, path);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        if (ILuminexFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            ILuminexFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = LuminexLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = LuminexLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'LuminexRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = LuminexLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'LuminexRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = LuminexLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? LuminexLibrary.pairFor(factory, output, path[i + 2]) : _to;
            ILuminexPair(LuminexLibrary.pairFor(factory, input, output)).swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = LuminexLibrary.sortTokens(input, output);
            ILuminexPair pair = ILuminexPair(LuminexLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            {
                (uint reserve0, uint reserve1,) = pair.getReserves();
                (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
                amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
                amountOutput = LuminexLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? LuminexLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }
}

interface ILuminexFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface ILuminexPair {
    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

library LuminexLibrary {
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'LuminexLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'LuminexLibrary: ZERO_ADDRESS');
    }

    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f'
            )))));
    }

    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = ILuminexPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'LuminexLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'LuminexLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'LuminexLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'LuminexLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'LuminexLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'LuminexLibrary: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn * amountOut * 1000;
        uint denominator = (reserveOut - amountOut) * 997;
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'LuminexLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'LuminexLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

library TransferHelper {
    function safeTransfer(address token, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferROSE(address to, uint value) internal {
        (bool success,) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper: ROSE_TRANSFER_FAILED');
    }
}