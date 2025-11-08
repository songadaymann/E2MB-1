// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title ISongAlgorithm
/// @notice Interface for music generation algorithm
interface ISongAlgorithm {
    struct Event {
        int16 pitch;      // MIDI pitch, -1 for rest
        uint16 duration;  // Duration in ticks (480 PPQN)
    }
    
    /// @notice Generate lead and bass events for a given beat
    /// @param beat Beat number (0-indexed)
    /// @param tokenSeed Random seed for generation
    /// @return lead Lead voice event
    /// @return bass Bass voice event
    function generateBeat(uint32 beat, uint32 tokenSeed) external pure returns (Event memory lead, Event memory bass);
    
    /// @notice Generate ABC notation for a beat
    /// @param beat Beat number
    /// @param tokenSeed Random seed
    /// @return abc ABC notation string
    function generateAbcBeat(uint32 beat, uint32 tokenSeed) external pure returns (string memory abc);
}
