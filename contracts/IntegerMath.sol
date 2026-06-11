// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IntegerMath - 整数运算安全测试合约
 * @dev 用于测试 Solidity 0.8+ 的内置溢出检查机制
 */
contract IntegerMath {
    // 存储值用于测试
    uint256 public storedValue;
    int256 public storedIntValue;

    event ValueSet(uint256 indexed value);
    event IntValueSet(int256 indexed value);
    event OperationResult(bool success, uint256 result);
    event IntOperationResult(bool success, int256 result);

    /**
     * @dev 测试无符号整数加法（可能溢出）
     */
    function add(uint256 a, uint256 b) external pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev 测试无符号整数减法（可能下溢）
     */
    function subtract(uint256 a, uint256 b) external pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev 测试无符号整数乘法（可能溢出）
     */
    function multiply(uint256 a, uint256 b) external pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev 测试无符号整数除法（除以零）
     */
    function divide(uint256 a, uint256 b) external pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev 测试有符号整数加法（可能溢出）
     */
    function addInt(int256 a, int256 b) external pure returns (int256) {
        return a + b;
    }

    /**
     * @dev 测试有符号整数减法（可能下溢）
     */
    function subtractInt(int256 a, int256 b) external pure returns (int256) {
        return a - b;
    }

    /**
     * @dev 安全加法（使用 checked 运算）
     */
    function safeAdd(uint256 a, uint256 b) external pure returns (uint256) {
        unchecked {
            uint256 result = a + b;
            require(result >= a, "SafeMath: addition overflow");
            return result;
        }
    }

    /**
     * @dev 安全减法（使用 checked 运算）
     */
    function safeSub(uint256 a, uint256 b) external pure returns (uint256) {
        unchecked {
            require(b <= a, "SafeMath: subtraction overflow");
            return a - b;
        }
    }

    /**
     * @dev 安全乘法（使用 checked 运算）
     */
    function safeMul(uint256 a, uint256 b) external pure returns (uint256) {
        unchecked {
            if (a == 0) return 0;
            uint256 result = a * b;
            require(result / a == b, "SafeMath: multiplication overflow");
            return result;
        }
    }

    /**
     * @dev 测试存储溢出
     */
    function setMaxValue() external {
        storedValue = type(uint256).max;
        emit ValueSet(storedValue);
    }

    /**
     * @dev 测试存储最小有符号值
     */
    function setMinIntValue() external {
        storedIntValue = type(int256).min;
        emit IntValueSet(storedIntValue);
    }

    /**
     * @dev 测试零值边界
     */
    function testZeroBoundary(uint256 value) external pure returns (bool) {
        return value == 0;
    }

    /**
     * @dev 测试极值递增
     */
    function incrementMax() external pure returns (uint256) {
        uint256 max = type(uint256).max;
        return max + 1; // 这会导致溢出
    }

    /**
     * @dev 测试极值递减
     */
    function decrementZero() external pure returns (uint256) {
        uint256 zero = 0;
        return zero - 1; // 这会导致下溢
    }
}