// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ISvgMusicGlyphs
/// @notice Interface for SVG music symbol definitions
interface ISvgMusicGlyphs {
    /// @notice Returns all music symbol definitions as SVG <symbol> elements
    /// @dev Should be placed inside <defs> tag
    /// @return SVG string containing all symbol definitions
    function defsMinimal() external pure returns (string memory);
}
