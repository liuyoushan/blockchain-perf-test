// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20.sol";

/**
 * @title StakingContract
 * @dev 简单的质押挖矿合约，支持质押、奖励计算、解押功能
 */
contract StakingContract {
    // ==================== 状态变量 ====================
    MyERC20 public immutable stakingToken;
    MyERC20 public immutable rewardToken;
    
    uint256 public rewardPerBlock;        // 每个区块的奖励
    uint256 public lastRewardBlock;       // 上次奖励区块
    uint256 public accRewardPerShare;     // 累计每股奖励
    uint256 public totalStaked;           // 总质押量
    
    uint256 public constant PRECISION = 1e18;  // 精度
    
    // 用户质押信息
    struct UserInfo {
        uint256 amount;           // 质押数量
        uint256 rewardDebt;       // 奖励债务
        uint256 pendingRewards;   // 待领取奖励
    }
    
    mapping(address => UserInfo) public userInfo;
    
    // ==================== 事件 ====================
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 amount);
    event RewardPerBlockUpdated(uint256 oldReward, uint256 newReward);
    
    // ==================== 构造函数 ====================
    constructor(address _stakingToken, address _rewardToken, uint256 _rewardPerBlock) {
        stakingToken = MyERC20(_stakingToken);
        rewardToken = MyERC20(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        lastRewardBlock = block.number;
    }
    
    // ==================== 核心功能 ====================
    
    /**
     * @dev 更新奖励池状态
     */
    function updatePool() public {
        if (block.number <= lastRewardBlock) {
            return;
        }
        
        if (totalStaked == 0) {
            lastRewardBlock = block.number;
            return;
        }
        
        uint256 blocksPassed = block.number - lastRewardBlock;
        uint256 reward = blocksPassed * rewardPerBlock;
        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastRewardBlock = block.number;
    }
    
    /**
     * @dev 质押代币
     * @param amount 质押数量
     */
    function stake(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        
        UserInfo storage user = userInfo[msg.sender];
        
        // 更新池状态
        updatePool();
        
        // 如果用户已有质押，先结算奖励
        if (user.amount > 0) {
            uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
            user.pendingRewards += pending;
        }
        
        // 转入质押代币
        stakingToken.transferFrom(msg.sender, address(this), amount);
        
        // 更新用户信息
        user.amount += amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
        
        totalStaked += amount;
        
        emit Staked(msg.sender, amount);
    }
    
    /**
     * @dev 解押代币
     * @param amount 解押数量
     */
    function unstake(uint256 amount) external {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= amount, "Insufficient staked balance");
        
        // 更新池状态并结算奖励
        updatePool();
        
        uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
        user.pendingRewards += pending;
        
        // 更新用户信息
        user.amount -= amount;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
        
        totalStaked -= amount;
        
        // 转出质押代币
        stakingToken.transfer(msg.sender, amount);
        
        emit Unstaked(msg.sender, amount);
    }
    
    /**
     * @dev 领取奖励
     */
    function claimReward() external {
        UserInfo storage user = userInfo[msg.sender];
        
        // 更新池状态
        updatePool();
        
        // 计算待领取奖励
        uint256 pending = (user.amount * accRewardPerShare) / PRECISION - user.rewardDebt;
        uint256 totalReward = user.pendingRewards + pending;
        
        require(totalReward > 0, "No rewards to claim");
        
        // 重置用户奖励状态
        user.pendingRewards = 0;
        user.rewardDebt = (user.amount * accRewardPerShare) / PRECISION;
        
        // 转出奖励代币
        rewardToken.transfer(msg.sender, totalReward);
        
        emit RewardClaimed(msg.sender, totalReward);
    }
    
    /**
     * @dev 查询待领取奖励
     * @param userAddress 用户地址
     * @return 待领取奖励数量
     */
    function pendingReward(address userAddress) external view returns (uint256) {
        UserInfo storage user = userInfo[userAddress];
        
        uint256 accReward = accRewardPerShare;
        
        if (block.number > lastRewardBlock && totalStaked > 0) {
            uint256 blocksPassed = block.number - lastRewardBlock;
            uint256 reward = blocksPassed * rewardPerBlock;
            accReward += (reward * PRECISION) / totalStaked;
        }
        
        return user.pendingRewards + (user.amount * accReward) / PRECISION - user.rewardDebt;
    }
    
    // ==================== 管理功能 ====================
    
    /**
     * @dev 更新每个区块奖励（仅用于测试）
     * @param newReward 新的区块奖励
     */
    function setRewardPerBlock(uint256 newReward) external {
        updatePool();
        uint256 oldReward = rewardPerBlock;
        rewardPerBlock = newReward;
        emit RewardPerBlockUpdated(oldReward, newReward);
    }
    
    /**
     * @dev 铸造奖励代币（仅用于测试）
     * @param amount 铸造数量
     */
    function mintRewardToken(uint256 amount) external {
        rewardToken.mint(address(this), amount);
    }
}
