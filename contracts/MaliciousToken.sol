// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MyERC20.sol";

interface ITokensRecipient {
    function tokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes calldata userData,
        bytes calldata operatorData
    ) external;
}

/**
 * @title MaliciousToken
 * @dev 恶意代币合约 - 支持回调机制，用于测试重入攻击
 * @notice 模拟ERC777风格的代币，在转账时调用接收者的tokensReceived函数
 */
contract MaliciousToken is MyERC20 {
    event TokensReceived(address operator, address from, address to, uint256 amount);

    constructor(string memory name, string memory symbol) MyERC20(name, symbol) {}

    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address from = msg.sender;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);

        _callTokensReceived(from, from, to, amount, "", "");

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = msg.sender;
        allowance[from][spender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);

        _callTokensReceived(spender, from, to, amount, "", "");

        return true;
    }

    function _callTokensReceived(
        address operator,
        address from,
        address to,
        uint256 amount,
        bytes memory userData,
        bytes memory operatorData
    ) private {
        if (to.code.length > 0) {
            try ITokensRecipient(to).tokensReceived(operator, from, to, amount, userData, operatorData) {
                emit TokensReceived(operator, from, to, amount);
            } catch (bytes memory) {
            }
        }
    }
}