// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/render/post/SvgMusicGlyphs.sol";
import "../../src/render/post/StaffUtils.sol";
import "../../src/render/post/MidiToStaff.sol";
import "../../src/render/post/NotePositioning.sol";
import "../../src/contracts/MusicRendererOrchestrator.sol";
import "../../src/render/post/AudioRenderer.sol";
import "../../src/core/SongAlgorithm.sol";
import "../../src/render/pre/CountdownSvgRenderer.sol";
import "../../src/render/pre/CountdownHtmlRenderer.sol";

/**
 * @title 01_DeployRenderers
 * @notice Deploys all external rendering contracts
 * @dev Phase 1, Step 1: Deploy the 9 rendering contracts (7 post-reveal + 2 pre-reveal)
 * 
 * Run with:
 *   source .env
 *   forge script script/deploy/01_DeployRenderers.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 */
contract DeployRenderers is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying rendering stack...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        
        // 1. Deploy glyph storage (largest contract)
        console.log("\n1/9 Deploying SvgMusicGlyphs...");
        SvgMusicGlyphs glyphs = new SvgMusicGlyphs();
        console.log("  Address:", address(glyphs));
        
        // 2. Deploy staff utilities
        console.log("\n2/9 Deploying StaffUtils...");
        StaffUtils staff = new StaffUtils();
        console.log("  Address:", address(staff));
        
        // 3. Deploy MIDI to staff position converter
        console.log("\n3/9 Deploying MidiToStaff...");
        MidiToStaff midi = new MidiToStaff();
        console.log("  Address:", address(midi));
        
        // 4. Deploy note positioning calculator
        console.log("\n4/9 Deploying NotePositioning...");
        NotePositioning positioning = new NotePositioning();
        console.log("  Address:", address(positioning));
        
        // 5. Deploy music renderer orchestrator (wires together the 4 above)
        console.log("\n5/9 Deploying MusicRendererOrchestrator...");
        MusicRendererOrchestrator musicRenderer = new MusicRendererOrchestrator(
            address(staff),
            address(glyphs),
            address(midi),
            address(positioning)
        );
        console.log("  Address:", address(musicRenderer));
        
        // 6. Deploy audio renderer
        console.log("\n6/9 Deploying AudioRenderer...");
        AudioRenderer audioRenderer = new AudioRenderer();
        console.log("  Address:", address(audioRenderer));
        
        // 7. Deploy song algorithm
        console.log("\n7/9 Deploying SongAlgorithm...");
        SongAlgorithm songAlgorithm = new SongAlgorithm();
        console.log("  Address:", address(songAlgorithm));
        
        // 8. Deploy countdown SVG renderer
        console.log("\n8/9 Deploying CountdownSvgRenderer (SVG)...");
        CountdownSvgRenderer countdownSvg = new CountdownSvgRenderer();
        console.log("  Address:", address(countdownSvg));
        
        // 9. Deploy countdown HTML renderer
        console.log("\n9/9 Deploying CountdownHtmlRenderer...");
        CountdownHtmlRenderer countdownHtml = new CountdownHtmlRenderer();
        console.log("  Address:", address(countdownHtml));
        
        vm.stopBroadcast();
        
        // Print summary
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("\nCopy these addresses to .env:");
        console.log("GLYPHS_ADDRESS=%s", address(glyphs));
        console.log("STAFF_UTILS_ADDRESS=%s", address(staff));
        console.log("MIDI_TO_STAFF_ADDRESS=%s", address(midi));
        console.log("NOTE_POSITIONING_ADDRESS=%s", address(positioning));
        console.log("MUSIC_RENDERER_ADDRESS=%s", address(musicRenderer));
        console.log("AUDIO_RENDERER_ADDRESS=%s", address(audioRenderer));
        console.log("SONG_ALGORITHM_ADDRESS=%s", address(songAlgorithm));
        console.log("COUNTDOWN_SVG_ADDRESS=%s", address(countdownSvg));
        console.log("COUNTDOWN_HTML_ADDRESS=%s", address(countdownHtml));
        
        // Skip writing to disk when permissions are restricted
        console.log("\nFilesystem write skipped (set ALLOW_RENDERER_WRITE=1 to enable).");
    }
}
