// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/render/post/MidiToStaff.sol";

contract MidiToStaffTest is Test {
    using MidiToStaff for uint8;

    function setUp() public {}

    function testClefSelection() public {
        // Test treble clef threshold (Bb3 = MIDI 58 and above)
        MidiToStaff.StaffPosition memory pos1 = MidiToStaff.midiToStaffPosition(58, 480); // Bb3
        assertEq(uint8(pos1.clef), uint8(MidiToStaff.Clef.TREBLE), "Bb3 should be treble clef");
        
        MidiToStaff.StaffPosition memory pos2 = MidiToStaff.midiToStaffPosition(60, 480); // C4
        assertEq(uint8(pos2.clef), uint8(MidiToStaff.Clef.TREBLE), "C4 should be treble clef");
        
        // Test bass clef threshold (A3 = MIDI 57 and below)
        MidiToStaff.StaffPosition memory pos3 = MidiToStaff.midiToStaffPosition(57, 480); // A3
        assertEq(uint8(pos3.clef), uint8(MidiToStaff.Clef.BASS), "A3 should be bass clef");
        
        MidiToStaff.StaffPosition memory pos4 = MidiToStaff.midiToStaffPosition(48, 480); // C3
        assertEq(uint8(pos4.clef), uint8(MidiToStaff.Clef.BASS), "C3 should be bass clef");
    }

    function testC4ReferencePositions() public {
        // Test C4 on treble clef (should be step 10)
        MidiToStaff.StaffPosition memory trebleC4 = MidiToStaff.midiToStaffPosition(60, 480); // C4
        assertEq(trebleC4.staffStep, 10, "C4 should be at treble step 10");
        assertEq(uint8(trebleC4.clef), uint8(MidiToStaff.Clef.TREBLE), "C4 should be treble clef");
        
        // Test C4 on bass clef (force it by using C3 which maps to same relative position)
        // C3 = MIDI 48, should map to bass clef step 4 (middle line, 7 steps down from our reference)
        MidiToStaff.StaffPosition memory bassC3 = MidiToStaff.midiToStaffPosition(48, 480); // C3
        assertEq(uint8(bassC3.clef), uint8(MidiToStaff.Clef.BASS), "C3 should be bass clef");
    }

    function testDurationMapping() public {
        uint8 testNote = 60; // C4
        
        // Test whole note (no stem)
        MidiToStaff.StaffPosition memory whole = MidiToStaff.midiToStaffPosition(testNote, 1920);
        assertEq(uint8(whole.noteType), uint8(MidiToStaff.NoteType.WHOLE), "1920 ticks should be whole note");
        
        // Test half note
        MidiToStaff.StaffPosition memory half = MidiToStaff.midiToStaffPosition(testNote, 960);
        assertTrue(
            uint8(half.noteType) == uint8(MidiToStaff.NoteType.HALF_UP) || 
            uint8(half.noteType) == uint8(MidiToStaff.NoteType.HALF_DOWN),
            "960 ticks should be half note"
        );
        
        // Test quarter note
        MidiToStaff.StaffPosition memory quarter = MidiToStaff.midiToStaffPosition(testNote, 480);
        assertTrue(
            uint8(quarter.noteType) == uint8(MidiToStaff.NoteType.QUARTER_UP) || 
            uint8(quarter.noteType) == uint8(MidiToStaff.NoteType.QUARTER_DOWN),
            "480 ticks should be quarter note"
        );
        
        // Test eighth note
        MidiToStaff.StaffPosition memory eighth = MidiToStaff.midiToStaffPosition(testNote, 240);
        assertTrue(
            uint8(eighth.noteType) == uint8(MidiToStaff.NoteType.EIGHTH_UP) || 
            uint8(eighth.noteType) == uint8(MidiToStaff.NoteType.EIGHTH_DOWN),
            "240 ticks should be eighth note"
        );
        
        // Test sixteenth note
        MidiToStaff.StaffPosition memory sixteenth = MidiToStaff.midiToStaffPosition(testNote, 120);
        assertTrue(
            uint8(sixteenth.noteType) == uint8(MidiToStaff.NoteType.SIXTEENTH_UP) || 
            uint8(sixteenth.noteType) == uint8(MidiToStaff.NoteType.SIXTEENTH_DOWN),
            "120 ticks should be sixteenth note"
        );
    }

    function testStemDirection() public {
        // Test treble clef stem directions
        // High notes (above middle line B4 = step 4) should have stems down
        MidiToStaff.StaffPosition memory highNote = MidiToStaff.midiToStaffPosition(72, 480); // C5, should be high on treble
        assertTrue(
            uint8(highNote.noteType) == uint8(MidiToStaff.NoteType.QUARTER_DOWN),
            "High treble notes should have stems down"
        );
        
        // Low notes (below middle line B4 = step 4) should have stems up  
        MidiToStaff.StaffPosition memory lowNote = MidiToStaff.midiToStaffPosition(64, 480); // E4, should be low on treble
        assertTrue(
            uint8(lowNote.noteType) == uint8(MidiToStaff.NoteType.QUARTER_UP),
            "Low treble notes should have stems up"
        );
    }

    function testRestHandling() public {
        // Test rest (MIDI -1 represented as 255)
        MidiToStaff.StaffPosition memory rest = MidiToStaff.midiToStaffPosition(255, 480);
        assertEq(uint8(rest.noteType), uint8(MidiToStaff.NoteType.REST), "255 should map to rest");
        assertEq(uint8(rest.clef), uint8(MidiToStaff.Clef.TREBLE), "Rests default to treble clef");
        assertEq(rest.staffStep, 4, "Rests positioned at middle of staff");
        assertTrue(rest.onLine, "Rests treated as on-line for positioning");
    }

    function testOnLineDetection() public {
        // Even steps should be on lines
        MidiToStaff.StaffPosition memory lineNote = MidiToStaff.midiToStaffPosition(71, 480); // B4, should be on line
        assertTrue(lineNote.onLine == (lineNote.staffStep % 2 == 0), "Even steps should be on lines");
        
        // Odd steps should be in spaces
        MidiToStaff.StaffPosition memory spaceNote = MidiToStaff.midiToStaffPosition(69, 480); // A4, should be in space
        assertTrue(spaceNote.onLine == (spaceNote.staffStep % 2 == 0), "Odd steps should be in spaces");
    }

    function testNoteTypeToString() public {
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.QUARTER_UP), "quarter-up");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.QUARTER_DOWN), "quarter-down");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.HALF_UP), "half-up");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.HALF_DOWN), "half-down");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.EIGHTH_UP), "eighth-up");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.EIGHTH_DOWN), "eighth-down");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.SIXTEENTH_UP), "sixteenth-up");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.SIXTEENTH_DOWN), "sixteenth-down");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.WHOLE), "whole");
        assertEq(MidiToStaff.noteTypeToString(MidiToStaff.NoteType.REST), "quarter-rest");
    }

    function testClefToString() public {
        assertEq(MidiToStaff.clefToString(MidiToStaff.Clef.TREBLE), "treble");
        assertEq(MidiToStaff.clefToString(MidiToStaff.Clef.BASS), "bass");
    }

    function testPitchClassMapping() public {
        // Test octave relationships - notes one octave apart should be 7 staff steps apart
        MidiToStaff.StaffPosition memory c4 = MidiToStaff.midiToStaffPosition(60, 480); // C4
        MidiToStaff.StaffPosition memory c5 = MidiToStaff.midiToStaffPosition(72, 480); // C5
        
        // C5 should be 7 steps higher (lower staff step number) than C4
        assertEq(c4.staffStep, c5.staffStep + 7, "Octave relationship should be 7 staff steps");
    }

    function testMidiRangeFromPython() public view {
        // Test the MIDI ranges observed in Python implementation
        // Treble: 48-71, Bass: 24-47
        
        // Test boundaries
        MidiToStaff.StaffPosition memory midi48 = MidiToStaff.midiToStaffPosition(48, 480); // C3
        MidiToStaff.StaffPosition memory midi71 = MidiToStaff.midiToStaffPosition(71, 480); // B4
        MidiToStaff.StaffPosition memory midi24 = MidiToStaff.midiToStaffPosition(24, 480); // C1
        MidiToStaff.StaffPosition memory midi47 = MidiToStaff.midiToStaffPosition(47, 480); // B2
        
        // Log for debugging (these will show in forge test -vv output)
        console.log("MIDI 48 (C3): clef=%s, step=%d", 
                   MidiToStaff.clefToString(midi48.clef), midi48.staffStep);
        console.log("MIDI 71 (B4): clef=%s, step=%d", 
                   MidiToStaff.clefToString(midi71.clef), midi71.staffStep);
        console.log("MIDI 24 (C1): clef=%s, step=%d", 
                   MidiToStaff.clefToString(midi24.clef), midi24.staffStep);
        console.log("MIDI 47 (B2): clef=%s, step=%d", 
                   MidiToStaff.clefToString(midi47.clef), midi47.staffStep);
    }
}
