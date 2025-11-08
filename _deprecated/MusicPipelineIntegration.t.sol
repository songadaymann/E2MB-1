// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/SongAlgorithm.sol";
import "../src/render/post/MidiToStaff.sol";
import "../src/render/post/NotePositioning.sol";

/**
 * @title MusicPipelineIntegration
 * @notice Integration test for the complete music rendering pipeline:
 *         SongAlgorithm → MidiToStaff → NotePositioning → SVG coordinates
 */
contract MusicPipelineIntegrationTest is Test {
    using MidiToStaff for uint8;

    function setUp() public {}

    /**
     * @notice Test the complete pipeline for a single beat
     */
    function testCompletePipeline() public {
        uint32 beat = 0;
        uint32 tokenSeed = 12345;
        
        // Step 1: Generate music events using MusicLib
        (SongAlgorithm.Event memory leadEvent, SongAlgorithm.Event memory bassEvent) = 
            SongAlgorithm.generateBeat(beat, tokenSeed);
        
        // Verify events were generated
        assertTrue(leadEvent.duration > 0, "Lead event should have duration");
        assertTrue(bassEvent.duration > 0, "Bass event should have duration");
        
        // Step 2: Convert MIDI to staff positions
        MidiToStaff.StaffPosition memory leadPos;
        MidiToStaff.StaffPosition memory bassPos;
        
        // Lead voice
        if (leadEvent.pitch == -1) {
            leadPos = MidiToStaff.midiToStaffPosition(255, leadEvent.duration); // Rest
            assertEq(uint8(leadPos.noteType), uint8(MidiToStaff.NoteType.REST), "Rest should map to REST note type");
        } else {
            // Handle potential negative pitch by checking bounds
            assertTrue(leadEvent.pitch >= 0 && leadEvent.pitch <= 127, "Lead pitch should be valid MIDI range");
            leadPos = MidiToStaff.midiToStaffPosition(uint8(uint16(leadEvent.pitch)), leadEvent.duration);
            assertTrue(uint8(leadPos.noteType) != uint8(MidiToStaff.NoteType.REST), "Note should not be REST");
        }
        
        // Bass voice  
        if (bassEvent.pitch == -1) {
            bassPos = MidiToStaff.midiToStaffPosition(255, bassEvent.duration); // Rest
            assertEq(uint8(bassPos.noteType), uint8(MidiToStaff.NoteType.REST), "Rest should map to REST note type");
        } else {
            // Handle potential negative pitch by checking bounds
            assertTrue(bassEvent.pitch >= 0 && bassEvent.pitch <= 127, "Bass pitch should be valid MIDI range");
            bassPos = MidiToStaff.midiToStaffPosition(uint8(uint16(bassEvent.pitch)), bassEvent.duration);
            assertTrue(uint8(bassPos.noteType) != uint8(MidiToStaff.NoteType.REST), "Note should not be REST");
        }
        
        // Step 3: Convert to SVG coordinates
        uint256 noteX = 350;
        
        // Lead positioning
        if (leadPos.noteType == MidiToStaff.NoteType.REST) {
            NotePositioning.PositionResult memory leadRestPos = 
                NotePositioning.getRestPosition(noteX, _staffStepToY(leadPos.staffStep, leadPos.clef), "quarter-rest");
            assertTrue(leadRestPos.width > 0, "Rest should have width");
            assertTrue(leadRestPos.height > 0, "Rest should have height");
        } else {
            uint256 leadY = _staffStepToY(leadPos.staffStep, leadPos.clef);
            NotePositioning.PositionResult memory leadNotePos = _getNotePosition(leadPos.noteType, noteX, leadY);
            assertTrue(leadNotePos.width > 0, "Note should have width");
            assertTrue(leadNotePos.height > 0, "Note should have height");
        }
        
        // Bass positioning  
        if (bassPos.noteType == MidiToStaff.NoteType.REST) {
            NotePositioning.PositionResult memory bassRestPos = 
                NotePositioning.getRestPosition(noteX, _staffStepToY(bassPos.staffStep, bassPos.clef), "quarter-rest");
            assertTrue(bassRestPos.width > 0, "Rest should have width");
            assertTrue(bassRestPos.height > 0, "Rest should have height");
        } else {
            uint256 bassY = _staffStepToY(bassPos.staffStep, bassPos.clef);
            NotePositioning.PositionResult memory bassNotePos = _getNotePosition(bassPos.noteType, noteX, bassY);
            assertTrue(bassNotePos.width > 0, "Note should have width");
            assertTrue(bassNotePos.height > 0, "Note should have height");
        }
        
        // Pipeline completed successfully if we reach here
        assertTrue(true, "Complete pipeline executed successfully");
    }

    /**
     * @notice Test multiple beats to show variation
     */
    function testMultipleBeats() public {
        uint32 tokenSeed = 42;
        
        for (uint32 beat = 0; beat < 4; beat++) {
            (SongAlgorithm.Event memory lead, SongAlgorithm.Event memory bass) = 
                SongAlgorithm.generateBeat(beat, tokenSeed);
                
            // Verify each beat generates valid events
            assertTrue(lead.duration > 0, "Lead should have duration");
            assertTrue(bass.duration > 0, "Bass should have duration");
            
            // Verify staff mapping works for each event
            if (lead.pitch != -1) {
                assertTrue(lead.pitch >= 0 && lead.pitch <= 127, "Lead pitch should be valid MIDI range");
                MidiToStaff.StaffPosition memory leadPos = 
                    MidiToStaff.midiToStaffPosition(uint8(uint16(lead.pitch)), lead.duration);
                assertTrue(leadPos.staffStep <= 20, "Staff step should be reasonable");
            }
            
            if (bass.pitch != -1) {
                assertTrue(bass.pitch >= 0 && bass.pitch <= 127, "Bass pitch should be valid MIDI range");
                MidiToStaff.StaffPosition memory bassPos = 
                    MidiToStaff.midiToStaffPosition(uint8(uint16(bass.pitch)), bass.duration);
                assertTrue(bassPos.staffStep <= 20, "Staff step should be reasonable");
            }
        }
        
        assertTrue(true, "Multiple beats processed successfully");
    }

    // Helper functions
    
    /**
     * @notice Convert staff step to Y coordinate
     * @param staffStep Staff step (0=top line)
     * @param clef Which clef
     * @return Y coordinate 
     */
    function _staffStepToY(uint8 staffStep, MidiToStaff.Clef clef) private pure returns (uint256) {
        // Using coordinates from StaffUtils.largeGeometry()
        uint256 staffTop = (clef == MidiToStaff.Clef.TREBLE) ? 80 : 320;
        return staffTop + (uint256(staffStep) * 20); // 20px per step
    }
    
    /**
     * @notice Get note position based on note type
     */
    function _getNotePosition(MidiToStaff.NoteType noteType, uint256 noteX, uint256 noteY) 
        private pure returns (NotePositioning.PositionResult memory) 
    {
        if (noteType == MidiToStaff.NoteType.QUARTER_UP || noteType == MidiToStaff.NoteType.QUARTER_DOWN) {
            return (noteType == MidiToStaff.NoteType.QUARTER_UP) ? 
                NotePositioning.getUpNotePosition(noteX, noteY, "quarter-up") :
                NotePositioning.getDownNotePosition(noteX, noteY, "quarter-down");
        } else if (noteType == MidiToStaff.NoteType.HALF_UP || noteType == MidiToStaff.NoteType.HALF_DOWN) {
            return (noteType == MidiToStaff.NoteType.HALF_UP) ? 
                NotePositioning.getUpNotePosition(noteX, noteY, "half-up") :
                NotePositioning.getDownNotePosition(noteX, noteY, "half-down");
        } else if (noteType == MidiToStaff.NoteType.EIGHTH_UP || noteType == MidiToStaff.NoteType.EIGHTH_DOWN) {
            return (noteType == MidiToStaff.NoteType.EIGHTH_UP) ? 
                NotePositioning.getUpNotePosition(noteX, noteY, "eighth-up") :
                NotePositioning.getDownNotePosition(noteX, noteY, "eighth-down");
        } else if (noteType == MidiToStaff.NoteType.SIXTEENTH_UP || noteType == MidiToStaff.NoteType.SIXTEENTH_DOWN) {
            return (noteType == MidiToStaff.NoteType.SIXTEENTH_UP) ? 
                NotePositioning.getUpNotePosition(noteX, noteY, "sixteenth-up") :
                NotePositioning.getDownNotePosition(noteX, noteY, "sixteenth-down");
        } else if (noteType == MidiToStaff.NoteType.WHOLE) {
            return NotePositioning.getWholeNotePosition(noteX, noteY);
        }
        
        // Fallback
        return NotePositioning.getUpNotePosition(noteX, noteY, "quarter-up");
    }
    
    /**
     * @notice Check if duration represents a dotted note
     */
    function _isDottedDuration(uint16 duration) private pure returns (bool) {
        // Common dotted durations: 720 (dotted quarter), 1440 (dotted half), etc.
        return (duration == 720 || duration == 1440 || duration == 360 || duration == 2880);
    }
}
