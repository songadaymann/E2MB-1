// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "../../src/core/EveryTwoMillionBlocks.sol";
import "../../src/core/SongAlgorithm.sol";
import "../../src/contracts/MusicRendererOrchestrator.sol";
import "../../src/render/post/StaffUtils.sol";
import "../../src/render/post/SvgMusicGlyphs.sol";
import "../../src/render/post/MidiToStaff.sol";
import "../../src/render/post/NotePositioning.sol";
import "../../src/render/post/AudioRenderer.sol";

contract TestSevenWordsDescription is Script {
    function run() external {
        console.log("=== TESTING SEVEN WORDS AS DESCRIPTION ===");
        
        // Deploy contracts
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
        nft.setRenderers(address(algo), address(musicRenderer), address(audio));
        
        // Mint and set seven words
        console.log("\n1. Minting token with seven words...");
        address holder = address(0x1234);
        nft.mint(holder, 999);
        
        vm.prank(holder);
        nft.setSevenWords(1, "eternal harmony resonance time melody transcend infinity");
        
        console.log('   Seven words: "eternal harmony resonance time melody transcend infinity"');
        
        // Check stored words
        console.log("\n2. Checking stored seven words:");
        string memory stored = nft.sevenWordsText(1);
        console.log("   Stored:", stored);
        
        // Generate metadata (will include words as description)
        console.log("\n3. Generating pre-reveal tokenURI...");
        string memory uri = nft.tokenURI(1);
        console.log("   URI generated (", bytes(uri).length, "bytes)");
        console.log("   Preview:", _substring(uri, 0, 100));
        
        // Reveal and check post-reveal
        console.log("\n4. Revealing token...");
        nft.prepareReveal(1);
        nft.finalizeReveal(1);
        
        console.log("\n5. Generating post-reveal tokenURI...");
        uri = nft.tokenURI(1);
        console.log("   URI generated (", bytes(uri).length, "bytes)");
        console.log("   Preview:", _substring(uri, 0, 100));
        
        console.log("\nSeven words will appear as description in both states!");
    }
    
    function _substring(string memory str, uint start, uint len) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        if (start + len > strBytes.length) len = strBytes.length - start;
        
        bytes memory result = new bytes(len);
        for (uint i = 0; i < len; i++) {
            result[i] = strBytes[start + i];
        }
        return string(result);
    }
}
