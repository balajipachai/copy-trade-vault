// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract EIP712Verifier {
    bytes32 constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant TRANSFER_TYPEHASH = keccak256("Transfer(address to,uint256 amount,uint256 nonce)");

    bytes32 public domainSeparator;

    mapping(address account => uint256 nonce) public nonces;

    struct Transfer {
        address to;
        uint256 amount;
        uint256 nonce;
    }

    event Executed(address signer, uint256 nonce);

    // keccak256(EIP712_DOMAIN_TYPEHASH || enc(name) || enc(version) || enc(chainId) || enc(verifyingContract))
    constructor(string memory name, string memory version) {
        domainSeparator = keccak256(abi.encode(
            EIP712_DOMAIN_TYPEHASH,
            keccak256(bytes(name)),
            keccak256(bytes(version)),
            block.chainid,
            address(this)
        ));
    }

    function execute(address signer, Transfer calldata transfer, uint8 v, bytes32 r, bytes32 s) external {
        require(verify(signer, transfer, v, r, s), "Verification failed");
        require(nonces[signer] == transfer.nonce, "Invalid nonces");
        uint256 tempNonce = nonces[signer];
        nonces[signer] += 1;
        emit Executed(signer, tempNonce);
    }

    function verify(address signer, Transfer calldata transfer, uint8 v, bytes32 r, bytes32 s) internal view returns(bool) {
        require(signer != address(0), "Invalid signer");
        bytes32 finalHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                hashStruct(transfer)
            )
        );
        address originalSigner = ecrecover(finalHash, v, r, s);
        return originalSigner == signer;
    }

    function hashStruct(Transfer calldata transfer) internal pure returns (bytes32 result) {
        return keccak256(abi.encode(
            TRANSFER_TYPEHASH,
            transfer.to,
            transfer.amount,
            transfer.nonce
        ));
    }
}


/**
 * 
 * Yul Assembly
 * Ran 5 tests for test/EIP712Verifier.t.sol:EIP712VerifierTest
[PASS] test_CrossContractReplay() (gas: 515056)
[PASS] test_Execute() (gas: 58740)
[PASS] test_RevertsWhenReplayAttackHappens() (gas: 67167)
[PASS] test_RevertsWhenSignatureIsInvalid() (gas: 31643)
[PASS] test_RevertsWhenSignerIsAddressZero() (gas: 24857)
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 9.43ms (21.97ms CPU time)


Using keccak256
Ran 5 tests for test/EIP712Verifier.t.sol:EIP712VerifierTest
[PASS] test_CrossContractReplay() (gas: 563915)
[PASS] test_Execute() (gas: 59688)
[PASS] test_RevertsWhenReplayAttackHappens() (gas: 69063)
[PASS] test_RevertsWhenSignatureIsInvalid() (gas: 32591)
[PASS] test_RevertsWhenSignerIsAddressZero() (gas: 24857)
Suite result: ok. 5 passed; 0 failed; 0 skipped; finished in 1.67ms (4.46ms CPU time)
 */

