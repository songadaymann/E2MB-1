// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../render/post/AudioRenderer.sol";

/**
 * @title AudioRendererExternal
 * @notice Standalone contract for audio HTML generation (external calls to save main contract size)
 * @dev Wraps AudioRenderer library with external functions
 */
contract AudioRendererExternal {
    /**
     * @notice Generate HTML audio player as data URI
     * @dev External/pure so it can be deployed separately and called cross-contract
     */
    function generateAudioHTML(
        int16 leadPitch,
        int16 bassPitch,
        uint256 revealTimestamp,
        uint256 tokenId,
        uint256 year
    ) external pure returns (string memory) {
        return AudioRenderer.generateAudioHTML(leadPitch, bassPitch, revealTimestamp, tokenId, year);
    }
}
