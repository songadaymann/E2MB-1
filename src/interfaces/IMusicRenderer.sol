// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IMusicRenderer
/// @notice Interface for complete music SVG rendering
interface IMusicRenderer {
    struct BeatData {
        uint256 tokenId;
        uint256 beat;
        uint256 year;
        int16 leadPitch;      // MIDI pitch, -1 for rest
        uint16 leadDuration;  // Duration in ticks
        int16 bassPitch;      // MIDI pitch, -1 for rest
        uint16 bassDuration;  // Duration in ticks
    }
    
    /// @notice Render complete SVG for a beat
    /// @param data Beat data to render
    /// @return Complete SVG string (600x600, white bg, black notation)
    function render(BeatData memory data) external view returns (string memory);
}
