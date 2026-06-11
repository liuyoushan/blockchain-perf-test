// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MyERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    address public owner;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    
    mapping(bytes32 => mapping(address => bool)) public roles;
    bool public paused;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);
    event Paused();
    event Unpaused();

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        owner = msg.sender;
        roles[ADMIN_ROLE][msg.sender] = true;
        roles[MINTER_ROLE][msg.sender] = true;
        roles[PAUSER_ROLE][msg.sender] = true;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyRole(bytes32 role) {
        require(roles[role][msg.sender], "Missing required role");
        _;
    }
    
    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    function grantRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        roles[role][account] = true;
        emit RoleGranted(role, account);
    }
    
    function revokeRole(bytes32 role, address account) external onlyRole(ADMIN_ROLE) {
        roles[role][account] = false;
        emit RoleRevoked(role, account);
    }
    
    function hasRole(bytes32 role, address account) external view returns (bool) {
        return roles[role][account];
    }
    
    function pause() external onlyRole(PAUSER_ROLE) {
        paused = true;
        emit Paused();
    }
    
    function unpause() external onlyRole(PAUSER_ROLE) {
        paused = false;
        emit Unpaused();
    }

    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
    }

    function _mint(address to, uint256 amount) internal {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
    
    function burn(uint256 amount) external whenNotPaused {
        _burn(msg.sender, amount);
    }
    
    function burnFrom(address account, uint256 amount) external whenNotPaused {
        allowance[account][msg.sender] -= amount;
        _burn(account, amount);
    }
    
    function _burn(address from, uint256 amount) internal {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function transfer(address to, uint256 amount) external virtual whenNotPaused returns (bool) {
        require(to != address(0), "MyERC20: Transfer to zero address");
        require(to != 0x000000000000000000000000000000000000dEaD, "MyERC20: Transfer to blackhole address");
        
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        require(amount != type(uint256).max, "MyERC20: Infinite approval not allowed");
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external virtual returns (bool) {
        require(to != address(0), "MyERC20: Transfer to zero address");
        require(to != 0x000000000000000000000000000000000000dEaD, "MyERC20: Transfer to blackhole address");
        
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }

    // ==================== 批量操作接口 ====================
    
    function batchTransfer(address[] calldata recipients, uint256[] calldata amounts) external whenNotPaused returns (bool) {
        require(recipients.length == amounts.length, "MyERC20: Array length mismatch");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            balanceOf[msg.sender] -= amounts[i];
            balanceOf[recipients[i]] += amounts[i];
            emit Transfer(msg.sender, recipients[i], amounts[i]);
        }
        return true;
    }

    function batchApprove(address[] calldata spenders, uint256[] calldata amounts) external returns (bool) {
        require(spenders.length == amounts.length, "MyERC20: Array length mismatch");
        
        for (uint256 i = 0; i < spenders.length; i++) {
            require(amounts[i] != type(uint256).max, "MyERC20: Infinite approval not allowed");
            allowance[msg.sender][spenders[i]] = amounts[i];
            emit Approval(msg.sender, spenders[i], amounts[i]);
        }
        return true;
    }

    function batchTransferFrom(
        address[] calldata froms,
        address[] calldata tos,
        uint256[] calldata amounts
    ) external virtual returns (bool) {
        require(froms.length == tos.length && tos.length == amounts.length, "MyERC20: Array length mismatch");
        
        for (uint256 i = 0; i < froms.length; i++) {
            allowance[froms[i]][msg.sender] -= amounts[i];
            balanceOf[froms[i]] -= amounts[i];
            balanceOf[tos[i]] += amounts[i];
            emit Transfer(froms[i], tos[i], amounts[i]);
        }
        return true;
    }
}