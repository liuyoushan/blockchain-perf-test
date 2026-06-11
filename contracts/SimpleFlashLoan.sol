// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20.sol";

/**
 * @title SimpleFlashLoan
 * @dev 闪电贷合约 - 用于测试闪电贷攻击
 * @notice 实现标准的闪电贷模式：在同一笔交易中借出、归还
 */
contract SimpleFlashLoan {
    MyERC20 public token;
    address public owner;

    event FlashLoanInitiated(address borrower, uint256 amount);
    event FlashLoanExecuted(address borrower, bool success, bytes result);
    event FlashLoanRepaid(address borrower, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(MyERC20 _token) {
        token = _token;
        owner = msg.sender;
    }

    /**
     * @dev 获取闪电贷合约的代币余额
     */
    function getContractBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev 提取代币到所有者
     */
    function withdrawTokens() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(owner, balance), "Transfer failed");
    }

    /**
     * @dev 执行闪电贷
     * @param borrower 借用者地址
     * @param amount 借用金额
     * @param data 传递给借用者的数据（用于回调）
     * @notice 闪电贷的核心：在同一笔交易中完成借出和归还
     */
    function executeFlashLoan(
        address borrower,
        uint256 amount,
        bytes calldata data
    ) external onlyOwner {
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance");

        emit FlashLoanInitiated(borrower, amount);

        // 1. 将代币借给攻击者
        require(token.transfer(borrower, amount), "Loan transfer failed");

        // 2. 调用攻击者的回调函数（攻击逻辑）
        bool success;
        bytes memory result;
        (success, result) = borrower.call(data);

        emit FlashLoanExecuted(borrower, success, result);

        // 3. 验证代币是否已归还（闪电贷核心原则）
        require(
            token.balanceOf(address(this)) >= amount,
            "Flash loan not repaid"
        );

        emit FlashLoanRepaid(borrower, amount);
    }

    /**
     * @dev 简化版本：直接借给调用者，调用者在回调中完成攻击逻辑
     * @param amount 借用金额
     * @param callbackData 回调数据
     */
    function flashLoan(address receiver, uint256 amount, bytes calldata callbackData)
        external
        onlyOwner
        returns (bool)
    {
        require(token.balanceOf(address(this)) >= amount, "Insufficient balance for flash loan");

        // 1. 先把代币转给接收者
        token.transfer(receiver, amount);

        // 2. 调用接收者的回调函数（用于执行攻击逻辑）
        (bool success, ) = receiver.call(callbackData);

        // 3. 验证归还
        require(
            token.balanceOf(address(this)) >= amount,
            "Flash loan not repaid - attack failed"
        );

        return success;
    }
}

/**
 * @title FlashLoanAttacker
 * @dev 闪电贷攻击者合约 - 模拟真实闪电贷攻击
 * @notice 实现完整的闪电贷攻击流程
 */
contract FlashLoanAttacker {
    SimpleFlashLoan public flashLoanContract;
    MyERC20 public targetToken;
    address public owner;

    uint256 public attackCount;
    bool public attackSuccess;
    uint256 public profit;

    event AttackAttempt(uint256 count, bool success);

    constructor() {
        owner = msg.sender;
        attackCount = 0;
        attackSuccess = false;
        profit = 0;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function setFlashLoanContract(SimpleFlashLoan _contract) external onlyOwner {
        flashLoanContract = _contract;
    }

    function setTargetToken(MyERC20 _token) external onlyOwner {
        targetToken = _token;
    }

    /**
     * @dev 提取攻击获利
     */
    function withdrawProfit() external onlyOwner {
        uint256 balance = targetToken.balanceOf(address(this));
        if (balance > 0) {
            targetToken.transfer(owner, balance);
        }
    }

    /**
     * @dev 攻击回调函数 - 闪电贷会调用此函数
     * @notice 完整的闪电贷攻击流程在这里执行
     */
    function onFlashLoanReceived() external returns (bytes32) {
        attackCount++;
        emit AttackAttempt(attackCount, true);

        // 攻击者在这里执行恶意逻辑
        // 1. 价格操纵（在这个简化版本中，我们跳过价格操纵，直接尝试清算）
        // 2. 清算目标仓位
        // 3. 获取清算奖励

        return keccak256("FlashLoanReceiver.onFlashLoanReceived");
    }

    /**
     * @dev 获取攻击结果
     */
    function getAttackResult() external view returns (bool, uint256) {
        return (attackSuccess, attackCount);
    }

    /**
     * @dev 获取合约余额
     */
    function getBalance() external view returns (uint256) {
        return targetToken.balanceOf(address(this));
    }
}