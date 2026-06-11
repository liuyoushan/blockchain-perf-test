// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title TimeLockContract
 * @dev 时间锁/区块锁控制合约，用于测试限时功能
 */
contract TimeLockContract {
    // 时间锁相关变量
    uint256 public lockDuration;      // 时间锁时长（秒）
    uint256 public lockBlocks;        // 区块锁数量
    uint256 public startTime;         // 锁定开始时间
    uint256 public startBlock;        // 锁定开始区块

    // 用户锁定记录
    struct LockRecord {
        uint256 amount;               // 锁定金额
        uint256 lockTime;             // 锁定时间
        uint256 lockBlock;            // 锁定区块
        bool isReleased;              // 是否已释放
    }

    mapping(address => LockRecord) public userLocks;

    // 事件
    event Locked(address indexed user, uint256 amount, uint256 lockTime, uint256 lockBlock);
    event Released(address indexed user, uint256 amount, uint256 releaseTime);
    event LockDurationUpdated(uint256 newDuration);
    event LockBlocksUpdated(uint256 newBlocks);

    // 构造函数
    constructor(uint256 _lockDuration, uint256 _lockBlocks) {
        lockDuration = _lockDuration;   // 默认86400秒（1天）
        lockBlocks = _lockBlocks;       // 默认100个区块
        startTime = block.timestamp;
        startBlock = block.number;
    }

    /**
     * @dev 用户锁定资金
     * @param amount 锁定金额
     */
    function lock(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(userLocks[msg.sender].amount == 0, "Already locked");

        userLocks[msg.sender] = LockRecord({
            amount: amount,
            lockTime: block.timestamp,
            lockBlock: block.number,
            isReleased: false
        });

        emit Locked(msg.sender, amount, block.timestamp, block.number);
    }

    /**
     * @dev 释放锁定资金（时间锁）
     */
    function releaseByTime() external {
        LockRecord storage record = userLocks[msg.sender];
        
        require(record.amount > 0, "No locked funds");
        require(!record.isReleased, "Already released");
        require(block.timestamp >= record.lockTime + lockDuration, "Time lock not expired");

        record.isReleased = true;
        emit Released(msg.sender, record.amount, block.timestamp);
    }

    /**
     * @dev 释放锁定资金（区块锁）
     */
    function releaseByBlock() external {
        LockRecord storage record = userLocks[msg.sender];
        
        require(record.amount > 0, "No locked funds");
        require(!record.isReleased, "Already released");
        require(block.number >= record.lockBlock + lockBlocks, "Block lock not expired");

        record.isReleased = true;
        emit Released(msg.sender, record.amount, block.timestamp);
    }

    /**
     * @dev 检查时间锁是否到期
     * @param user 用户地址
     */
    function isTimeLockExpired(address user) external view returns (bool) {
        LockRecord storage record = userLocks[user];
        return block.timestamp >= record.lockTime + lockDuration;
    }

    /**
     * @dev 检查区块锁是否到期
     * @param user 用户地址
     */
    function isBlockLockExpired(address user) external view returns (bool) {
        LockRecord storage record = userLocks[user];
        return block.number >= record.lockBlock + lockBlocks;
    }

    /**
     * @dev 获取剩余时间（秒）
     * @param user 用户地址
     */
    function getRemainingTime(address user) external view returns (uint256) {
        LockRecord storage record = userLocks[user];
        if (block.timestamp >= record.lockTime + lockDuration) {
            return 0;
        }
        return (record.lockTime + lockDuration) - block.timestamp;
    }

    /**
     * @dev 获取剩余区块数
     * @param user 用户地址
     */
    function getRemainingBlocks(address user) external view returns (uint256) {
        LockRecord storage record = userLocks[user];
        if (block.number >= record.lockBlock + lockBlocks) {
            return 0;
        }
        return (record.lockBlock + lockBlocks) - block.number;
    }

    /**
     * @dev 更新时间锁时长（仅用于测试）
     * @param newDuration 新的锁定时长
     */
    function updateLockDuration(uint256 newDuration) external {
        lockDuration = newDuration;
        emit LockDurationUpdated(newDuration);
    }

    /**
     * @dev 更新区块锁数量（仅用于测试）
     * @param newBlocks 新的区块锁数量
     */
    function updateLockBlocks(uint256 newBlocks) external {
        lockBlocks = newBlocks;
        emit LockBlocksUpdated(newBlocks);
    }

    /**
     * @dev 获取当前区块号
     */
    function getCurrentBlock() external view returns (uint256) {
        return block.number;
    }

    /**
     * @dev 获取当前时间戳
     */
    function getCurrentTimestamp() external view returns (uint256) {
        return block.timestamp;
    }
}
