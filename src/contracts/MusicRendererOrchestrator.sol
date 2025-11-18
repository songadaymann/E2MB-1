// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../interfaces/IMusicRenderer.sol";
import "../interfaces/IStaffUtils.sol";
import "../interfaces/ISvgMusicGlyphs.sol";
import "../interfaces/IMidiToStaff.sol";
import "../interfaces/INotePositioning.sol";

contract MusicRendererOrchestrator is IMusicRenderer, Ownable {
    using Strings for uint256;
    
    IStaffUtils public staff;
    ISvgMusicGlyphs public glyphs;
    IMidiToStaff public midi;
    INotePositioning public positioning;
    
    bool public frozen;
    
    event ModulesUpdated(address staff, address glyphs, address midi, address positioning);
    event Frozen();
    
    modifier notFrozen() {
        require(!frozen, "Frozen");
        _;
    }
    
    constructor(
        address _staff,
        address _glyphs,
        address _midi,
        address _positioning
    ) Ownable(msg.sender) {
        staff = IStaffUtils(_staff);
        glyphs = ISvgMusicGlyphs(_glyphs);
        midi = IMidiToStaff(_midi);
        positioning = INotePositioning(_positioning);
    }
    
    function setModules(
        address _staff,
        address _glyphs,
        address _midi,
        address _positioning
    ) external onlyOwner notFrozen {
        staff = IStaffUtils(_staff);
        glyphs = ISvgMusicGlyphs(_glyphs);
        midi = IMidiToStaff(_midi);
        positioning = INotePositioning(_positioning);
        emit ModulesUpdated(_staff, _glyphs, _midi, _positioning);
    }
    
    function freeze() external onlyOwner {
        frozen = true;
        emit Frozen();
    }
    
    function render(BeatData memory data) external view override returns (string memory) {
        IStaffUtils.StaffGeometry memory geom = staff.largeGeometry();
        
        string memory bgColor = "#000";
        string memory fgColor = "#fff";
        
        string memory header = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" ',
            'viewBox="0 0 600 600" width="600" height="600">',
            '<defs>', glyphs.defsMinimal(), '</defs>',
            '<rect width="100%" height="100%" fill="', bgColor, '"/>'
        ));
        
        string memory grandStaff = staff.generateGrandStaff(geom, fgColor, fgColor);
        
        uint256 noteX = 300;
        
        string memory notes = "";
        
        IMidiToStaff.StaffPosition memory leadPos = midi.midiToStaffPosition(
            data.leadPitch >= 0 ? uint8(uint16(data.leadPitch)) : 255,  // 255 = rest
            data.leadDuration
        );
        uint256 leadY = _getStaffY(leadPos.clef, int8(leadPos.staffStep), geom);
        string memory leadSymbol = midi.noteTypeToString(leadPos.noteType);
        
        bool isDotted = _isDottedDuration(data.leadDuration);
        
        if (leadPos.noteType != IMidiToStaff.NoteType.REST) {
            string memory leadLedgers = positioning.getLedgerLines(
                noteX, 
                geom.trebleTop, 
                int8(leadPos.staffStep)
            );
            notes = string(abi.encodePacked(notes, leadLedgers));
            
            INotePositioning.PositionResult memory leadNote = _getPositionForNoteType(
                leadPos.noteType, noteX, leadY, leadSymbol
            );
            
            notes = string(abi.encodePacked(
                notes,
                '<use xlink:href="#', leadSymbol, '" href="#', leadSymbol, '" ',
                'x="', _intToString(leadNote.offsetX), '" ',
                'y="', _intToString(leadNote.offsetY), '" ',
                'width="', leadNote.width.toString(), '" ',
                'height="', leadNote.height.toString(), '"/> '
            ));
            
            if (isDotted) {
                INotePositioning.PositionResult memory dot = positioning.getDotPosition(
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
            uint256 restY = geom.trebleTop + 80;
            string memory restSymbol = _restTypeToString(leadPos.noteType);
            
            INotePositioning.PositionResult memory leadRest = positioning.getRestPosition(
                noteX + 38, restY, restSymbol
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
        
        IMidiToStaff.StaffPosition memory bassPos = midi.midiToStaffPosition(
            data.bassPitch >= 0 ? uint8(uint16(data.bassPitch)) : 255,  // 255 = rest
            data.bassDuration
        );
        uint256 bassY = _getStaffY(bassPos.clef, int8(bassPos.staffStep), geom);
        string memory bassSymbol = midi.noteTypeToString(bassPos.noteType);
        
        bool bassDotted = _isDottedDuration(data.bassDuration);
        
        if (bassPos.noteType != IMidiToStaff.NoteType.REST) {
            string memory bassLedgers = positioning.getLedgerLines(
                noteX, 
                geom.bassTop, 
                int8(bassPos.staffStep)
            );
            notes = string(abi.encodePacked(notes, bassLedgers));
            
            INotePositioning.PositionResult memory bassNote = _getPositionForNoteType(
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
            
            if (bassDotted) {
                INotePositioning.PositionResult memory dot = positioning.getDotPosition(
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
            uint256 restY = geom.bassTop + 80;
            string memory restSymbol = _restTypeToString(bassPos.noteType);
            
            INotePositioning.PositionResult memory bassRest = positioning.getRestPosition(
                noteX + 38, restY, restSymbol
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
        
        return string(abi.encodePacked(
            header,
            grandStaff,
            '<g fill="', fgColor, '" color="', fgColor, '">',
            notes,
            '</g>',
            '</svg>'
        ));
    }
    
    /// @notice Calculate Y coordinate on staff from clef and staff step
    function _getStaffY(IMidiToStaff.Clef clef, int8 staffStep, IStaffUtils.StaffGeometry memory geom) 
        private pure returns (uint256) 
    {
        if (clef == IMidiToStaff.Clef.TREBLE) {
            return uint256(int256(uint256(geom.trebleTop)) + int256(staffStep) * 20);
        } else {
            return uint256(int256(uint256(geom.bassTop)) + int256(staffStep) * 20);
        }
    }
    
    /// @notice Get positioning for a note based on its type (up/down stem, whole, etc.)
    function _getPositionForNoteType(
        IMidiToStaff.NoteType noteType,
        uint256 x,
        uint256 y,
        string memory symbolId
    ) private view returns (INotePositioning.PositionResult memory) {
        if (noteType == IMidiToStaff.NoteType.QUARTER_UP || 
            noteType == IMidiToStaff.NoteType.HALF_UP ||
            noteType == IMidiToStaff.NoteType.EIGHTH_UP ||
            noteType == IMidiToStaff.NoteType.SIXTEENTH_UP) {
            return positioning.getUpNotePosition(x, y, symbolId);
        } else if (noteType == IMidiToStaff.NoteType.QUARTER_DOWN ||
                   noteType == IMidiToStaff.NoteType.HALF_DOWN ||
                   noteType == IMidiToStaff.NoteType.EIGHTH_DOWN ||
                   noteType == IMidiToStaff.NoteType.SIXTEENTH_DOWN) {
            return positioning.getDownNotePosition(x, y, symbolId);
        } else if (noteType == IMidiToStaff.NoteType.WHOLE) {
            return positioning.getWholeNotePosition(x, y);
        } else {
            // Fallback
            return positioning.getUpNotePosition(x, y, "quarter-up");
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
    
    /// @notice Check if duration represents a dotted note
    function _isDottedDuration(uint16 duration) private pure returns (bool) {
        // Dotted notes: 360, 720, 180, 90 ticks
        return (duration == 360 || duration == 720 || duration == 180 || duration == 90);
    }
    
    /// @notice Map note type to rest symbol ID
    function _restTypeToString(IMidiToStaff.NoteType noteType) private pure returns (string memory) {
        if (noteType == IMidiToStaff.NoteType.REST) {
            return "rest-quarter";  // Default rest
        }
        // This shouldn't be called for non-rest types, but provide fallback
        return "rest-quarter";
    }
}
