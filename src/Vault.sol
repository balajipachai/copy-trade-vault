// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Vault is Initializable, OwnableUpgradeable {
    uint256 public balance;

    event Deposit(address indexed deposiotr, uint256 amount);
    event Withdraw(address indexed withdrawer, uint256 amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
    }

    function deposit() external payable {
        balance += msg.value;
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external onlyOwner {
        require(balance >= amount, "Insufficient Balance");
        balance -= amount;
        emit Withdraw(msg.sender, amount);
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Withdraw failed");
    }
}
