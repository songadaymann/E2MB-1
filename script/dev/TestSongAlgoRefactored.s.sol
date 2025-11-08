// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../src/core/SongAlgorithm.sol";

/// @title TestSongAlgoRefactored
/// @notice Test the refactored SongAlgorithm contract (now external)
/// @dev Generates first 50 beats with various seeds and outputs JSON + ABC
contract TestSongAlgoRefactored is Script {
    using Strings for uint256;
    
    struct BeatOutput {
        uint32 beat;
        uint256 year;
        uint32 seed;
        int16 leadPitch;
        uint16 leadDuration;
        int16 bassPitch;
        uint16 bassDuration;
        string abc;
    }
    
    function run() external {
        console.log("=== TESTING REFACTORED SONGALGORITHM ===");
        console.log("Architecture: External contract (not library)");
        console.log("");
        
        // Deploy SongAlgorithm contract
        SongAlgorithm algo = new SongAlgorithm();
        console.log("Deployed SongAlgorithm at:", address(algo));
        console.log("");
        
        // Test with multiple seeds
        uint32[5] memory testSeeds = [
            uint32(12345),
            uint32(42),
            uint32(99999),
            uint32(1),
            uint32(314159)
        ];
        
        for (uint s = 0; s < testSeeds.length; s++) {
            uint32 seed = testSeeds[s];
            console.log("--- Seed %d ---", seed);
            
            // Generate first 20 beats with this seed
            BeatOutput[] memory beats = new BeatOutput[](20);
            
            for (uint32 i = 0; i < 20; i++) {
                (ISongAlgorithm.Event memory lead, ISongAlgorithm.Event memory bass) = 
                    algo.generateBeat(i, seed);
                
                string memory abc = algo.generateAbcBeat(i, seed);
                
                beats[i] = BeatOutput({
                    beat: i,
                    year: 2026 + i,
                    seed: seed,
                    leadPitch: lead.pitch,
                    leadDuration: lead.duration,
                    bassPitch: bass.pitch,
                    bassDuration: bass.duration,
                    abc: abc
                });
                
                // Log first few beats
                if (i < 5) {
                    if (lead.pitch >= 0) {
                        console.log("  Beat", i, "Lead", uint256(uint16(lead.pitch)));
                    } else {
                        console.log("  Beat", i, "Lead REST");
                    }
                }
            }
            
            // Save output for this seed
            _saveOutput(beats, seed);
            console.log("");
        }
        
        console.log("=== COMPLETE ===");
        console.log("Output files in: OUTPUTS/algo-test/");
        console.log("");
        console.log("Key observations to verify:");
        console.log("1. Lead voice has rests (pitch = -1)");
        console.log("2. Bass voice never rests");
        console.log("3. Eb major tonality");
        console.log("4. Different seeds produce different results");
        console.log("5. Same seed+beat produces deterministic output");
    }
    
    function _saveOutput(BeatOutput[] memory beats, uint32 seed) internal {
        // Create output directory
        string[] memory mkdirCmd = new string[](3);
        mkdirCmd[0] = "mkdir";
        mkdirCmd[1] = "-p";
        mkdirCmd[2] = "OUTPUTS/algo-test";
        vm.ffi(mkdirCmd);
        
        // Generate JSON
        string memory json = _generateJSON(beats, seed);
        string memory jsonFile = string(abi.encodePacked(
            "OUTPUTS/algo-test/beats-seed-",
            uint256(seed).toString(),
            ".json"
        ));
        vm.writeFile(jsonFile, json);
        
        // Generate ABC
        string memory abc = _generateABC(beats, seed);
        string memory abcFile = string(abi.encodePacked(
            "OUTPUTS/algo-test/beats-seed-",
            uint256(seed).toString(),
            ".abc"
        ));
        vm.writeFile(abcFile, abc);
        
        console.log("Saved: %s", jsonFile);
    }
    
    function _generateJSON(BeatOutput[] memory beats, uint32 seed) 
        internal pure returns (string memory) 
    {
        string memory events = "";
        
        for (uint i = 0; i < beats.length; i++) {
            BeatOutput memory beat = beats[i];
            string memory comma = i < beats.length - 1 ? "," : "";
            
            events = string(abi.encodePacked(
                events,
                '    {"beat":', uint256(beat.beat).toString(),
                ',"year":', beat.year.toString(),
                ',"lead":{"pitch":', _int16ToString(beat.leadPitch),
                ',"duration":', uint256(beat.leadDuration).toString(),
                '},"bass":{"pitch":', _int16ToString(beat.bassPitch),
                ',"duration":', uint256(beat.bassDuration).toString(),
                '}}', comma, '\n'
            ));
        }
        
        return string(abi.encodePacked(
            '{\n',
            '  "metadata": {\n',
            '    "algorithm": "SongAlgorithm v3 (Eb major, refactored)",\n',
            '    "seed": ', uint256(seed).toString(), ',\n',
            '    "numBeats": ', beats.length.toString(), ',\n',
            '    "architecture": "External contract (post-refactor)"\n',
            '  },\n',
            '  "beats": [\n',
            events,
            '  ]\n',
            '}\n'
        ));
    }
    
    function _generateABC(BeatOutput[] memory beats, uint32 seed) 
        internal pure returns (string memory) 
    {
        string memory header = string(abi.encodePacked(
            "X:1\n",
            "T:SongAlgorithm Test - Seed ", uint256(seed).toString(), "\n",
            "C:Refactored External Contract\n",
            "M:4/4\n",
            "L:1/8\n",
            "K:Eb\n",
            "V:1 clef=treble name=\"Lead\"\n",
            "V:2 clef=bass name=\"Bass\"\n"
        ));
        
        string memory body = "";
        for (uint i = 0; i < beats.length; i++) {
            body = string(abi.encodePacked(
                body,
                "% Beat ", uint256(beats[i].beat).toString(), " - Year ", beats[i].year.toString(), "\n",
                beats[i].abc, "\n"
            ));
        }
        
        return string(abi.encodePacked(header, body));
    }
    
    function _int16ToString(int16 value) internal pure returns (string memory) {
        if (value >= 0) {
            return uint256(uint16(value)).toString();
        } else {
            return string(abi.encodePacked("-", uint256(uint16(-value)).toString()));
        }
    }
}
