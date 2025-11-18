// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/external/IBeginningJavascript.sol";
import "../../../utils/SSTORE2.sol";

/// @notice Chunked Tone.js source backed by SSTORE2 pointers.
contract InlineToneSource is IBeginningJavascript {
    address public immutable owner;

    address[] public tonePointers;
    address[] public gunzipPointers;

    bool public toneLocked;
    bool public gunzipLocked;

    error NotOwner();
    error Locked();
    error EmptyChunk();
    error ChunkTooLarge();

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @notice Uploads one chunk of base64 data (Tone.js gzip or gunzip helper).
    function uploadChunk(bytes calldata chunk, bool isGunzip) external onlyOwner {
        if (chunk.length == 0) revert EmptyChunk();
        if (chunk.length > 24_575) revert ChunkTooLarge();

        if (isGunzip) {
            if (gunzipLocked) revert Locked();
            gunzipPointers.push(SSTORE2.write(chunk));
        } else {
            if (toneLocked) revert Locked();
            tonePointers.push(SSTORE2.write(chunk));
        }
    }

    function lock(bool isGunzip) external onlyOwner {
        if (isGunzip) {
            gunzipLocked = true;
        } else {
            toneLocked = true;
        }
    }

    function getTonejs() external view returns (string memory) {
        string memory tone = _readAll(tonePointers);
        string memory gunzip = _readAll(gunzipPointers);
        return string(
            abi.encodePacked(
                "<script type=\"text/javascript+gzip\" src=\"data:text/javascript;base64,",
                tone,
                "\"></script>",
                "<script src=\"data:text/javascript;base64,",
                gunzip,
                "\"></script>"
            )
        );
    }

    function _readAll(address[] storage ptrs) internal view returns (string memory) {
        uint256 total;
        uint256 len = ptrs.length;
        uint256[] memory sizes = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 size = SSTORE2.dataLength(ptrs[i]);
            sizes[i] = size;
            total += size;
        }

        bytes memory out = new bytes(total);
        uint256 offset;
        for (uint256 i = 0; i < len; i++) {
            SSTORE2.readInto(ptrs[i], out, offset);
            offset += sizes[i];
        }
        return total == 0 ? "" : string(out);
    }
}
