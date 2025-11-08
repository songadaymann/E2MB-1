// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/render/post/NotePositioning.sol";

/// @title NotePositioning Test
/// @notice Test the NotePositioning library with known calibrated values
contract NotePositioningTest is Test {
    
    function testQuarterUpPositioning() public {
        // Test quarter-up note at treble B4 line (our calibrated reference)
        uint256 noteX = 350;
        uint256 noteY = 160;  // B4 line
        
        NotePositioning.PositionResult memory result = 
            NotePositioning.getUpNotePosition(noteX, noteY, "quarter-up");
        
        // Should match our calibrated values from testing
        assertEq(result.offsetX, 320, "Quarter-up X offset should be 320");
        assertEq(result.offsetY, 30, "Quarter-up Y offset should be 30");
        assertEq(result.width, 48, "Quarter-up width should be 48");
        assertEq(result.height, 150, "Quarter-up height should be 150");
    }
    
    function testQuarterDownPositioning() public {
        // Test quarter-down note at treble B4 line (our calibrated reference)
        uint256 noteX = 350;
        uint256 noteY = 160;  // B4 line
        
        NotePositioning.PositionResult memory result = 
            NotePositioning.getDownNotePosition(noteX, noteY, "quarter-down");
        
        // Should match our calibrated values from testing
        assertEq(result.offsetX, 320, "Quarter-down X offset should be 320");
        assertEq(result.offsetY, 140, "Quarter-down Y offset should be 140");
        assertEq(result.width, 48, "Quarter-down width should be 48");
        assertEq(result.height, 150, "Quarter-down height should be 150");
    }
    
    function testBassClefPositioning() public {
        // Test quarter-up note at bass B2 line (our bass clef test)
        uint256 noteX = 350;
        uint256 noteY = 440;  // B2 line
        
        NotePositioning.PositionResult memory result = 
            NotePositioning.getUpNotePosition(noteX, noteY, "quarter-up");
        
        // Should be 280px lower than treble (440 - 160 = 280)
        assertEq(result.offsetX, 320, "Bass quarter-up X offset should be 320");
        assertEq(result.offsetY, 310, "Bass quarter-up Y offset should be 310");
    }
    
    function testQuarterRestPositioning() public {
        // Test quarter rest at treble center
        uint256 restX = 350;
        uint256 restY = 160;
        
        NotePositioning.PositionResult memory result = 
            NotePositioning.getRestPosition(restX, restY, "rest-quarter");
        
        // Should match our calibrated values
        assertEq(result.offsetX, 331, "Quarter rest X offset should be 331");
        assertEq(result.offsetY, 100, "Quarter rest Y offset should be 100");
        assertEq(result.width, 39, "Quarter rest width should be 39");
        assertEq(result.height, 120, "Quarter rest height should be 120");
    }
    
    function testHalfRestPositioning() public {
        // Test half rest at adjusted position
        uint256 restX = 350;
        uint256 restY = 152;  // 8px above center
        
        NotePositioning.PositionResult memory result = 
            NotePositioning.getRestPosition(restX, restY, "rest-half");
        
        // Should match our calibrated values
        assertEq(result.offsetX, 298, "Half rest X offset should be 298");
        assertEq(result.offsetY, 142, "Half rest Y offset should be 142");
        assertEq(result.width, 105, "Half rest width should be 105");
        assertEq(result.height, 21, "Half rest height should be 21");
    }
    
    function testDotPositioning() public {
        // Test dot for note on line (B4 line)
        uint256 noteX = 350;
        uint256 noteY = 160;
        bool noteOnLine = true;
        
        NotePositioning.PositionResult memory result = 
            NotePositioning.getDotPosition(noteX, noteY, noteOnLine);
        
        // Should be 38px right, 20px up (space above line)
        assertEq(result.offsetX, 381, "Dot X offset should be 381");
        assertEq(result.offsetY, 133, "Dot Y offset should be 133");
        assertEq(result.width, 15, "Dot width should be 15");
        assertEq(result.height, 15, "Dot height should be 15");
    }
    
    function testDotPositioningInSpace() public {
        // Test dot for note in space
        uint256 noteX = 350;
        uint256 noteY = 140;  // C5 space
        bool noteOnLine = false;
        
        NotePositioning.PositionResult memory result = 
            NotePositioning.getDotPosition(noteX, noteY, noteOnLine);
        
        // Should be 38px right, same Y (dot in same space)
        assertEq(result.offsetX, 381, "Dot X offset should be 381");
        assertEq(result.offsetY, 133, "Dot Y offset should be 133 (140 - 7.5)");
        assertEq(result.width, 15, "Dot width should be 15");
        assertEq(result.height, 15, "Dot height should be 15");
    }
}
