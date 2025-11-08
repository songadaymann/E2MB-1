// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title INotePositioning
/// @notice Interface for calculating SVG positions of notes, rests, and dots
interface INotePositioning {
    struct PositionResult {
        int256 offsetX;    // SVG x coordinate
        int256 offsetY;    // SVG y coordinate
        uint256 width;     // Display width
        uint256 height;    // Display height
    }
    
    /// @notice Get position for up-stemmed notes
    function getUpNotePosition(uint256 noteX, uint256 noteY, string memory noteType) external pure returns (PositionResult memory);
    
    /// @notice Get position for down-stemmed notes
    function getDownNotePosition(uint256 noteX, uint256 noteY, string memory noteType) external pure returns (PositionResult memory);
    
    /// @notice Get position for whole notes
    function getWholeNotePosition(uint256 noteX, uint256 noteY) external pure returns (PositionResult memory);
    
    /// @notice Get position for rests
    function getRestPosition(uint256 restX, uint256 restY, string memory restType) external pure returns (PositionResult memory);
    
    /// @notice Get position for dots
    function getDotPosition(uint256 noteX, uint256 noteY, bool onLine) external pure returns (PositionResult memory);
    
    /// @notice Get ledger lines for notes outside staff range
    function getLedgerLines(uint256 noteX, uint256 staffTop, int8 staffStep) external pure returns (string memory);
}
