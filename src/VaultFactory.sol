// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Vault} from "./Vault.sol";

contract VaultFactory is Ownable2StepUpgradeable {
    address public implementation;

    mapping(address user => address vault) public userVaults;
    address[] public allVaults;

    event VaultCreated(address indexed creator, address indexed vault);
    error InvalidAddress();
    error VaultExists();

    constructor(address owner, address impl) initializer {
        if (impl == address(0)) revert InvalidAddress();
        if (owner == address(0)) revert InvalidAddress();
        __Ownable_init(owner);
        implementation = impl;
    }

    function createVault() external returns (address userVault) {
        // msg.sender can be used for deployer as well as salt
        if (userVaults[msg.sender] != address(0)) revert VaultExists();
        // Clone the implmentation contract
        userVault = Clones.cloneDeterministic(implementation, bytes32(uint256(uint160(msg.sender))));
        // Initialize with the initial state
        Vault(userVault).initialize(msg.sender);
        // Update the mapping
        userVaults[msg.sender] = userVault;
        allVaults.push(userVault);
        emit VaultCreated(msg.sender, userVault);
    }

    function getCreate2Address(address deployer) external view returns (address) {
        return Clones.predictDeterministicAddress(
            implementation,
            bytes32(uint256(uint160(deployer))), // salt
            address(this) // deployer, factory contract
        );
    }

    function getAllVaults() external view returns (address[] memory) {
        return allVaults;
    }
}
