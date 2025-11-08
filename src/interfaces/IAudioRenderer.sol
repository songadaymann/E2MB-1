// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IAudioRenderer
/// @notice Interface for generating HTML audio player with embedded SVG
interface IAudioRenderer {
    /// @notice Generate HTML audio player with WebAudio synthesis and embedded SVG
    /// @param leadPitch Lead MIDI pitch (-1 for rest)
    /// @param bassPitch Bass MIDI pitch (-1 for rest)
    /// @param revealTimestamp Unix timestamp of reveal
    /// @param svgContent SVG markup to display (not data URI, just raw SVG)
    /// @return data:text/html;base64 URI
    function generateAudioHTML(
        int16 leadPitch,
        int16 bassPitch,
        uint256 revealTimestamp,
        string memory svgContent
    ) external pure returns (string memory);
}
