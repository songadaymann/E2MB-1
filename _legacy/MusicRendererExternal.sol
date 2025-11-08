// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../render/post/MusicRenderer.sol";

/**
 * @title MusicRendererExternal
 * @notice Standalone contract for music rendering (external calls to save main contract size)
 * @dev Wraps MusicRenderer library with external functions
 */
contract MusicRendererExternal {
    /**
     * @notice Render beat data to SVG staff notation
     * @dev External/pure so it can be deployed separately and called cross-contract
     */
    function render(MusicRenderer.BeatData calldata data) external pure returns (string memory) {
        return MusicRenderer.render(data);
    }
}
