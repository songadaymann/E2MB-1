// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/testnet/FastRevealTest.sol";
import "../../src/render/post/SvgMusicGlyphs.sol";
import "../../src/render/post/StaffUtils.sol";
import "../../src/render/post/MidiToStaff.sol";
import "../../src/render/post/NotePositioning.sol";
import "../../src/contracts/MusicRendererOrchestrator.sol";
import "../../src/render/post/AudioRenderer.sol";
import "../../src/core/SongAlgorithm.sol";

/// @title DeployFastReveal
/// @notice Deploy FastRevealTest with 5-minute intervals
/// @dev Can reuse existing renderers OR deploy fresh ones
contract DeployFastReveal is Script {
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Check if we should reuse existing renderers
        bool reuseRenderers = vm.envOr("REUSE_RENDERERS", false);
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying Fast Reveal Test Stack...");
        console.log("Deploy time:", block.timestamp);
        console.log("Reuse existing renderers:", reuseRenderers);
        
        address glyphsAddr;
        address staffAddr;
        address midiAddr;
        address positioningAddr;
        address audioRendererAddr;
        address songAlgorithmAddr;
        
        if (reuseRenderers) {
            // Load existing addresses from environment
            console.log("\n1. Reusing existing rendering contracts...");
            glyphsAddr = vm.envAddress("SVG_GLYPHS");
            staffAddr = vm.envAddress("STAFF_UTILS");
            midiAddr = vm.envAddress("MIDI_TO_STAFF");
            positioningAddr = vm.envAddress("NOTE_POSITIONING");
            audioRendererAddr = vm.envAddress("AUDIO_RENDERER");
            songAlgorithmAddr = vm.envAddress("SONG_ALGORITHM");
            
            console.log("  SvgMusicGlyphs:", glyphsAddr);
            console.log("  StaffUtils:", staffAddr);
            console.log("  MidiToStaff:", midiAddr);
            console.log("  NotePositioning:", positioningAddr);
            console.log("  AudioRenderer:", audioRendererAddr);
            console.log("  SongAlgorithm:", songAlgorithmAddr);
        } else {
            // Deploy fresh rendering contracts
            console.log("\n1. Deploying NEW rendering contracts...");
            
            SvgMusicGlyphs glyphs = new SvgMusicGlyphs();
            glyphsAddr = address(glyphs);
            console.log("  SvgMusicGlyphs:", glyphsAddr);
            
            StaffUtils staff = new StaffUtils();
            staffAddr = address(staff);
            console.log("  StaffUtils:", staffAddr);
            
            MidiToStaff midi = new MidiToStaff();
            midiAddr = address(midi);
            console.log("  MidiToStaff:", midiAddr);
            
            NotePositioning positioning = new NotePositioning();
            positioningAddr = address(positioning);
            console.log("  NotePositioning:", positioningAddr);
            
            AudioRenderer audioRenderer = new AudioRenderer();
            audioRendererAddr = address(audioRenderer);
            console.log("  AudioRenderer:", audioRendererAddr);
            
            SongAlgorithm songAlgorithm = new SongAlgorithm();
            songAlgorithmAddr = address(songAlgorithm);
            console.log("  SongAlgorithm:", songAlgorithmAddr);
        }
        
        // 2. Deploy orchestrator (always new, as it needs to point to renderers)
        console.log("\n2. Deploying MusicRendererOrchestrator...");
        MusicRendererOrchestrator musicRenderer = new MusicRendererOrchestrator(
            staffAddr,
            glyphsAddr,
            midiAddr,
            positioningAddr
        );
        console.log("  Orchestrator:", address(musicRenderer));
        
        // 3. Deploy main NFT contract
        console.log("\n3. Deploying FastRevealTest NFT...");
        FastRevealTest nft = new FastRevealTest();
        console.log("  FastRevealTest:", address(nft));
        console.log("  Deploy timestamp:", nft.deployTimestamp());
        console.log("  Reveal interval:", nft.REVEAL_INTERVAL(), "seconds (5 minutes)");
        
        // 4. Wire renderers
        console.log("\n4. Wiring renderers...");
        nft.setRenderers(
            songAlgorithmAddr,
            address(musicRenderer),
            audioRendererAddr
        );
        console.log("  Renderers wired!");
        
        vm.stopBroadcast();
        
        // Print addresses (don't use writeFile to avoid permissions issues)
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("FastRevealTest:", address(nft));
        console.log("MusicRenderer:", address(musicRenderer));
        console.log("AudioRenderer:", audioRendererAddr);
        console.log("SongAlgorithm:", songAlgorithmAddr);
        console.log("\nCopy these to deployed-fast-reveal.env:");
        console.log("FAST_REVEAL=", vm.toString(address(nft)));
        console.log("MUSIC_RENDERER=", vm.toString(address(musicRenderer)));
        console.log("AUDIO_RENDERER=", vm.toString(audioRendererAddr));
        console.log("SONG_ALGORITHM=", vm.toString(songAlgorithmAddr));
        
        console.log("\nNext steps:");
        console.log("1. Mint: cast send $FAST_REVEAL 'batchMint(address,uint256)' <ADDR> 10 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy");
        console.log("2. View on Rarible: https://testnet.rarible.com/token/sepolia/", vm.toString(address(nft)), ":1");
    }
}
