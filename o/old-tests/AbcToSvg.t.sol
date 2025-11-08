// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/render/post/AbcToSvg.sol";
import "../src/core/SongAlgorithm.sol";

contract AbcToSvgTest is Test {
    function testGenerateBeatSvg() public {
        // Generate a beat using MusicLib
        uint32 seed = 999;
        uint32 beat = 0;
        
        (SongAlgorithm.Event memory leadEvent, SongAlgorithm.Event memory bassEvent) = 
            SongAlgorithm.generateBeat(beat, seed);
        
        // Convert to SVG
        string memory svg = AbcToSvg.generateBeatSvg(
            leadEvent.pitch,
            leadEvent.duration,
            bassEvent.pitch, 
            bassEvent.duration,
            seed,
            12 // beats
        );
        
        // Verify SVG contains basic structure
        assertTrue(bytes(svg).length > 0);
        
        // Should contain SVG header
        assertTrue(contains(svg, '<svg'));
        assertTrue(contains(svg, 'viewBox="0 0 600 600"'));
        
        // Should contain defs
        assertTrue(contains(svg, '<defs>'));
        
        // Should contain staff lines
        assertTrue(contains(svg, 'stroke="#fff"'));
        assertTrue(contains(svg, '<line'));
        
        // Should contain clefs
        assertTrue(contains(svg, '<use href="#treble"'));
        assertTrue(contains(svg, '<use href="#bass"'));
        
        // Write SVG to file for manual inspection
        console.log("Generated SVG:");
        console.log(svg);
        
        // Create HTML wrapper for easy viewing
        string memory html = string(abi.encodePacked(
            '<!DOCTYPE html><html><head><title>ABC to SVG Test</title></head><body>',
            svg,
            '</body></html>'
        ));
        
        vm.writeFile("debug_abc_svg.html", html);
    }
    
    function testPitchMapping() public {
        // Test treble pitch mapping
        int16 middleC = 60; // C4
        int16 step = AbcToSvg.treblePitchToStep(middleC);
        assertEq(step, 10); // Should be on ledger line below staff
        
        // Test high note
        int16 highF = 77; // F5  
        step = AbcToSvg.treblePitchToStep(highF);
        assertEq(step, 0); // Should be on top line
        
        // Test bass pitch mapping
        int16 lowA = 45; // A2
        step = AbcToSvg.bassPitchToStep(lowA);
        assertEq(step, 7); // Should be in bottom space
    }
    
    function testRestGeneration() public {
        // Generate SVG with a rest (pitch = -1)
        string memory svg = AbcToSvg.generateBeatSvg(
            -1, 480, // Lead rest, quarter note
            60, 480, // Bass C4, quarter note  
            123, 1
        );
        
        assertTrue(contains(svg, 'rest-quarter'));
        console.log("SVG with rest:");
        console.log(svg);
    }
    
    // Helper function to check if string contains substring
    function contains(string memory source, string memory target) internal pure returns (bool) {
        bytes memory sourceBytes = bytes(source);
        bytes memory targetBytes = bytes(target);
        
        if (targetBytes.length > sourceBytes.length) {
            return false;
        }
        
        for (uint i = 0; i <= sourceBytes.length - targetBytes.length; i++) {
            bool found = true;
            for (uint j = 0; j < targetBytes.length; j++) {
                if (sourceBytes[i + j] != targetBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}
