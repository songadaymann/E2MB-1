// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Import the contract implementations directly
import {StaffUtils} from "../../src/render/post/StaffUtils.sol";
import {SvgMusicGlyphs} from "../../src/render/post/SvgMusicGlyphs.sol";
import {MidiToStaff} from "../../src/render/post/MidiToStaff.sol";
import {NotePositioning} from "../../src/render/post/NotePositioning.sol";
import {MusicRendererOrchestrator} from "../../src/contracts/MusicRendererOrchestrator.sol";
import {IMusicRenderer} from "../../src/interfaces/IMusicRenderer.sol";

/// @title TestOrchestratorSimple
/// @notice Test the new external contract architecture - simpler version
contract TestOrchestratorSimple is Script {
    using Strings for uint256;

    function run() external {
        console.log("=== TESTING MUSIC RENDERER ORCHESTRATOR ===");
        console.log("");
        
        // Deploy modules
        console.log("Deploying modules...");
        StaffUtils staff = new StaffUtils();
        console.log("  StaffUtils:", address(staff));
        
        SvgMusicGlyphs glyphs = new SvgMusicGlyphs();
        console.log("  SvgMusicGlyphs:", address(glyphs));
        
        MidiToStaff midi = new MidiToStaff();
        console.log("  MidiToStaff:", address(midi));
        
        NotePositioning positioning = new NotePositioning();
        console.log("  NotePositioning:", address(positioning));
        
        // Deploy orchestrator
        console.log("");
        console.log("Deploying orchestrator...");
        MusicRendererOrchestrator orchestrator = new MusicRendererOrchestrator(
            address(staff),
            address(glyphs),
            address(midi),
            address(positioning)
        );
        console.log("  Orchestrator:", address(orchestrator));
        
        console.log("");
        console.log("=== ARCHITECTURE DEPLOYED ===");
        console.log("");
        
        // Create output directory
        string[] memory mkdirCmd = new string[](3);
        mkdirCmd[0] = "mkdir";
        mkdirCmd[1] = "-p";
        mkdirCmd[2] = "OUTPUTS";
        vm.ffi(mkdirCmd);
        
        // Test with a few beats
        IMusicRenderer.BeatData[] memory beats = new IMusicRenderer.BeatData[](5);
        beats[0] = IMusicRenderer.BeatData(1, 0, 2026, 67, 720, 36, 960);   // G4 dotted, C2 half
        beats[1] = IMusicRenderer.BeatData(2, 1, 2027, 67, 480, 46, 480);   // G4 quarter, Bb2 quarter
        beats[2] = IMusicRenderer.BeatData(3, 2, 2028, 63, 240, 41, 240);   // Eb4 eighth, F2 eighth
        beats[3] = IMusicRenderer.BeatData(4, 3, 2029, -1, 480, 43, 960);   // REST, G2 half
        beats[4] = IMusicRenderer.BeatData(5, 4, 2030, 70, 480, 39, 960);   // Bb4 quarter, Eb2 half
        
        console.log("Generating SVG files...");
        console.log("");
        
        for (uint i = 0; i < beats.length; i++) {
            IMusicRenderer.BeatData memory beat = beats[i];
            
            // Call the orchestrator
            string memory svg = orchestrator.render(beat);
            
            // Write to file
            string memory filename = string(abi.encodePacked(
                "OUTPUTS/orchestrator-token-", beat.tokenId.toString(), ".svg"
            ));
            vm.writeFile(filename, svg);
            
            console.log("Token", beat.tokenId, "->", filename);
            if (beat.leadPitch >= 0) {
                console.log("  Lead: MIDI", uint256(uint16(beat.leadPitch)));
            } else {
                console.log("  Lead: REST");
            }
            console.log("  Bass: MIDI", uint256(uint16(beat.bassPitch)));
            console.log("");
        }
        
        console.log("=== COMPLETE ===");
        console.log("All SVGs generated successfully!");
        console.log("");
        console.log("VERIFICATION:");
        console.log("  Open OUTPUTS/orchestrator-token-1.svg in browser");
        console.log("  Should show: G4 (dotted half) + C2 (half) on staff");
    }
}
