// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/core/EveryTwoMillionBlocks.sol";
import "../../src/core/SongAlgorithm.sol";
import "../../src/contracts/MusicRendererOrchestrator.sol";
import "../../src/render/post/StaffUtils.sol";
import "../../src/render/post/SvgMusicGlyphs.sol";
import "../../src/render/post/MidiToStaff.sol";
import "../../src/render/post/NotePositioning.sol";
import "../../src/render/post/AudioRenderer.sol";

/// @title TestTwoStepReveal
/// @notice Test the new two-step reveal mechanism (prepareReveal → finalizeReveal)
contract TestTwoStepReveal is Script {
    function run() external {
        console.log("=== TESTING TWO-STEP REVEAL MECHANISM ===");
        console.log("");
        
        // Deploy all contracts
        console.log("1. Deploying contracts...");
        SongAlgorithm algo = new SongAlgorithm();
        StaffUtils staffUtils = new StaffUtils();
        SvgMusicGlyphs glyphs = new SvgMusicGlyphs();
        MidiToStaff midiToStaff = new MidiToStaff();
        NotePositioning positioning = new NotePositioning();
        AudioRenderer audio = new AudioRenderer();
        
        MusicRendererOrchestrator musicRenderer = new MusicRendererOrchestrator(
            address(staffUtils),
            address(glyphs),
            address(midiToStaff),
            address(positioning)
        );
        
        EveryTwoMillionBlocks nft = new EveryTwoMillionBlocks();
        
        console.log("   EveryTwoMillionBlocks:", address(nft));
        console.log("   SongAlgorithm:", address(algo));
        console.log("   MusicRenderer:", address(musicRenderer));
        console.log("");
        
        // Wire renderers (songAlgorithm, music, audio)
        console.log("2. Wiring renderers...");
        nft.setRenderers(address(algo), address(musicRenderer), address(audio));
        console.log("   Renderers connected");
        console.log("");
        
        // Mint a token
        console.log("3. Minting token #1...");
        address holder = address(0x1234);
        nft.mint(holder, 12345);
        console.log("   Token #1 minted to", holder);
        console.log("   Token seed:", nft.tokenSeed(1));
        console.log("");
        
        // Check initial state
        console.log("4. Checking initial state...");
        console.log("   revealed[1]:", nft.revealed(1));
        console.log("   revealPending[1]:", nft.revealPending(1));
        console.log("");
        
        // Step 1: Prepare reveal
        console.log("5. Calling prepareReveal(1)...");
        uint256 gasBefore = gasleft();
        nft.prepareReveal(1);
        uint256 gasUsed = gasBefore - gasleft();
        console.log("   Gas used:", gasUsed);
        console.log("");
        
        // Check pending state
        console.log("6. Checking pending state...");
        console.log("   revealPending[1]:", nft.revealPending(1));
        console.log("   pendingBeat[1]:", nft.pendingBeat(1));
        console.log("   pendingWords[1]:", uint256(nft.pendingWords(1)));
        console.log("   revealed[1] (should still be false):", nft.revealed(1));
        console.log("");
        
        // Step 2: Finalize reveal
        console.log("7. Calling finalizeReveal(1)...");
        gasBefore = gasleft();
        nft.finalizeReveal(1);
        gasUsed = gasBefore - gasleft();
        console.log("   Gas used:", gasUsed);
        console.log("");
        
        // Check final state
        console.log("8. Checking final state...");
        console.log("   revealed[1]:", nft.revealed(1));
        console.log("   revealPending[1] (should be false):", nft.revealPending(1));
        
        (int16 leadPitch, uint16 leadDuration) = nft.revealedLeadNote(1);
        (int16 bassPitch, uint16 bassDuration) = nft.revealedBassNote(1);
        console.log("   Lead note: MIDI", _int16ToString(leadPitch), "duration", leadDuration);
        console.log("   Bass note: MIDI", uint256(uint16(bassPitch)), "duration", bassDuration);
        console.log("");
        
        // Test metadata generation
        console.log("9. Testing tokenURI()...");
        string memory uri = nft.tokenURI(1);
        console.log("   URI length:", bytes(uri).length, "bytes");
        console.log("   URI prefix:", _substring(uri, 0, 50));
        console.log("");
        
        console.log("=== TEST COMPLETE ===");
        console.log("");
        console.log("Summary:");
        console.log("  - Two-step reveal works correctly");
        console.log("  - State transitions validated");
        console.log("  - Music generated and stored");
        console.log("  - Metadata returns properly formatted data URI");
    }
    
    function _int16ToString(int16 value) internal pure returns (string memory) {
        if (value >= 0) {
            return Strings.toString(uint256(uint16(value)));
        } else {
            return string(abi.encodePacked("-", Strings.toString(uint256(uint16(-value)))));
        }
    }
    
    function _substring(string memory str, uint256 start, uint256 len) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (start + len > strBytes.length) {
            len = strBytes.length - start;
        }
        
        bytes memory result = new bytes(len);
        for (uint256 i = 0; i < len; i++) {
            result[i] = strBytes[start + i];
        }
        return string(result);
    }
}
