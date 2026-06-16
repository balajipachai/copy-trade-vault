// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract EIP712Verifier {
    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
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
        domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH, keccak256(bytes(name)), keccak256(bytes(version)), block.chainid, address(this)
            )
        );
    }

    function execute(address signer, Transfer calldata transfer, uint8 v, bytes32 r, bytes32 s) external {
        require(verify(signer, transfer, v, r, s), "Verification failed");
        require(nonces[signer] == transfer.nonce, "Invalid nonces");
        uint256 tempNonce = nonces[signer];
        nonces[signer] += 1;
        emit Executed(signer, tempNonce);
    }

    function verify(address signer, Transfer calldata transfer, uint8 v, bytes32 r, bytes32 s)
        internal
        view
        returns (bool)
    {
        require(signer != address(0), "Invalid signer");

        bytes32 result = hashStruct(transfer);
        bytes32 finalHash;

        assembly {
            let ptr := mload(0x40)
            mstore8(ptr, 0x19)
            mstore8(add(ptr, 1), 0x01)
            mstore(add(ptr, 2), sload(domainSeparator.slot))
            mstore(add(ptr, 34), result)

            finalHash := keccak256(ptr, 66)
        }

        address originalSigner = ecrecover(finalHash, v, r, s);
        return originalSigner == signer;
    }

    function hashStruct(Transfer calldata transfer) internal pure returns (bytes32 result) {
        address to = transfer.to;
        uint256 amount = transfer.amount;
        uint256 nonce = transfer.nonce;

        // Assign to a local variable first
        // as it was causing error
        // Error (7615): Only direct number constants and references to such constants are supported by inline assembly.
        bytes32 transferTypeHash = TRANSFER_TYPEHASH;

        assembly {
            let ptr := mload(0x40) // get free pointer
            mstore(ptr, transferTypeHash)

            mstore(add(ptr, 32), to)
            mstore(add(ptr, 64), amount)
            mstore(add(ptr, 96), nonce)

            result := keccak256(ptr, 128)
        }
    }
}

