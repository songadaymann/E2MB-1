// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Minimal SSTORE2 helper (adapted from Solmate)
/// @notice Stores arbitrary data in contract bytecode and reads it back efficiently.
library SSTORE2 {
    /// @dev Writes `data` to a new contract and returns the address.
    function write(bytes memory data) internal returns (address pointer) {
        // Prefix with a STOP to ensure the deployed contract cannot be called.
        bytes memory runtime = abi.encodePacked(hex"00", data);
        bytes memory creation = abi.encodePacked(
            hex"61",
            uint16(runtime.length),
            hex"3d81600a3d39f3",
            runtime
        );

        assembly {
            pointer := create(0, add(creation, 0x20), mload(creation))
            if iszero(pointer) {
                revert(0, 0)
            }
        }
    }

    /// @dev Reads the full contents written to `pointer`.
    function read(address pointer) internal view returns (bytes memory data) {
        uint256 len = dataLength(pointer);
        assembly {
            data := mload(0x40)
            mstore(0x40, add(data, and(add(add(len, 0x20), 0x1f), not(0x1f))))
            mstore(data, len)
            extcodecopy(pointer, add(data, 0x20), 1, len)
        }
    }

    function dataLength(address pointer) internal view returns (uint256 len) {
        assembly {
            len := sub(extcodesize(pointer), 1)
        }
    }

    function readInto(address pointer, bytes memory buffer, uint256 offset) internal view {
        uint256 len = dataLength(pointer);
        assembly {
            extcodecopy(pointer, add(add(buffer, 0x20), offset), 1, len)
        }
    }
}
