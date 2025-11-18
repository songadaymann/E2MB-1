// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/IMidiToStaff.sol";

contract MidiToStaff is IMidiToStaff {
    
    // Staff step references (from Python implementation)
    int256 constant TREBLE_C4_STEP = 10;  // C4 position on treble staff
    int256 constant BASS_C4_STEP = -2;    // C4 position on bass staff (below staff)
    
    // Clef selection thresholds  
    uint8 constant TREBLE_THRESHOLD = 55; // G3 and above go to treble clef
    uint8 constant BASS_THRESHOLD = 54;   // F#3 and below go to bass clef
    
    // Note duration mapping (from MusicLib durations to note types)
    uint16 constant QUARTER_DURATION = 480;  // Quarter note
    uint16 constant HALF_DURATION = 960;     // Half note  
    uint16 constant EIGHTH_DURATION = 240;   // Eighth note
    uint16 constant WHOLE_DURATION = 1920;   // Whole note
    uint16 constant SIXTEENTH_DURATION = 120; // Sixteenth note
    
    function _pitchClassToStep(uint8 pitchClass) private pure returns (uint8) {
        // C, C#, D, D#, E, F, F#, G, G#, A, A#, B
        if (pitchClass == 0 || pitchClass == 1) return 0; // C, C#
        if (pitchClass == 2 || pitchClass == 3) return 1; // D, D#
        if (pitchClass == 4) return 2; // E
        if (pitchClass == 5 || pitchClass == 6) return 3; // F, F#
        if (pitchClass == 7 || pitchClass == 8) return 4; // G, G#
        if (pitchClass == 9) return 5; // A
        if (pitchClass == 10 || pitchClass == 11) return 6; // A#/Bb, B
        return 0; // Fallback
    }
    
    // Enums and structs are defined in IMidiToStaff interface
    
    function midiToStaffPosition(uint8 midiNote, uint16 duration) 
        external 
        pure 
        override
        returns (StaffPosition memory) 
    {
        // Handle rests (MIDI note -1 represented as 255)
        if (midiNote == 255) {
            return StaffPosition({
                clef: Clef.TREBLE,  // Default to treble for rests
                staffStep: 4,       // Middle of staff
                noteType: NoteType.REST,
                onLine: true        // Rests treated as on-line for positioning
            });
        }
        
        // Determine clef
        Clef clef = (midiNote >= TREBLE_THRESHOLD) ? Clef.TREBLE : Clef.BASS;
        
        // Convert MIDI to staff step using diatonic conversion
        uint8 staffStep = _midiToStaffStep(midiNote, clef);
        
        // Determine note type and stem direction
        NoteType noteType = _getDurationNoteType(duration, staffStep, clef);
        
        // Determine if note is on line (even steps) or space (odd steps)
        bool onLine = (staffStep % 2 == 0);
        
        return StaffPosition({
            clef: clef,
            staffStep: staffStep,
            noteType: noteType,
            onLine: onLine
        });
    }
    
    function _midiToStaffStep(uint8 midiNote, Clef clef) private pure returns (uint8) {
        // OCTAVE SHIFT: Apply only to bass clef for better positioning
        // Bass notes (MIDI 24-46 = C1-Bb2) are very low, shift up 1 octave for readability
        // Treble notes (MIDI 48-70 = C3-Bb4) use raw values
        uint8 displayMidi;
        if (clef == Clef.BASS) {
            displayMidi = midiNote + 12;  // Shift bass up 1 octave
        } else {
            displayMidi = midiNote;  // Treble uses raw MIDI values
        }
        
        // Get octave and pitch class using the shifted MIDI value
        // Note: MIDI 60 = C4, so MIDI octave 5 = musical octave 4
        // We need to subtract 1 to get musical octave number
        uint8 midiOctave = displayMidi / 12;
        uint8 pitchClass = displayMidi % 12;
        
        // Convert MIDI octave to musical octave  
        // MIDI 0-11 = octave -1, MIDI 12-23 = octave 0, etc.
        int256 musicalOctave = int256(uint256(midiOctave)) - 1;
        
        // Convert to diatonic step within octave
        uint8 diatonicStep = _pitchClassToStep(pitchClass);
        
        // Calculate absolute diatonic step (C4 = octave 4, step 0 within octave)
        int256 absoluteStep = musicalOctave * 7 + int256(uint256(diatonicStep));
        
        // Convert to staff position relative to C4
        int256 c4AbsoluteStep = 4 * 7; // C4 absolute step
        int256 stepsFromC4 = absoluteStep - c4AbsoluteStep;
        
        int256 staffStep;
        if (clef == Clef.TREBLE) {
            staffStep = TREBLE_C4_STEP - stepsFromC4;
        } else {
            staffStep = BASS_C4_STEP - stepsFromC4;
        }
        
        // Clamp to reasonable range (allow some ledger lines)
        if (staffStep < 0) staffStep = 0;
        if (staffStep > 20) staffStep = 20;
        
        return uint8(uint256(staffStep));
    }
    
    function _getDurationNoteType(uint16 duration, uint8 staffStep, Clef clef) 
        private 
        pure 
        returns (NoteType) 
    {
        // Determine base note type from duration
        NoteType baseType;
        if (duration >= WHOLE_DURATION) {
            return NoteType.WHOLE; // Whole notes have no stems
        } else if (duration >= HALF_DURATION) {
            baseType = NoteType.HALF_UP; // Will adjust for stem direction
        } else if (duration >= QUARTER_DURATION) {
            baseType = NoteType.QUARTER_UP; // Will adjust for stem direction
        } else if (duration >= EIGHTH_DURATION) {
            baseType = NoteType.EIGHTH_UP; // Will adjust for stem direction
        } else {
            baseType = NoteType.SIXTEENTH_UP; // Will adjust for stem direction
        }
        
        // Apply stem direction rules (below middle line → stems up)
        uint8 middleLine = (clef == Clef.TREBLE) ? 4 : 4; // B4 line for treble, D3 line for bass
        
        bool stemUp = (staffStep >= middleLine);
        
        // Convert base type to correct stem direction
        if (baseType == NoteType.QUARTER_UP) {
            return stemUp ? NoteType.QUARTER_UP : NoteType.QUARTER_DOWN;
        } else if (baseType == NoteType.HALF_UP) {
            return stemUp ? NoteType.HALF_UP : NoteType.HALF_DOWN;
        } else if (baseType == NoteType.EIGHTH_UP) {
            return stemUp ? NoteType.EIGHTH_UP : NoteType.EIGHTH_DOWN;
        } else if (baseType == NoteType.SIXTEENTH_UP) {
            return stemUp ? NoteType.SIXTEENTH_UP : NoteType.SIXTEENTH_DOWN;
        }
        
        return baseType; // Fallback
    }
    
    function noteTypeToString(NoteType noteType) external pure override returns (string memory) {
        if (noteType == NoteType.QUARTER_UP) return "quarter-up";
        if (noteType == NoteType.QUARTER_DOWN) return "quarter-down";
        if (noteType == NoteType.HALF_UP) return "half-up";
        if (noteType == NoteType.HALF_DOWN) return "half-down";
        if (noteType == NoteType.EIGHTH_UP) return "eighth-up";
        if (noteType == NoteType.EIGHTH_DOWN) return "eighth-down";
        if (noteType == NoteType.SIXTEENTH_UP) return "sixteenth-up";
        if (noteType == NoteType.SIXTEENTH_DOWN) return "sixteenth-down";
        if (noteType == NoteType.WHOLE) return "whole";
        if (noteType == NoteType.REST) return "quarter-rest"; // Default rest type
        
        return "quarter-up"; // Fallback
    }
    
    /**
     * @notice Convert clef enum to string for debugging
     * @param clef Clef enum value
     * @return String representation
     */
    function clefToString(Clef clef) external pure override returns (string memory) {
        return (clef == Clef.TREBLE) ? "treble" : "bass";
    }
}
