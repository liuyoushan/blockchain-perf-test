// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title UpgradeableProxy - 可升级代理合约
 * @dev 实现 EIP-1967 代理模式
 */
contract UpgradeableProxy {
    event Upgraded(address indexed implementation);
    event AdminChanged(address previousAdmin, address newAdmin);

    constructor(address _implementation, address _admin) {
        bytes32 implSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        
        assembly {
            sstore(implSlot, _implementation)
            sstore(adminSlot, _admin)
        }
    }

    function _getImplementation() internal view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        address impl;
        assembly {
            impl := sload(slot)
        }
        return impl;
    }

    function _getAdmin() internal view returns (address) {
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address admin;
        assembly {
            admin := sload(slot)
        }
        return admin;
    }

    function upgradeTo(address _newImplementation) external {
        require(msg.sender == _getAdmin(), "Only admin can upgrade");
        require(_newImplementation != address(0), "Invalid implementation");
        
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        assembly {
            sstore(slot, _newImplementation)
        }
        
        emit Upgraded(_newImplementation);
    }

    function changeAdmin(address _newAdmin) external {
        require(msg.sender == _getAdmin(), "Only admin can change");
        require(_newAdmin != address(0), "Invalid admin");
        
        address oldAdmin = _getAdmin();
        
        bytes32 slot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        assembly {
            sstore(slot, _newAdmin)
        }
        
        emit AdminChanged(oldAdmin, _newAdmin);
    }

    function getImplementation() external view returns (address) {
        return _getImplementation();
    }

    function getAdmin() external view returns (address) {
        return _getAdmin();
    }

    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {
        _delegate(_getImplementation());
    }

    function _delegate(address _implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

/**
 * @title LogicV1 - 初始逻辑合约版本1
 */
contract LogicV1 {
    uint256 public value;
    string public version;

    event ValueSet(uint256 indexed value);

    function initialize(uint256 _value) external {
        value = _value;
        version = "V1";
    }

    function setValue(uint256 _value) external {
        value = _value;
        emit ValueSet(_value);
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function getVersion() external view returns (string memory) {
        return version;
    }
}

/**
 * @title LogicV2 - 升级后逻辑合约版本2
 */
contract LogicV2 {
    uint256 public value;
    string public version;
    uint256 public additionalValue;

    event ValueSet(uint256 indexed value);
    event AdditionalValueSet(uint256 indexed value);

    function initializeV2(uint256 _additionalValue) external {
        version = "V2";
        additionalValue = _additionalValue;
    }

    function setValue(uint256 _value) external {
        value = _value;
        emit ValueSet(_value);
    }

    function setAdditionalValue(uint256 _value) external {
        additionalValue = _value;
        emit AdditionalValueSet(_value);
    }

    function getValue() external view returns (uint256) {
        return value;
    }

    function getVersion() external view returns (string memory) {
        return version;
    }

    function getAdditionalValue() external view returns (uint256) {
        return additionalValue;
    }

    function getSum() external view returns (uint256) {
        return value + additionalValue;
    }
}