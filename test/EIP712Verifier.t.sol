// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {EIP712Verifier} from "../src/EIP712Verifier.sol";

contract EIP712VerifierTest is Test {
    EIP712Verifier public eip712Verifier;

    address public signer;
    uint256 private privateKey = uint256(1);

    address to = address(2);
    uint256 amount = 1 ether; // 1_000_000_000_000_000_000;
    uint256 currentNonce = 0;

    bytes32 constant TRANSFER_TYPEHASH = keccak256("Transfer(address to,uint256 amount,uint256 nonce)");

    function setUp() public {
        eip712Verifier = new EIP712Verifier("Zignaly", "1.0");
        signer = vm.addr(privateKey);
        currentNonce = eip712Verifier.nonces(signer);
    }

    function getDigest() public view returns (bytes32 digest, EIP712Verifier.Transfer memory transfer) {
        // The transfer struct is built as follows
        transfer = EIP712Verifier.Transfer({to: to, amount: amount, nonce: currentNonce});

        // Constructing the final digest as it is done inside the main contract
        digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                eip712Verifier.domainSeparator(),
                keccak256(abi.encode(TRANSFER_TYPEHASH, transfer.to, transfer.amount, transfer.nonce))
            )
        );
    }

    function test_Execute() public {
        (bytes32 digest, EIP712Verifier.Transfer memory transfer) = getDigest();

        // Get hold of the signature components v, r and s
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Prior to calling execute
        // nonces[signer] = 0
        assertEq(eip712Verifier.nonces(signer), 0);

        // Call execute and assert it succeeds
        eip712Verifier.execute(signer, transfer, v, r, s);

        // After calling execute
        // nonces[signer] = 1
        assertEq(eip712Verifier.nonces(signer), 1);
    }

    function test_RevertsWhenSignatureIsInvalid() public {
        // Get digest and transfer struct
        (bytes32 digest, EIP712Verifier.Transfer memory transfer) = getDigest();
        // Get hold of the signature components v, r and s
        (, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        vm.expectRevert("Verification failed");
        // Call execute and assert it reverts
        eip712Verifier.execute(
            signer,
            transfer,
            108, // making the signature invalid
            r,
            s
        );
    }

    function test_RevertsWhenSignerIsAddressZero() public {
        // Get digest and transfer struct
        (bytes32 digest, EIP712Verifier.Transfer memory transfer) = getDigest();
        // Get hold of the signature components v, r and s
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        vm.expectRevert("Invalid signer");
        // Call execute and assert it reverts
        eip712Verifier.execute(
            address(0), // passing signer as the zero address
            transfer,
            v,
            r,
            s
        );
    }

    function test_RevertsWhenReplayAttackHappens() public {
        // Get digest and transfer struct
        (bytes32 digest, EIP712Verifier.Transfer memory transfer) = getDigest();
        // Get hold of the signature components v, r and s
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        vm.expectEmit();
        uint256 tempNonce = eip712Verifier.nonces(signer);
        emit EIP712Verifier.Executed(signer, tempNonce);
        // Call execute and assert it reverts
        eip712Verifier.execute(signer, transfer, v, r, s);

        // We will try replaying the same signature in that case it should fail with
        // "Invalid nonces"
        vm.expectRevert("Invalid nonces");
        // Call execute and assert it reverts
        eip712Verifier.execute(signer, transfer, v, r, s);
    }

    function test_CrossContractReplay() public {
        EIP712Verifier anotherEip712Verifier = new EIP712Verifier("Paradex", "1.0");

        // Get digest and transfer struct
        (bytes32 digest, EIP712Verifier.Transfer memory transfer) = getDigest();
        // Get hold of the signature components v, r and s
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        vm.expectRevert("Verification failed");
        // Call execute and assert it reverts
        anotherEip712Verifier.execute(signer, transfer, v, r, s);
    }
}
