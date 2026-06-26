// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract CommiReveal {
    struct Committment {
        bytes32 hash;
        bool isRevealed;
        uint64 deadline;
    }

    mapping(address user => Committment[] committment) public commitments;

    event Committed(address indexed user, bytes32 commitmmentHash, uint64 deadline);
    event Revealed(address indexed user, bytes32 commitmmentHash);

    error PassedDeadline();
    error AlreadyRevealed();
    error HashMismatch();

    function commit(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 amountOutMin,
        uint256 nonce,
        uint64 deadline
    ) external {
        bytes32 hash;
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, caller())
            mstore(add(ptr, 32), tokenIn)
            mstore(add(ptr, 64), tokenOut)
            mstore(add(ptr, 96), amount)
            mstore(add(ptr, 128), amountOutMin)
            mstore(add(ptr, 160), nonce)

            // Update free memory pointer to point past our 192 bytes data area
            mstore(0x40, add(ptr, 192))

            hash := keccak256(ptr, 192)
        }
        commitments[msg.sender].push(Committment({hash: hash, isRevealed: false, deadline: deadline}));
        emit Committed(msg.sender, hash, deadline);
    }

    function reveal(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 amountOutMin,
        uint256 nonce,
        uint256 index
    ) external {
        // Check
        Committment storage committment = commitments[msg.sender][index];
        if (block.timestamp > committment.deadline) revert PassedDeadline();
        if (committment.isRevealed) revert AlreadyRevealed();

        bytes32 calculatedHash;

        assembly {
            let ptr := mload(0x40)
            mstore(ptr, caller())
            mstore(add(ptr, 32), tokenIn)
            mstore(add(ptr, 64), tokenOut)
            mstore(add(ptr, 96), amount)
            mstore(add(ptr, 128), amountOutMin)
            mstore(add(ptr, 160), nonce)
            // Update free memory pointer to point past our 192 bytes data area
            mstore(0x40, add(ptr, 192))

            calculatedHash := keccak256(ptr, 192)
        }

        if (calculatedHash != committment.hash) revert HashMismatch();

        // Effects
        committment.isRevealed = true;

        emit Revealed(msg.sender, calculatedHash);

        // Interaction
        // Swap will happen here
    }
}
