// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../../src/core/SongAlgorithm.sol";

/// @title TestSongAlgoWithRealSeeds
/// @notice Test SongAlgorithm with proper 5-source seed computation (matching MillenniumSong._computeRevealSeed)
/// @dev Simulates the full reveal seed calculation with all entropy sources
contract TestSongAlgoWithRealSeeds is Script {
    using Strings for uint256;
    
    struct TokenContext {
        uint256 tokenId;
        uint32 tokenSeed;       // Initial seed from mint
        bytes32 sevenWords;     // Owner's chosen words
        bytes32 previousNotes;  // Cumulative hash of previous reveals
        bytes32 globalState;    // Global state
    }
    
    struct BeatOutput {
        uint32 beat;
        uint256 year;
        uint256 tokenId;
        uint32 finalSeed;
        int16 leadPitch;
        uint16 leadDuration;
        int16 bassPitch;
        uint16 bassDuration;
        string abc;
    }
    
    function run() external {
        console.log("=== TESTING SONGALGORITHM WITH REAL 5-SOURCE SEEDS ===");
        console.log("Matching MillenniumSong._computeRevealSeed() logic");
        console.log("");
        
        // Deploy SongAlgorithm contract
        SongAlgorithm algo = new SongAlgorithm();
        console.log("Deployed SongAlgorithm at:", address(algo));
        console.log("");
        
        // Initialize global state (would be set by owner)
        bytes32 globalState = keccak256("millennium-song-v1-mainnet");
        console.log("Global State:");
        console.logBytes32(globalState);
        console.log("");
        
        // Simulate 50 tokens revealing sequentially
        uint256 numTokens = 50;
        BeatOutput[] memory beats = new BeatOutput[](numTokens);
        bytes32 previousNotesHash = bytes32(0); // Start with empty
        
        console.log("Generating %d beats with realistic seed computation...", numTokens);
        console.log("");
        
        for (uint256 i = 0; i < numTokens; i++) {
            uint256 tokenId = i + 1;
            uint32 beat = uint32(i);
            
            // Create token context (simulating what would be in storage)
            TokenContext memory ctx = TokenContext({
                tokenId: tokenId,
                tokenSeed: _generateTokenSeed(tokenId),
                sevenWords: _generateSevenWords(tokenId),
                previousNotes: previousNotesHash,
                globalState: globalState
            });
            
            // Compute final reveal seed (EXACTLY as MillenniumSong does)
            uint32 finalSeed = _computeRevealSeed(ctx);
            
            // Generate music with this seed
            (ISongAlgorithm.Event memory lead, ISongAlgorithm.Event memory bass) = 
                algo.generateBeat(beat, finalSeed);
            
            string memory abc = algo.generateAbcBeat(beat, finalSeed);
            
            beats[i] = BeatOutput({
                beat: beat,
                year: 2026 + i,
                tokenId: tokenId,
                finalSeed: finalSeed,
                leadPitch: lead.pitch,
                leadDuration: lead.duration,
                bassPitch: bass.pitch,
                bassDuration: bass.duration,
                abc: abc
            });
            
            // Update previousNotesHash (cumulative, like in contract)
            previousNotesHash = keccak256(abi.encodePacked(
                previousNotesHash,
                lead.pitch,
                lead.duration,
                bass.pitch,
                bass.duration
            ));
            
            // Log first 10 for verification
            if (i < 10) {
                console.log("Token %d: seed=%d", tokenId, finalSeed);
                if (lead.pitch >= 0) {
                    console.log("  Lead MIDI %d, Bass MIDI %d", uint256(uint16(lead.pitch)), uint256(uint16(bass.pitch)));
                } else {
                    console.log("  Lead REST, Bass MIDI %d", uint256(uint16(bass.pitch)));
                }
            }
        }
        
        // Save outputs
        _saveOutput(beats);
        
        console.log("");
        console.log("=== COMPLETE ===");
        console.log("Output: OUTPUTS/real-seed-test/");
        console.log("");
        console.log("Seed components (matching MillenniumSong):");
        console.log("1. tokenSeed - per-token initial seed");
        console.log("2. sevenWords - owner's commitment");
        console.log("3. previousNotesHash - cumulative note history");
        console.log("4. globalState - global entropy");
        console.log("5. tokenId - unique identifier");
    }
    
    /// @notice Compute reveal seed EXACTLY as MillenniumSong._computeRevealSeed does
    /// @dev This must match the contract implementation perfectly
    function _computeRevealSeed(TokenContext memory ctx) internal pure returns (uint32) {
        return uint32(uint256(keccak256(abi.encodePacked(
            ctx.tokenSeed,      // Source 1: Initial token seed
            ctx.sevenWords,     // Source 2: Seven words commitment
            ctx.previousNotes,  // Source 3: Previous notes hash
            ctx.globalState,    // Source 4: Global state
            ctx.tokenId         // Source 5: Token ID
        ))));
    }
    
    /// @notice Generate initial token seed (simulating mint)
    function _generateTokenSeed(uint256 tokenId) internal view returns (uint32) {
        // In real contract, this comes from mint parameter or block data
        return uint32(uint256(keccak256(abi.encodePacked(
            block.timestamp,
            tokenId,
            "mint-entropy"
        ))));
    }
    
    /// @notice Generate seven words (simulating owner choice)
    function _generateSevenWords(uint256 tokenId) internal pure returns (bytes32) {
        // In real contract, owner calls setSevenWords() before reveal
        // For testing, generate deterministically
        string[7] memory words = [
            "eternal",
            "harmony",
            "resonance",
            "time",
            "melody",
            "transcend",
            "infinity"
        ];
        
        // Rotate words based on tokenId for variety
        uint256 offset = tokenId % 7;
        return keccak256(abi.encodePacked(
            words[offset],
            words[(offset + 1) % 7],
            words[(offset + 2) % 7],
            words[(offset + 3) % 7],
            words[(offset + 4) % 7],
            words[(offset + 5) % 7],
            words[(offset + 6) % 7]
        ));
    }
    
    function _saveOutput(BeatOutput[] memory beats) internal {
        // Create output directory
        string[] memory mkdirCmd = new string[](3);
        mkdirCmd[0] = "mkdir";
        mkdirCmd[1] = "-p";
        mkdirCmd[2] = "OUTPUTS/real-seed-test";
        vm.ffi(mkdirCmd);
        
        // Generate JSON with seed details
        string memory json = _generateJSON(beats);
        vm.writeFile("OUTPUTS/real-seed-test/beats-with-real-seeds.json", json);
        
        // Generate ABC
        string memory abc = _generateABC(beats);
        vm.writeFile("OUTPUTS/real-seed-test/beats-with-real-seeds.abc", abc);
        
        // Generate CSV with seed breakdown
        string memory csv = _generateCSV(beats);
        vm.writeFile("OUTPUTS/real-seed-test/seed-breakdown.csv", csv);
        
        console.log("Saved 3 files:");
        console.log("  - beats-with-real-seeds.json");
        console.log("  - beats-with-real-seeds.abc");
        console.log("  - seed-breakdown.csv");
    }
    
    function _generateJSON(BeatOutput[] memory beats) internal pure returns (string memory) {
        string memory events = "";
        
        for (uint i = 0; i < beats.length; i++) {
            BeatOutput memory beat = beats[i];
            string memory comma = i < beats.length - 1 ? "," : "";
            
            events = string(abi.encodePacked(
                events,
                '    {"tokenId":', beat.tokenId.toString(),
                ',"beat":', uint256(beat.beat).toString(),
                ',"year":', beat.year.toString(),
                ',"finalSeed":', uint256(beat.finalSeed).toString(),
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
            '    "algorithm": "SongAlgorithm v3 (refactored)",\n',
            '    "seedMethod": "5-source (tokenSeed + sevenWords + previousNotes + globalState + tokenId)",\n',
            '    "numBeats": ', beats.length.toString(), ',\n',
            '    "architecture": "External contract with realistic seed computation"\n',
            '  },\n',
            '  "beats": [\n',
            events,
            '  ]\n',
            '}\n'
        ));
    }
    
    function _generateABC(BeatOutput[] memory beats) internal pure returns (string memory) {
        string memory header = string(abi.encodePacked(
            "X:1\n",
            "T:Millennium Song - Real 5-Source Seeds\n",
            "C:SongAlgorithm Test\n",
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
                "% Token ", beats[i].tokenId.toString(), " - Beat ", uint256(beats[i].beat).toString(),
                " - Seed ", uint256(beats[i].finalSeed).toString(), "\n",
                beats[i].abc, "\n"
            ));
        }
        
        return string(abi.encodePacked(header, body));
    }
    
    function _generateCSV(BeatOutput[] memory beats) internal pure returns (string memory) {
        string memory csv = "token_id,beat,year,final_seed,lead_pitch,lead_duration,bass_pitch,bass_duration\n";
        
        for (uint i = 0; i < beats.length; i++) {
            BeatOutput memory beat = beats[i];
            csv = string(abi.encodePacked(
                csv,
                beat.tokenId.toString(), ",",
                uint256(beat.beat).toString(), ",",
                beat.year.toString(), ",",
                uint256(beat.finalSeed).toString(), ",",
                _int16ToString(beat.leadPitch), ",",
                uint256(beat.leadDuration).toString(), ",",
                _int16ToString(beat.bassPitch), ",",
                uint256(beat.bassDuration).toString(), "\n"
            ));
        }
        
        return csv;
    }
    
    function _int16ToString(int16 value) internal pure returns (string memory) {
        if (value >= 0) {
            return uint256(uint16(value)).toString();
        } else {
            return string(abi.encodePacked("-", uint256(uint16(-value)).toString()));
        }
    }
}
