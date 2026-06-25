// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Vault} from "../src/Vault.sol";

/// @dev Helper contract used as a Vault owner that rejects any incoming ETH.
///      Because it has no `receive`/`payable fallback`, the low-level `call`
///      inside `Vault.withdraw` will fail, allowing us to test the
///      "Withdraw failed" revert path.
contract RejectEther {
    /// @dev Forwards a withdraw call to the vault. Since `withdraw` sends the
    ///      ETH back to `msg.sender` (this contract), and this contract cannot
    ///      receive ETH, the transfer fails.
    function callWithdraw(Vault vault, uint256 amount) external {
        vault.withdraw(amount);
    }
}

contract VaultTest is Test {
    Vault public implementation;
    Vault public vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public nonOwner = makeAddr("nonOwner");

    // Mirror of the events emitted by Vault so we can use `vm.expectEmit`.
    event Deposit(address indexed deposiotr, uint256 amount);
    event Withdraw(address indexed withdrawer, uint256 amount);

    function setUp() public {
        // Deploy the implementation. Its initializers are disabled in the
        // constructor, so we interact with a fresh clone instead.
        implementation = new Vault();

        // Create a minimal proxy clone and initialize it with `owner`.
        vault = Vault(Clones.clone(address(implementation)));
        vault.initialize(owner);
    }

    /// @dev Helper that funds `vault` with `amount` of ETH via `deposit`.
    function _deposit(uint256 amount) internal {
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();
    }

    function test_Deployment() public view {
        // The clone is initialized: owner is set and balance starts at zero.
        assertEq(vault.owner(), owner);
        assertEq(vault.balance(), 0);
        assertEq(address(vault).balance, 0);
    }

    function test_Deposit() public {
        uint256 amount = 1 ether;
        vm.deal(user, amount);

        // Expect the Deposit event with the depositor and amount.
        vm.expectEmit();
        emit Deposit(user, amount);

        vm.prank(user);
        vault.deposit{value: amount}();

        // Both the tracked balance and the real ETH balance increase.
        assertEq(vault.balance(), amount);
        assertEq(address(vault).balance, amount);
    }

    function test_Withdraw() public {
        uint256 amount = 1 ether;
        _deposit(amount);

        uint256 ownerBalanceBefore = owner.balance;

        // Expect the Withdraw event with the owner and amount.
        vm.expectEmit();
        emit Withdraw(owner, amount);

        vm.prank(owner);
        vault.withdraw(amount);

        // Tracked balance decreases, ETH is transferred to the owner.
        assertEq(vault.balance(), 0);
        assertEq(address(vault).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + amount);
    }

    function test_RevertIf_InitializeTwice() public {
        // The clone was already initialized in setUp, so a second call reverts.
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        vault.initialize(owner);
    }

    function test_RevertIf_WithdrawExceedsBalance() public {
        // Vault is empty; withdrawing any non-zero amount reverts.
        vm.prank(owner);
        vm.expectRevert("Insufficient Balance");
        vault.withdraw(1 ether);
    }

    function test_RevertIf_WithdrawFailedTransfer() public {
        // Deploy a vault owned by a contract that rejects ETH.
        RejectEther rejecter = new RejectEther();
        Vault rejectingVault = Vault(Clones.clone(address(implementation)));
        rejectingVault.initialize(address(rejecter));

        // Fund the vault so the balance check passes and we reach the transfer.
        uint256 amount = 1 ether;
        vm.deal(user, amount);
        vm.prank(user);
        rejectingVault.deposit{value: amount}();

        // The ETH transfer back to the rejecter fails -> "Withdraw failed".
        vm.expectRevert("Withdraw failed");
        rejecter.callWithdraw(rejectingVault, amount);
    }

    function test_RevertIf_NonOwnerWithdraws() public {
        _deposit(1 ether);

        // The onlyOwner guard blocks non-owners.
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, nonOwner));
        vault.withdraw(1 ether);
    }

    /// @dev Fuzz the withdraw flow with random amounts.
    function testFuzz_Withdraw(uint256 amount) public {
        // Bound to a sensible, dealable range (avoid zero so the event/transfer
        // paths are meaningfully exercised).
        amount = bound(amount, 1, 1_000_000 ether);

        _deposit(amount);

        uint256 ownerBalanceBefore = owner.balance;

        vm.expectEmit();
        emit Withdraw(owner, amount);

        vm.prank(owner);
        vault.withdraw(amount);

        assertEq(vault.balance(), 0);
        assertEq(address(vault).balance, 0);
        assertEq(owner.balance, ownerBalanceBefore + amount);
    }
}
