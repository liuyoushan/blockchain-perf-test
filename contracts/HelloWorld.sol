// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HelloWorld {
    string public message;

    constructor() {
        message = "Hello ApeWorX!";
    }

    function setMessage(string calldata newMsg) external {
        message = newMsg;
    }
}
