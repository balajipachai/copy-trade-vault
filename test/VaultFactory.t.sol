// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Vault} from "../src/Vault.sol";
import {VaultFactory} from "../src/VaultFactory.sol";

contract VaultFactoryTest is Test {
    Vault public implementation;
    VaultFactory public factory;

    address public owner = makeAddr("owner");
    address public userA = makeAddr("userA");
    address public userB = makeAddr("userB");

    // Mirror of the event emitted by VaultFactory for `vm.expectEmit`.
    event VaultCreated(address indexed creator, address indexed vault);

    function setUp() public {
        implementation = new Vault();
        factory = new VaultFactory(owner, address(implementation));
    }

    function test_Deployment() public view {
        // State variables set by the constructor.
        assertEq(factory.implementation(), address(implementation));
        assertEq(factory.owner(), owner);
        assertEq(factory.getAllVaults().length, 0);
    }

    function test_CreateVault() public {
        // The deterministic address is derived from the caller (salt).
        address predicted = factory.getCreate2Address(userA);

        // Expect the VaultCreated event with creator and the predicted vault.
        vm.expectEmit();
        emit VaultCreated(userA, predicted);

        vm.prank(userA);
        address vault = factory.createVault();

        // The deployed vault matches the prediction.
        assertEq(vault, predicted);
        // The registry mapping and array are updated.
        assertEq(factory.userVaults(userA), vault);
        assertEq(factory.getAllVaults().length, 1);
        assertEq(factory.allVaults(0), vault);
        // The vault owner is the user, NOT the factory.
        assertEq(Vault(vault).owner(), userA);
        assertTrue(Vault(vault).owner() != address(factory));
    }

    function test_GetCreate2Address() public {
        // Predicted address (computed before deployment) equals the actual one.
        address predicted = factory.getCreate2Address(userA);

        vm.prank(userA);
        address actual = factory.createVault();

        assertEq(predicted, actual);
    }

    function test_GetAllVaults() public {
        // No vaults initially.
        assertEq(factory.getAllVaults().length, 0);

        vm.prank(userA);
        address vaultA = factory.createVault();

        vm.prank(userB);
        address vaultB = factory.createVault();

        // The array reflects both deployments in creation order.
        address[] memory vaults = factory.getAllVaults();
        assertEq(vaults.length, 2);
        assertEq(vaults[0], vaultA);
        assertEq(vaults[1], vaultB);
    }

    function test_VaultIsolation() public {
        // User A creates and funds their vault.
        vm.prank(userA);
        address vaultA = factory.createVault();

        vm.deal(address(this), 1 ether);
        Vault(vaultA).deposit{value: 1 ether}();

        // User B creates their own vault.
        vm.prank(userB);
        factory.createVault();

        // User B cannot withdraw from User A's vault (onlyOwner guard).
        vm.prank(userB);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, userB));
        Vault(vaultA).withdraw(1 ether);
    }

    function test_RevertIf_DeployWithZeroOwner() public {
        // Zero owner with a valid implementation reverts.
        vm.expectRevert(VaultFactory.InvalidAddress.selector);
        new VaultFactory(address(0), address(implementation));
    }

    function test_RevertIf_DeployWithZeroImpl() public {
        // Zero implementation reverts (checked first in the constructor).
        vm.expectRevert(VaultFactory.InvalidAddress.selector);
        new VaultFactory(owner, address(0));
    }

    function test_RevertIf_CreateVaultTwice() public {
        vm.startPrank(userA);
        factory.createVault();

        // A second vault for the same user reverts with VaultExists.
        vm.expectRevert(VaultFactory.VaultExists.selector);
        factory.createVault();
        vm.stopPrank();
    }
}
