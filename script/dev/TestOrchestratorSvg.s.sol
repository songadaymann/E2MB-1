// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../src/interfaces/IMusicRenderer.sol";

/// @title TestOrchestratorSvg
/// @notice Test the new external contract architecture for music rendering
/// @dev Deploys all modules, wires them up, and generates SVG to verify it works
contract TestOrchestratorSvg is Script {
    using Strings for uint256;

    function run() external {
        console.log("=== TESTING MUSICRENDERER ORCHESTRATOR (EXTERNAL CONTRACTS) ===");
        console.log("");
        
        // Deploy using create2 for deterministic addresses
        vm.startBroadcast();
        
        // Deploy all the external module contracts
        console.log("Deploying rendering modules...");
        address staff = deployCode("StaffUtils.sol");
        console.log("  StaffUtils deployed at:", staff);
        
        address glyphs = deployCode("SvgMusicGlyphs.sol");
        console.log("  SvgMusicGlyphs deployed at:", glyphs);
        
        address midi = deployCode("MidiToStaff.sol");
        console.log("  MidiToStaff deployed at:", midi);
        
        address positioning = deployCode("NotePositioning.sol");
        console.log("  NotePositioning deployed at:", positioning);
        
        // Deploy the orchestrator
        console.log("");
        console.log("Deploying MusicRendererOrchestrator...");
        address orchestrator = deployCode(
            "MusicRendererOrchestrator.sol",
            abi.encode(staff, glyphs, midi, positioning)
        );
        console.log("  Orchestrator deployed at:", orchestrator);
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== MODULE WIRING COMPLETE ===");
        console.log("");
        
        // Create timestamped output folder
        string memory timestamp = _getTimestamp();
        string memory outputDir = string(abi.encodePacked("OUTPUTS/orchestrator-test-", timestamp));
        
        // Create the output directory
        string[] memory mkdirCmd = new string[](3);
        mkdirCmd[0] = "mkdir";
        mkdirCmd[1] = "-p";
        mkdirCmd[2] = outputDir;
        vm.ffi(mkdirCmd);
        
        // Test data - same as the original test
        IMusicRenderer.BeatData[] memory beats = new IMusicRenderer.BeatData[](10);
        
        // Data from combined-midi-info.json
        beats[0] = IMusicRenderer.BeatData(1, 0, 2026, 67, 720, 36, 960);   // G4 dotted, C2 half
        beats[1] = IMusicRenderer.BeatData(2, 1, 2027, 67, 480, 46, 480);   // G4 quarter, Bb2 quarter
        beats[2] = IMusicRenderer.BeatData(3, 2, 2028, 68, 480, 36, 960);   // Ab4 quarter, C2 half
        beats[3] = IMusicRenderer.BeatData(4, 3, 2029, 63, 240, 41, 240);   // Eb4 eighth, F2 eighth
        beats[4] = IMusicRenderer.BeatData(5, 4, 2030, 70, 480, 39, 960);   // Bb4 quarter, Eb2 half
        beats[5] = IMusicRenderer.BeatData(6, 5, 2031, 62, 480, 38, 480);   // D4 quarter, D2 quarter
        beats[6] = IMusicRenderer.BeatData(7, 6, 2032, 63, 720, 39, 960);   // Eb4 dotted, Eb2 half
        beats[7] = IMusicRenderer.BeatData(8, 7, 2033, 62, 720, 41, 240);   // D4 dotted, F2 eighth
        beats[8] = IMusicRenderer.BeatData(9, 8, 2034, -1, 480, 43, 960);   // REST, G2 half
        beats[9] = IMusicRenderer.BeatData(10, 9, 2035, 67, 480, 36, 480);  // G4 quarter, C2 quarter
        
        console.log("Generating", beats.length, "SVG files using external contract orchestrator...");
        console.log("");
        
        // Generate SVG for each beat using the orchestrator
        for (uint i = 0; i < beats.length; i++) {
            IMusicRenderer.BeatData memory beat = beats[i];
            
            // KEY: This now calls external contracts instead of internal library!
            string memory svg = IMusicRenderer(orchestrator).render(beat);
            
            string memory filename = string(abi.encodePacked(
                outputDir, "/token-", beat.tokenId.toString(), "-year-", beat.year.toString(), ".svg"
            ));
            
            vm.writeFile(filename, svg);
            
            console.log("Generated:", filename);
            console.log("  Token/Beat/Year:", beat.tokenId, beat.beat, beat.year);
            
            // Show note info
            if (beat.leadPitch >= 0) {
                console.log("  Lead MIDI:", uint256(uint16(beat.leadPitch)));
            } else {
                console.log("  Lead: REST");
            }
            
            if (beat.bassPitch >= 0) {
                console.log("  Bass MIDI:", uint256(uint16(beat.bassPitch)));
            } else {
                console.log("  Bass: REST");
            }
            
            console.log("");
        }
        
        console.log("=== COMPLETE ===");
        console.log("Output directory:", outputDir);
        console.log("");
        console.log("ARCHITECTURE VALIDATED:");
        console.log("  StaffUtils:       external contract (generates staff)");
        console.log("  SvgMusicGlyphs:   external contract (provides symbol defs)");
        console.log("  MidiToStaff:      external contract (MIDI conversion)");
        console.log("  NotePositioning:  external contract (note placement)");
        console.log("  Orchestrator:     external contract (assembles final SVG)");
        console.log("");
        console.log("SVG should match the original internal library version!");
    }
    
    /// @notice Get timestamp using FFI (creates unique folder names)
    function _getTimestamp() internal returns (string memory) {
        string[] memory dateCmd = new string[](2);
        dateCmd[0] = "date";
        dateCmd[1] = "+%Y%m%d_%H%M%S";
        bytes memory result = vm.ffi(dateCmd);
        return string(result);
    }
}
