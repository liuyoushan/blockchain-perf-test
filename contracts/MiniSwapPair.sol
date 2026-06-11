// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20.sol";

contract MiniSwapPair is MyERC20("LPToken", "LPT") {
    address public token0;
    address public token1;

    uint112 private reserve0;
    uint112 private reserve1;

    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() {}

    function initialize(address _token0, address _token1) external {
        require(token0 == address(0), "already initialized");
        token0 = _token0;
        token1 = _token1;
    }

    function getReserves() public view returns (uint112, uint112) {
        return (reserve0, reserve1);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        uint256 balance0 = MyERC20(token0).balanceOf(address(this));
        uint256 balance1 = MyERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        if (totalSupply == 0) {
            liquidity = sqrt(amount0 * amount1);
        } else {
            liquidity = min((amount0 * totalSupply) / _reserve0, (amount1 * totalSupply) / _reserve1);
        }
        require(liquidity > 0, "insufficient liquidity minted");
        _mint(to, liquidity);
        _update(balance0, balance1);
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
        require(amount0Out > 0 || amount1Out > 0, "insufficient output amount");
        (uint112 _reserve0, uint112 _reserve1) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "insufficient liquidity");

        if (amount0Out > 0) MyERC20(token0).transfer(to, amount0Out);
        if (amount1Out > 0) MyERC20(token1).transfer(to, amount1Out);

        uint256 balance0 = MyERC20(token0).balanceOf(address(this));
        uint256 balance1 = MyERC20(token1).balanceOf(address(this));
        uint256 amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "insufficient input amount");

        uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
        uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
        require(balance0Adjusted * balance1Adjusted >= uint256(_reserve0) * _reserve1 * 1000**2, "K");

        _update(balance0, balance1);
    }

    function burn(address to) external returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = MyERC20(token0).balanceOf(address(this));
        uint256 balance1 = MyERC20(token1).balanceOf(address(this));
        uint256 liquidity = MyERC20(address(this)).balanceOf(address(this));

        amount0 = liquidity * balance0 / totalSupply;
        amount1 = liquidity * balance1 / totalSupply;
        require(amount0 > 0 && amount1 > 0, "insufficient liquidity burned");

        _burn(address(this), liquidity);
        MyERC20(token0).transfer(to, amount0);
        MyERC20(token1).transfer(to, amount1);

        _update(MyERC20(token0).balanceOf(address(this)), MyERC20(token1).balanceOf(address(this)));
    }

    function sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}