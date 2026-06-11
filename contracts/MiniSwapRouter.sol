// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20.sol";
import "./MiniSwapFactory.sol";

contract MiniSwapRouter {
    address public immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        address to
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        address pair = MiniSwapFactory(factory).getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = MiniSwapFactory(factory).createPair(tokenA, tokenB);
        }
        (amountA, amountB) = (amountADesired, amountBDesired);
        MyERC20(tokenA).transferFrom(msg.sender, pair, amountA);
        MyERC20(tokenB).transferFrom(msg.sender, pair, amountB);
        liquidity = MiniSwapPair(pair).mint(to);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external {
        MyERC20(path[0]).transferFrom(msg.sender, MiniSwapFactory(factory).getPair(path[0], path[1]), amountIn);
        uint256 amountOut = getAmountOut(amountIn, path[0], path[1]);
        require(amountOut >= amountOutMin, "insufficient output amount");
        (uint256 amount0Out, uint256 amount1Out) = path[0] < path[1] ? (uint256(0), amountOut) : (amountOut, uint256(0));
        MiniSwapPair(MiniSwapFactory(factory).getPair(path[0], path[1])).swap(amount0Out, amount1Out, to);
    }

    function getAmountOut(uint256 amountIn, address tokenA, address tokenB) public view returns (uint256) {
        address pair = MiniSwapFactory(factory).getPair(tokenA, tokenB);
        (uint112 reserve0, uint112 reserve1) = MiniSwapPair(pair).getReserves();
        (uint112 reserveIn, uint112 reserveOut) = tokenA < tokenB ? (reserve0, reserve1) : (reserve1, reserve0);
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        return numerator / denominator;
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        address to
    ) external returns (uint256 amountA, uint256 amountB) {
        address pair = MiniSwapFactory(factory).getPair(tokenA, tokenB);
        require(pair != address(0), "pair does not exist");

        MiniSwapPair(pair).transferFrom(msg.sender, pair, liquidity);
        (uint256 amount0, uint256 amount1) = MiniSwapPair(pair).burn(to);
        (amountA, amountB) = tokenA < tokenB ? (amount0, amount1) : (amount1, amount0);
    }
}