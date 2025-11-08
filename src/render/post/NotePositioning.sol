// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/INotePositioning.sol";

/// @title NotePositioning
/// @notice Library for positioning musical notes, rests, and dots on SVG staff
/// @dev Contains all calibrated positioning formulas from testing
/// @dev Converted from library to contract - now deployable separately
contract NotePositioning is INotePositioning {
    
    /// @notice Standard note size used in calculations
    uint256 private constant NOTE_SIZE = 60;
    
    /// @notice Note display height scale factor (2.5x)
    uint256 private constant NOTE_SCALE = 2500;
    
    // PositionResult struct is defined in INotePositioning interface
    
    /// @notice Head center coordinates for each note type (viewBox coords * 100 for precision)
    struct HeadCenter {
        uint256 x;  // X coordinate * 100
        uint256 y;  // Y coordinate * 100
    }
    
    /// @notice ViewBox dimensions for each symbol (dimensions * 100 for precision)  
    struct ViewBoxDims {
        uint256 width;   // Width * 100
        uint256 height;  // Height * 100
    }
    
    // ============================================================================
    // NOTE POSITIONING
    // ============================================================================
    
    /// @notice Calculate positioning for up-stemmed notes
    /// @param noteX Target X coordinate for note head center
    /// @param noteY Target Y coordinate for note head center  
    /// @param noteType Note type identifier ("quarter-up", "half-up", etc.)
    /// @return Positioning data (offsetX, offsetY, width, height)
    function getUpNotePosition(
        uint256 noteX,
        uint256 noteY,
        string memory noteType
    ) external pure override returns (PositionResult memory) {
        
        HeadCenter memory headCenter = _getUpNoteHeadCenter(noteType);
        ViewBoxDims memory viewBox = _getNoteViewBox(noteType);
        
        // Calculate display dimensions
        uint256 displayHeight = (NOTE_SIZE * NOTE_SCALE) / 1000;  // 150px
        uint256 displayWidth = (viewBox.width * displayHeight) / viewBox.height;
        
        // Calculate scale factor
        uint256 scaleFactor = (displayHeight * 100) / viewBox.height;
        
        // Up-stemmed positioning formula (calibrated from testing)
        int256 offsetX = int256(noteX) - int256((headCenter.x * scaleFactor) / 10000) + 20;
        int256 offsetY = int256(noteY) - int256((headCenter.y * scaleFactor) / 10000) - 130;
        
        return PositionResult({
            offsetX: offsetX,
            offsetY: offsetY,
            width: displayWidth,
            height: displayHeight
        });
    }
    
    /// @notice Calculate positioning for down-stemmed notes
    /// @param noteX Target X coordinate for note head center
    /// @param noteY Target Y coordinate for note head center
    /// @param noteType Note type identifier ("quarter-down", "half-down", etc.)
    /// @return Positioning data (offsetX, offsetY, width, height)
    function getDownNotePosition(
        uint256 noteX,
        uint256 noteY,
        string memory noteType
    ) external pure override returns (PositionResult memory) {
        
        HeadCenter memory headCenter = _getDownNoteHeadCenter(noteType);
        ViewBoxDims memory viewBox = _getNoteViewBox(noteType);
        
        // Calculate display dimensions  
        uint256 displayHeight = (NOTE_SIZE * NOTE_SCALE) / 1000;  // 150px
        uint256 displayWidth = (viewBox.width * displayHeight) / viewBox.height;
        
        // Calculate scale factor
        uint256 scaleFactor = (displayHeight * 100) / viewBox.height;
        
        // Down-stemmed positioning formula (calibrated from testing)
        int256 offsetX = int256(noteX) - int256((headCenter.x * scaleFactor) / 10000) + 20;
        int256 offsetY = int256(noteY) - int256((headCenter.y * scaleFactor) / 10000) - 20;  // Different Y adjustment
        
        return PositionResult({
            offsetX: offsetX,
            offsetY: offsetY,
            width: displayWidth,
            height: displayHeight
        });
    }
    
    /// @notice Calculate positioning for whole notes (no stem)
    /// @param noteX Target X coordinate for note head center
    /// @param noteY Target Y coordinate for note head center
    /// @return Positioning data (offsetX, offsetY, width, height)
    function getWholeNotePosition(
        uint256 noteX,
        uint256 noteY
    ) external pure override returns (PositionResult memory) {
        
        // Whole note: smaller display height
        uint256 displayHeight = (NOTE_SIZE * 675) / 1000;  // 40.5px
        
        // ViewBox for whole note
        ViewBoxDims memory viewBox = ViewBoxDims({width: 2706, height: 8362});  // 27.06 x 83.62
        uint256 displayWidth = (viewBox.width * displayHeight) / viewBox.height;
        
        // Head center for whole note
        HeadCenter memory headCenter = HeadCenter({x: 1350, y: 1002});  // (13.5, 10.02)
        
        uint256 scaleFactor = (displayHeight * 100) / viewBox.height;
        
        // Whole note positioning
        int256 offsetX = int256(noteX) - int256((headCenter.x * scaleFactor) / 10000) + 20;
        int256 offsetY = int256(noteY) - int256((headCenter.y * scaleFactor) / 10000) - 20;
        
        return PositionResult({
            offsetX: offsetX,
            offsetY: offsetY,
            width: displayWidth,
            height: displayHeight
        });
    }
    
    // ============================================================================
    // REST POSITIONING
    // ============================================================================
    
    /// @notice Calculate positioning for rests (center-based positioning)
    /// @param restX Target X coordinate for rest center
    /// @param restY Target Y coordinate for rest center
    /// @param restType Rest type identifier ("rest-quarter", "rest-eighth", "rest-half")
    /// @return Positioning data (offsetX, offsetY, width, height)
    function getRestPosition(
        uint256 restX,
        uint256 restY,
        string memory restType
    ) external pure override returns (PositionResult memory) {
        
        ViewBoxDims memory viewBox = _getRestViewBox(restType);
        uint256 scale = _getRestScale(restType);
        
        // Calculate display dimensions
        uint256 displayHeight = (NOTE_SIZE * scale) / 1000;
        uint256 displayWidth = (viewBox.width * displayHeight) / viewBox.height;
        
        // Simple center positioning for rests
        int256 offsetX = int256(restX) - int256(displayWidth / 2);
        int256 offsetY = int256(restY) - int256(displayHeight / 2);
        
        return PositionResult({
            offsetX: offsetX,
            offsetY: offsetY,
            width: displayWidth,
            height: displayHeight
        });
    }
    
    // ============================================================================
    // DOT POSITIONING
    // ============================================================================
    
    /// @notice Calculate positioning for dots (follows musical notation rules)
    /// @param noteX Note head center X coordinate
    /// @param noteY Note head center Y coordinate  
    /// @param onLine True if note is on a staff line, false if in space
    /// @return Positioning data (offsetX, offsetY, width, height)
    function getDotPosition(
        uint256 noteX,
        uint256 noteY,
        bool onLine
    ) external pure override returns (PositionResult memory) {
        bool noteOnLine = onLine;
        
        uint256 dotSize = 15;  // Calibrated dot size
        
        // Horizontal: 96px to the right (38px spacing + 58px to account for note positioning offset)
        uint256 dotX = noteX + 96;
        
        // Vertical: Musical notation rules
        // - Note on line → dot in space above (20px up)
        // - Note in space → dot in same space
        uint256 dotY = noteOnLine ? noteY - 20 : noteY;
        
        // Center the dot at target position
        int256 offsetX = int256(dotX) - int256(dotSize / 2);
        int256 offsetY = int256(dotY) - int256(dotSize / 2);
        
        return PositionResult({
            offsetX: offsetX,
            offsetY: offsetY,
            width: dotSize,
            height: dotSize
        });
    }
    
    // ============================================================================
    // LEDGER LINE POSITIONING
    // ============================================================================
    
    /// @notice Generate ledger lines for notes outside staff range
    /// @param noteX Note head center X coordinate
    /// @param staffTop Y coordinate of top staff line
    /// @param staffStep Staff step (0-8 for staff lines/spaces)
    /// @return SVG string with ledger line elements (empty if no ledger lines needed)
    function getLedgerLines(
        uint256 noteX,
        uint256 staffTop,
        int8 staffStep
    ) external pure override returns (string memory) {
        
        // Ledger lines needed:
        // - Above staff: step < 0 (C5 and higher on treble)
        // - Below staff: step > 8 (A1 and lower on bass)
        
        if (staffStep >= 0 && staffStep <= 8) {
            return "";  // No ledger lines needed
        }
        
        string memory lines = "";
        uint256 lineWidth = 65;  // Width of ledger line
        int256 centerX = int256(noteX) + 44;  // Calibrated for proper alignment
        int256 x1 = centerX - int256(lineWidth / 2);
        int256 x2 = centerX + int256(lineWidth / 2);
        
        if (staffStep < 0) {
            // Above staff: generate lines at -2, -4, -6, etc.
            for (int8 step = -2; step >= staffStep; step -= 2) {
                uint256 lineY = uint256(int256(staffTop) + (int256(int8(step)) * 20));
                lines = string(abi.encodePacked(
                    lines,
                    '<line x1="', _int16ToString(int16(x1)),
                    '" y1="', _uint16ToString(uint16(lineY)),
                    '" x2="', _int16ToString(int16(x2)),
                    '" y2="', _uint16ToString(uint16(lineY)),
                    '" stroke="#fff" stroke-width="6"/>'
                ));
            }
        } else {
            // Below staff: generate lines at 10, 12, 14, etc.
            for (int8 step = 10; step <= staffStep; step += 2) {
                uint256 lineY = uint256(int256(staffTop) + (int256(int8(step)) * 20));
                lines = string(abi.encodePacked(
                    lines,
                    '<line x1="', _int16ToString(int16(x1)),
                    '" y1="', _uint16ToString(uint16(lineY)),
                    '" x2="', _int16ToString(int16(x2)),
                    '" y2="', _uint16ToString(uint16(lineY)),
                    '" stroke="#fff" stroke-width="6"/>'
                ));
            }
        }
        
        return lines;
    }
    
    // ============================================================================
    // INTERNAL HELPER FUNCTIONS
    // ============================================================================
    
    /// @notice Get head center coordinates for up-stemmed notes
    function _getUpNoteHeadCenter(string memory noteType) private pure returns (HeadCenter memory) {
        bytes32 typeHash = keccak256(abi.encodePacked(noteType));
        
        if (typeHash == keccak256("quarter-up")) {
            return HeadCenter({x: 1350, y: 6846});  // (13.5, 68.46)
        } else if (typeHash == keccak256("half-up")) {
            return HeadCenter({x: 1450, y: 6825});  // (14.5, 68.25)
        } else if (typeHash == keccak256("eighth-up")) {
            return HeadCenter({x: 1350, y: 6850});  // (13.5, 68.50)
        } else if (typeHash == keccak256("sixteenth-up")) {
            return HeadCenter({x: 1350, y: 6800});  // (13.5, 68.00)
        }
        
        // Default to quarter-up
        return HeadCenter({x: 1350, y: 6846});
    }
    
    /// @notice Get head center coordinates for down-stemmed notes
    function _getDownNoteHeadCenter(string memory noteType) private pure returns (HeadCenter memory) {
        bytes32 typeHash = keccak256(abi.encodePacked(noteType));
        
        if (typeHash == keccak256("quarter-down")) {
            return HeadCenter({x: 1350, y: 1516});  // (13.5, 15.16)
        } else if (typeHash == keccak256("half-down")) {
            return HeadCenter({x: 1421, y: 1516});  // (14.21, 15.16)
        } else if (typeHash == keccak256("eighth-down")) {
            return HeadCenter({x: 1535, y: 1516});  // (15.35, 15.16)
        } else if (typeHash == keccak256("sixteenth-down")) {
            return HeadCenter({x: 1484, y: 1516});  // (14.84, 15.16)
        }
        
        // Default to quarter-down
        return HeadCenter({x: 1350, y: 1516});
    }
    
    /// @notice Get viewBox dimensions for note types
    function _getNoteViewBox(string memory noteType) private pure returns (ViewBoxDims memory) {
        bytes32 typeHash = keccak256(abi.encodePacked(noteType));
        
        if (typeHash == keccak256("quarter-up") || typeHash == keccak256("quarter-down")) {
            return ViewBoxDims({width: 2706, height: 8362});  // 27.06 x 83.62
        } else if (typeHash == keccak256("half-up") || typeHash == keccak256("half-down")) {
            return ViewBoxDims({width: 2842, height: 8376});  // 28.42 x 83.76
        } else if (typeHash == keccak256("eighth-up")) {
            return ViewBoxDims({width: 5258, height: 8376});  // 52.58 x 83.76
        } else if (typeHash == keccak256("eighth-down")) {
            return ViewBoxDims({width: 3070, height: 8368});  // 30.7 x 83.68
        } else if (typeHash == keccak256("sixteenth-up")) {
            return ViewBoxDims({width: 5334, height: 8372});  // 53.34 x 83.72
        } else if (typeHash == keccak256("sixteenth-down")) {
            return ViewBoxDims({width: 2968, height: 8372});  // 29.68 x 83.72
        }
        
        // Default to quarter note dimensions
        return ViewBoxDims({width: 2706, height: 8362});
    }
    
    /// @notice Get viewBox dimensions for rest types
    function _getRestViewBox(string memory restType) private pure returns (ViewBoxDims memory) {
        bytes32 typeHash = keccak256(abi.encodePacked(restType));
        
        if (typeHash == keccak256("rest-quarter")) {
            return ViewBoxDims({width: 1761, height: 5312});  // 17.61 x 53.12
        } else if (typeHash == keccak256("rest-eighth")) {
            return ViewBoxDims({width: 2328, height: 5552});  // 23.28 x 55.52
        } else if (typeHash == keccak256("rest-half")) {
            return ViewBoxDims({width: 5955, height: 1189});  // 59.55 x 11.89
        } else if (typeHash == keccak256("rest-whole")) {
            return ViewBoxDims({width: 5955, height: 1189});  // 59.55 x 11.89
        }
        
        // Default to quarter rest
        return ViewBoxDims({width: 1761, height: 5312});
    }
    
    /// @notice Get scale factor for rest types
    function _getRestScale(string memory restType) private pure returns (uint256) {
        bytes32 typeHash = keccak256(abi.encodePacked(restType));
        
        if (typeHash == keccak256("rest-quarter")) {
            return 2000;  // 2.0x scale
        } else if (typeHash == keccak256("rest-eighth")) {
            return 2000;  // 2.0x scale
        } else if (typeHash == keccak256("rest-half")) {
            return 350;   // 0.35x scale
        } else if (typeHash == keccak256("rest-whole")) {
            return 350;   // 0.35x scale
        }
        
        // Default to 2.0x
        return 2000;
    }
    
    /// @notice Convert int16 to string (handles negatives)
    function _int16ToString(int16 value) private pure returns (string memory) {
        if (value == 0) return "0";
        
        bool negative = value < 0;
        uint16 absValue = uint16(negative ? -value : value);
        
        bytes memory buffer = new bytes(7);  // Max: "-32768"
        uint256 index = buffer.length;
        
        while (absValue != 0) {
            index--;
            buffer[index] = bytes1(uint8(48 + (absValue % 10)));
            absValue /= 10;
        }
        
        if (negative) {
            index--;
            buffer[index] = "-";
        }
        
        bytes memory result = new bytes(buffer.length - index);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = buffer[index + i];
        }
        
        return string(result);
    }
    
    /// @notice Convert uint16 to string
    function _uint16ToString(uint16 value) private pure returns (string memory) {
        if (value == 0) return "0";
        
        bytes memory buffer = new bytes(6);  // Max: "65535"
        uint256 index = buffer.length;
        
        while (value != 0) {
            index--;
            buffer[index] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        
        bytes memory result = new bytes(buffer.length - index);
        for (uint256 i = 0; i < result.length; i++) {
            result[i] = buffer[index + i];
        }
        
        return string(result);
    }
}
