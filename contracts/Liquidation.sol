// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20.sol";

/**
 * @title Liquidation
 * @dev 清算合约 - 实现健康因子计算和清算触发逻辑
 * 包含重入防护、重复清算防护等安全措施
 */
contract Liquidation {
    // ========== 状态变量 ==========
    address public immutable owner;
    MyERC20 public immutable collateralToken;
    MyERC20 public immutable debtToken;
    
    // 清算阈值（使用 18 位精度）
    uint256 public constant HEALTH_FACTOR_WARNING = 1200000000000000000;  // 1.2
    uint256 public constant HEALTH_FACTOR_LIQUIDATION = 1000000000000000000;  // 1.0
    
    // 用户状态
    mapping(address => uint256) public userCollateral;  // 用户抵押品
    mapping(address => uint256) public userDebt;        // 用户债务
    mapping(address => bool) public isLiquidated;       // 是否已清算（防止重复清算）
    
    // 重入锁
    bool private locked;
    
    // ========== 事件 ==========
    event CollateralDeposited(address indexed user, uint256 amount);
    event DebtBorrowed(address indexed user, uint256 amount);
    event LiquidationTriggered(address indexed liquidator, address indexed user, uint256 debt);
    event ReentrancyAttackAttempted(address indexed attacker);
    
    // ========== 修饰器 ==========
    
    /**
     * @dev 重入防护修饰器
     */
    modifier nonReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }
    
    // ========== 构造函数 ==========
    constructor(MyERC20 _collateralToken, MyERC20 _debtToken) {
        owner = msg.sender;
        collateralToken = _collateralToken;
        debtToken = _debtToken;
        locked = false;
    }
    
    // ========== 核心函数 ==========
    
    /**
     * @dev 存入抵押品
     */
    function depositCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        require(collateralToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        userCollateral[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }
    
    /**
     * @dev 借出债务（需要有足够抵押）
     */
    function borrow(uint256 amount) external nonReentrant {
        require(amount > 0, "Amount must be > 0");
        
        // 检查抵押率（初始要求至少 150% 抵押率）
        uint256 requiredCollateral = amount * 3 / 2;  // 150%
        require(userCollateral[msg.sender] >= requiredCollateral, "Insufficient collateral");
        
        // Check-Effects-Interaction 模式：先修改状态，再转账
        userDebt[msg.sender] += amount;
        
        require(debtToken.transfer(msg.sender, amount), "Transfer failed");
        emit DebtBorrowed(msg.sender, amount);
    }
    
    /**
     * @dev 计算用户健康因子
     * @return 健康因子（18位精度）
     */
    function getHealthFactor(address user) public view returns (uint256) {
        uint256 debt = userDebt[user];
        if (debt == 0) return type(uint256).max;  // 无债务时健康因子无穷大
        return (userCollateral[user] * 1e18) / debt;
    }
    
    /**
     * @dev 检查是否可以清算
     * @notice 清算条件：
     *         1. 抵押品充足（>= 债务 + 奖励）：无论健康因子如何都可清算
     *         2. 健康因子 <= 1.0（抵押品不足时，需满足健康因子条件）
     */
    function canLiquidate(address user) public view returns (bool) {
        uint256 hf = getHealthFactor(user);
        uint256 debt = userDebt[user];
        uint256 collateral = userCollateral[user];
        uint256 reward = debt / 10;
        bool sufficientCollateral = collateral >= debt + reward;
        return (sufficientCollateral || hf <= HEALTH_FACTOR_LIQUIDATION) && !isLiquidated[user];
    }
    
    /**
     * @dev 检查是否处于预警状态
     */
    function isWarning(address user) public view returns (bool) {
        uint256 hf = getHealthFactor(user);
        return hf > HEALTH_FACTOR_LIQUIDATION && hf <= HEALTH_FACTOR_WARNING;
    }
    
    /**
     * @dev 执行清算（清算人偿还债务，获得抵押品+奖励）
     * @notice 修改：清算人只需支付 min(债务, 抵押品)，更合理的清算机制
     */
    function liquidate(address user) external nonReentrant {
        // 检查是否可清算（包含重复清算检查）
        require(canLiquidate(user), "Cannot liquidate - health factor > 1 or already liquidated");

        uint256 debt = userDebt[user];
        uint256 collateral = userCollateral[user];

        // 计算清算奖励（从债务中提取10%）
        uint256 reward = debt / 10;

        // Check-Effects-Interaction 模式：先修改状态，再转账
        // 1. 先标记为已清算（防止重复清算）
        isLiquidated[user] = true;

        // 2. 清除用户债务
        userDebt[user] = 0;

        // 3. 清算人只需支付 min(债务, 抵押品)
        uint256 liquidatorPayment = debt < collateral ? debt : collateral;

        // 4. 计算用户剩余抵押品
        // 如果抵押品充足，用户剩余 = 抵押品 - 债务 - 奖励
        // 如果抵押品不足，清算人获得全部抵押品，用户剩余 = 0
        if (collateral >= debt + reward) {
            // 抵押品足够支付债务+奖励：用户剩余 = 抵押品 - 债务 - 奖励
            userCollateral[user] = collateral - debt - reward;
        } else {
            // 抵押品不足：清算人获得全部抵押品，用户剩余为0
            userCollateral[user] = 0;
        }

        // 5. 清算人支付 min(债务, 抵押品)
        require(debtToken.transferFrom(msg.sender, address(this), liquidatorPayment), "Transfer failed");

        // 6. 转移抵押品给清算人（清算人获得全部抵押品，奖励从抵押品中出）
        uint256 collateralToLiquidator = collateral;
        require(collateralToken.transfer(msg.sender, collateralToLiquidator), "Transfer failed");

        emit LiquidationTriggered(msg.sender, user, debt);
    }
    
    // ========== 辅助函数（仅用于测试） ==========
    
    /**
     * @dev 重置用户清算状态（仅用于测试，实际中不需要）
     */
    function resetLiquidationStatus(address user) external {
        require(msg.sender == owner, "Only owner");
        isLiquidated[user] = false;
    }
    
    /**
     * @dev 设置用户抵押品和债务（仅用于测试，实际中通过 deposit/borrow）
     */
    function setUserPosition(address user, uint256 collateral, uint256 debt) external {
        require(msg.sender == owner, "Only owner");
        userCollateral[user] = collateral;
        userDebt[user] = debt;
    }
}