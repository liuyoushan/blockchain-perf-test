// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20.sol";
import "./Liquidation.sol";

/**
 * @title MaliciousAttacker
 * @dev 恶意合约 - 用于测试重入攻击
 * @notice 实现真正的重入攻击：在接收抵押品代币时回调清算函数
 */
contract MaliciousAttacker {
    Liquidation public liquidationContract;
    MyERC20 public collateralToken;
    MyERC20 public debtToken;
    address public targetUser;
    address public owner;
    
    uint256 public reentrancyCount;
    bool public attackSuccess;
    bool public reentrancyInProgress;
    
    event ReentrancyAttempt(uint256 attempt);
    event AttackResult(bool success, uint256 count);
    
    constructor(
        Liquidation _liquidationContract,
        MyERC20 _collateralToken,
        MyERC20 _debtToken
    ) {
        liquidationContract = _liquidationContract;
        collateralToken = _collateralToken;
        debtToken = _debtToken;
        owner = msg.sender;
        reentrancyCount = 0;
        attackSuccess = false;
        reentrancyInProgress = false;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    /**
     * @dev 设置要攻击的目标用户
     */
    function setTarget(address user) external onlyOwner {
        targetUser = user;
    }
    
    /**
     * @dev 获取攻击结果
     */
    function getAttackResult() external view returns (bool, uint256) {
        return (attackSuccess, reentrancyCount);
    }
    
    /**
     * @dev 提取合约中的代币
     */
    function withdrawTokens() external onlyOwner {
        uint256 colBalance = collateralToken.balanceOf(address(this));
        uint256 debtBalance = debtToken.balanceOf(address(this));
        
        if (colBalance > 0) {
            collateralToken.transfer(owner, colBalance);
        }
        if (debtBalance > 0) {
            debtToken.transfer(owner, debtBalance);
        }
    }
    
    /**
     * @dev 发起重入攻击
     * @notice 调用清算函数，在接收抵押品时触发重入
     */
    function attack() external onlyOwner {
        require(targetUser != address(0), "Target not set");
        
        reentrancyCount = 0;
        attackSuccess = false;
        reentrancyInProgress = true;
        
        uint256 debt = liquidationContract.userDebt(targetUser);
        
        // 授权清算合约转移债务代币
        debtToken.approve(address(liquidationContract), debt);
        
        // 执行清算，期望在接收抵押品时触发重入
        liquidationContract.liquidate(targetUser);
        
        reentrancyInProgress = false;
        emit AttackResult(attackSuccess, reentrancyCount);
    }
    
    /**
     * @dev 尝试重入调用清算函数
     * @notice 这个函数会在接收代币时被调用（如果代币有回调机制）
     */
    function tryReentrantCall() internal {
        if (reentrancyInProgress && targetUser != address(0)) {
            reentrancyCount++;
            emit ReentrancyAttempt(reentrancyCount);
            
            // 尝试再次调用清算函数（重入攻击）
            try liquidationContract.liquidate(targetUser) {
                attackSuccess = true;
            } catch {
                // 重入失败是预期的 - nonReentrant修饰器应该阻止这次调用
            }
        }
    }
    
    /**
     * @dev receive函数 - 接收ETH时触发
     * @notice 如果清算合约用ETH支付奖励，这里可以触发重入
     */
    receive() external payable {
        tryReentrantCall();
    }
    
    /**
     * @dev fallback函数 - 处理未知函数调用
     * @notice 如果清算合约调用了恶意合约的某个函数，可以在这里触发重入
     */
    fallback() external payable {
        tryReentrantCall();
    }
    
    /**
     * @dev 模拟ERC777风格的代币回调
     * @notice 某些代币在转账时会调用接收者的`tokensReceived`函数
     */
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external {
        // 验证调用者是抵押品代币
        if (msg.sender == address(collateralToken)) {
            tryReentrantCall();
        }
    }
}