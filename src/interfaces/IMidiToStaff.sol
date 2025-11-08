// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IMidiToStaff
/// @notice Interface for MIDI to staff notation conversion
interface IMidiToStaff {
    enum Clef { TREBLE, BASS }
    enum NoteType { QUARTER_UP, QUARTER_DOWN, HALF_UP, HALF_DOWN, EIGHTH_UP, EIGHTH_DOWN, 
                   SIXTEENTH_UP, SIXTEENTH_DOWN, WHOLE, REST }
    
    struct StaffPosition {
        Clef clef;           // Which clef to use
        uint8 staffStep;     // Staff position (0=top line, 2/4/6/8=lines, 1/3/5/7=spaces)
        NoteType noteType;   // Which note symbol to use
        bool onLine;         // True if note is on a staff line (for dot positioning)
    }
    
    /// @notice Convert MIDI pitch and duration to staff position
    /// @param midiNote MIDI note number (0-127, 255 for rest)
    /// @param duration Duration in ticks (480 = quarter note at 480 PPQN)
    /// @return Staff position with clef, step, note type, and onLine flag
    function midiToStaffPosition(uint8 midiNote, uint16 duration) external pure returns (StaffPosition memory);
    
    /// @notice Convert note type enum to string (for symbol ID)
    /// @param noteType Note type enum
    /// @return String like "quarter-up", "half-down", etc.
    function noteTypeToString(NoteType noteType) external pure returns (string memory);
    
    /// @notice Convert clef enum to string
    /// @param clef Clef enum
    /// @return String "treble" or "bass"
    function clefToString(Clef clef) external pure returns (string memory);
}
