// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../render/post/MusicRenderer.sol";

/**
 * @title MusicRendererContract
 * @notice External contract wrapper for MusicRenderer library
 * @dev Allows MillenniumSongTestnet to call rendering externally to save size
 */
contract MusicRendererContract {
    /**
     * @notice Render beat data to SVG (external call)
     */
    function render(MusicRenderer.BeatData calldata data) external pure returns (string memory) {
        return MusicRenderer.render(data);
    }
}
