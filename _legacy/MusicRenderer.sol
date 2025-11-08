// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./StaffUtils.sol";
import "./SvgMusicGlyphs.sol";
import "./MidiToStaff.sol";
import "./NotePositioning.sol";

/// @title MusicRenderer
/// @notice Complete post-reveal SVG music notation renderer
/// @dev Renders musical notes on grand staff from MIDI pitch/duration data
library MusicRenderer {
    using Strings for uint256;

    /// @notice Input data for rendering a beat/token
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
    /// @return Complete SVG string
    function render(BeatData memory data) internal pure returns (string memory) {
        StaffUtils.StaffGeometry memory geom = StaffUtils.largeGeometry();
        
        // Hardcoded theme: white background, black notes (matches production design)
        string memory bgColor = "#fff";
        string memory fgColor = "#000";
        
        // SVG header with 600x600 canvas
        string memory header = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" ',
            'viewBox="0 0 600 600" width="600" height="600">',
            '<defs>', SvgMusicGlyphs.defsMinimal(), '</defs>',
            '<rect width="100%" height="100%" fill="', bgColor, '"/>'
        ));
        
        // Generate grand staff (treble + bass with clefs)
        string memory grandStaff = StaffUtils.generateGrandStaff(geom, fgColor, fgColor);
        
        // Center position for notes
        uint256 noteX = 300;
        
        string memory notes = "";
        
        // Process lead note (or rest)
        MidiToStaff.StaffPosition memory leadPos = MidiToStaff.midiToStaffPosition(
            data.leadPitch >= 0 ? uint8(uint16(data.leadPitch)) : 255,  // 255 = rest
            data.leadDuration
        );
        uint256 leadY = _getStaffY(leadPos.clef, int8(leadPos.staffStep), geom);
        string memory leadSymbol = MidiToStaff.noteTypeToString(leadPos.noteType);
        
        // Check if this is a dotted note (duration * 2 / 3 gives base duration)
        bool isDotted = _isDottedDuration(data.leadDuration);
        
        if (leadPos.noteType != MidiToStaff.NoteType.REST) {
            // Add ledger lines if needed
            string memory leadLedgers = NotePositioning.getLedgerLines(
                noteX, 
                geom.trebleTop, 
                int8(leadPos.staffStep)
            );
            notes = string(abi.encodePacked(notes, leadLedgers));
            
            // Render note
            NotePositioning.PositionResult memory leadNote = _getPositionForNoteType(
                leadPos.noteType, noteX, leadY, leadSymbol
            );
            
            notes = string(abi.encodePacked(
                notes,
                '<use xlink:href="#', leadSymbol, '" href="#', leadSymbol, '" ',
                'x="', _intToString(leadNote.offsetX), '" ',
                'y="', _intToString(leadNote.offsetY), '" ',
                'width="', leadNote.width.toString(), '" ',
                'height="', leadNote.height.toString(), '" ',
                'fill="', fgColor, '"/> '
            ));
            
            // Add dot if dotted note
            if (isDotted) {
                // Pass the TARGET position (same as note positioning input)
                // getDotPosition calculates its own offsets just like note positioning does
                NotePositioning.PositionResult memory dot = NotePositioning.getDotPosition(
                    noteX, 
                    leadY, 
                    leadPos.onLine
                );
                notes = string(abi.encodePacked(
                    notes,
                    '<use xlink:href="#dot" href="#dot" ',
                    'x="', _intToString(dot.offsetX), '" ',
                    'y="', _intToString(dot.offsetY), '" ',
                    'width="', dot.width.toString(), '" ',
                    'height="', dot.height.toString(), '" ',
                    'fill="', fgColor, '"/> '
                ));
            }
        } else {
            // Render rest - centered in treble staff at middle position
            uint256 restY = geom.trebleTop + 80;  // Middle of treble staff
            string memory restSymbol = _restTypeToString(leadPos.noteType);
            
            NotePositioning.PositionResult memory leadRest = NotePositioning.getRestPosition(
                noteX + 38, restY, restSymbol  // +38 to align with note heads
            );
            
            notes = string(abi.encodePacked(
                notes,
                '<use xlink:href="#', restSymbol, '" href="#', restSymbol, '" ',
                'x="', _intToString(leadRest.offsetX), '" ',
                'y="', _intToString(leadRest.offsetY), '" ',
                'width="', leadRest.width.toString(), '" ',
                'height="', leadRest.height.toString(), '" ',
                'fill="', fgColor, '"/> '
            ));
        }
        
        // Process bass note (or rest)
        MidiToStaff.StaffPosition memory bassPos = MidiToStaff.midiToStaffPosition(
            data.bassPitch >= 0 ? uint8(uint16(data.bassPitch)) : 255,  // 255 = rest
            data.bassDuration
        );
        uint256 bassY = _getStaffY(bassPos.clef, int8(bassPos.staffStep), geom);
        string memory bassSymbol = MidiToStaff.noteTypeToString(bassPos.noteType);
        
        // Check if this is a dotted note
        bool bassDotted = _isDottedDuration(data.bassDuration);
        
        if (bassPos.noteType != MidiToStaff.NoteType.REST) {
            // Add ledger lines if needed
            string memory bassLedgers = NotePositioning.getLedgerLines(
                noteX, 
                geom.bassTop, 
                int8(bassPos.staffStep)
            );
            notes = string(abi.encodePacked(notes, bassLedgers));
            
            // Render note
            NotePositioning.PositionResult memory bassNote = _getPositionForNoteType(
                bassPos.noteType, noteX, bassY, bassSymbol
            );
            
            notes = string(abi.encodePacked(
                notes,
                '<use xlink:href="#', bassSymbol, '" href="#', bassSymbol, '" ',
                'x="', _intToString(bassNote.offsetX), '" ',
                'y="', _intToString(bassNote.offsetY), '" ',
                'width="', bassNote.width.toString(), '" ',
                'height="', bassNote.height.toString(), '" ',
                'fill="', fgColor, '"/> '
            ));
            
            // Add dot if dotted note
            if (bassDotted) {
                // Pass the staff target position (noteX, bassY) directly
                // The note head is centered at this position by design
                NotePositioning.PositionResult memory dot = NotePositioning.getDotPosition(
                    noteX, 
                    bassY, 
                    bassPos.onLine
                );
                notes = string(abi.encodePacked(
                    notes,
                    '<use xlink:href="#dot" href="#dot" ',
                    'x="', _intToString(dot.offsetX), '" ',
                    'y="', _intToString(dot.offsetY), '" ',
                    'width="', dot.width.toString(), '" ',
                    'height="', dot.height.toString(), '" ',
                    'fill="', fgColor, '"/> '
                ));
            }
        } else {
            // Render rest - centered in bass staff at middle position
            uint256 restY = geom.bassTop + 80;  // Middle of bass staff
            string memory restSymbol = _restTypeToString(bassPos.noteType);
            
            NotePositioning.PositionResult memory bassRest = NotePositioning.getRestPosition(
                noteX + 38, restY, restSymbol  // +38 to align with note heads  
            );
            
            notes = string(abi.encodePacked(
                notes,
                '<use xlink:href="#', restSymbol, '" href="#', restSymbol, '" ',
                'x="', _intToString(bassRest.offsetX), '" ',
                'y="', _intToString(bassRest.offsetY), '" ',
                'width="', bassRest.width.toString(), '" ',
                'height="', bassRest.height.toString(), '" ',
                'fill="', fgColor, '"/> '
            ));
        }
        
        // No metadata text overlays - clean staff only
        
        return string(abi.encodePacked(
            header,
            grandStaff,
            notes,
            '</svg>'
        ));
    }
    
    /// @notice Calculate Y coordinate on staff from clef and staff step
    function _getStaffY(MidiToStaff.Clef clef, int8 staffStep, StaffUtils.StaffGeometry memory geom) 
        private pure returns (uint256) 
    {
        if (clef == MidiToStaff.Clef.TREBLE) {
            return uint256(int256(uint256(geom.trebleTop)) + int256(staffStep) * 20);
        } else {
            return uint256(int256(uint256(geom.bassTop)) + int256(staffStep) * 20);
        }
    }
    
    /// @notice Get positioning for a note based on its type (up/down stem, whole, etc.)
    function _getPositionForNoteType(
        MidiToStaff.NoteType noteType,
        uint256 x,
        uint256 y,
        string memory symbolId
    ) private pure returns (NotePositioning.PositionResult memory) {
        if (noteType == MidiToStaff.NoteType.QUARTER_UP || 
            noteType == MidiToStaff.NoteType.HALF_UP ||
            noteType == MidiToStaff.NoteType.EIGHTH_UP ||
            noteType == MidiToStaff.NoteType.SIXTEENTH_UP) {
            return NotePositioning.getUpNotePosition(x, y, symbolId);
        } else if (noteType == MidiToStaff.NoteType.QUARTER_DOWN ||
                   noteType == MidiToStaff.NoteType.HALF_DOWN ||
                   noteType == MidiToStaff.NoteType.EIGHTH_DOWN ||
                   noteType == MidiToStaff.NoteType.SIXTEENTH_DOWN) {
            return NotePositioning.getDownNotePosition(x, y, symbolId);
        } else if (noteType == MidiToStaff.NoteType.WHOLE) {
            return NotePositioning.getWholeNotePosition(x, y);
        } else {
            // Fallback
            return NotePositioning.getUpNotePosition(x, y, "quarter-up");
        }
    }
    
    /// @notice Convert signed integer to string
    function _intToString(int256 value) private pure returns (string memory) {
        if (value >= 0) {
            return uint256(value).toString();
        } else {
            return string(abi.encodePacked("-", uint256(-value).toString()));
        }
    }
    
    /// @notice Check if a duration represents a dotted note
    /// @dev Dotted notes have duration = base * 1.5
    /// Common dotted durations: 720 (dotted quarter), 360 (dotted eighth), 180 (dotted sixteenth)
    function _isDottedDuration(uint16 duration) private pure returns (bool) {
        // Check common dotted durations
        if (duration == 720) return true;  // Dotted quarter (480 * 1.5)
        if (duration == 360) return true;  // Dotted eighth (240 * 1.5)
        if (duration == 1440) return true; // Dotted half (960 * 1.5)
        if (duration == 180) return true;  // Dotted sixteenth (120 * 1.5)
        return false;
    }
    
    /// @notice Convert REST note type to rest symbol string
    function _restTypeToString(MidiToStaff.NoteType noteType) private pure returns (string memory) {
        // All REST types map to rest-quarter for now
        // TODO: Add duration-based rest types if needed
        return "rest-quarter";
    }

}
