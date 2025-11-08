// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/core/EveryTwoMillionBlocks.sol";
import "../src/render/post/SvgMusicGlyphs.sol";
import "../src/render/post/StaffUtils.sol";
import "../src/render/post/MidiToStaff.sol";
import "../src/render/post/NotePositioning.sol";
import "../src/contracts/MusicRendererOrchestrator.sol";
import "../src/render/post/AudioRenderer.sol";
import "../src/core/SongAlgorithm.sol";
import "../src/render/pre/CountdownSvgRenderer.sol";
import "../src/render/pre/CountdownHtmlRenderer.sol";

/// @title RevealTransition Test
/// @notice Test the REAL contract's reveal mechanism using time warping
/// @dev No modifications to production code - pure time manipulation
contract RevealTransitionTest is Test {
    
    EveryTwoMillionBlocks public nft;
    MusicRendererOrchestrator public musicRenderer;
    AudioRenderer public audioRenderer;
    SongAlgorithm public songAlgorithm;
    
    address public owner = address(this);
    address public user = address(0x1);
    
    function setUp() public {
        // Deploy rendering stack
        SvgMusicGlyphs glyphs = new SvgMusicGlyphs();
        StaffUtils staff = new StaffUtils();
        MidiToStaff midi = new MidiToStaff();
        NotePositioning positioning = new NotePositioning();
        
        musicRenderer = new MusicRendererOrchestrator(
            address(staff),
            address(glyphs),
            address(midi),
            address(positioning)
        );
        
        audioRenderer = new AudioRenderer();
        songAlgorithm = new SongAlgorithm();
        
        // Deploy ACTUAL production contract
        nft = new EveryTwoMillionBlocks();
        
        // Wire renderers
        nft.setRenderers(
            address(songAlgorithm),
            address(musicRenderer),
            address(audioRenderer)
        );

        CountdownSvgRenderer countdownSvg = new CountdownSvgRenderer();
        CountdownHtmlRenderer countdownHtml = new CountdownHtmlRenderer();
        nft.setCountdownRenderer(address(countdownSvg));
        nft.setCountdownHtmlRenderer(address(countdownHtml));
        nft.setDefaultPreRevealRenderer(0);
    }
    
    function testRevealTransitionSingleToken() public {
        console.log("\n=== TEST: Single Token Reveal Transition ===");
        
        // Mint token #1
        uint32 seed = 12345;
        nft.mint(user, seed);
        
        uint256 rank = nft.getCurrentRank(1);
        console.log("Token 1 rank:", rank);
        
        // Get pre-reveal metadata
        console.log("\n--- PRE-REVEAL STATE ---");
        string memory preRevealURI = nft.tokenURI(1);
        console.log("Metadata length:", bytes(preRevealURI).length);
        assertTrue(bytes(preRevealURI).length > 0, "Pre-reveal metadata should exist");
        
        // Verify it's a countdown (contains "countdown" or similar indicators)
        // We can check if it has the countdown SVG structure
        
        // Time travel to Jan 1, 2026 (token 1's reveal time, rank 0)
        uint256 jan1_2026 = 1735689600; // Jan 1, 2026 00:00:00 UTC
        console.log("\nWarping from", block.timestamp, "to", jan1_2026);
        vm.warp(jan1_2026);
        console.log("Current time after warp:", block.timestamp);
        
        // Now prepare reveal (two-step process)
        console.log("\n--- PREPARING REVEAL ---");
        vm.prank(user);
        nft.prepareReveal(1);
        
        console.log("--- FINALIZING REVEAL ---");
        vm.prank(user);
        nft.finalizeReveal(1);
        
        // Get post-reveal metadata
        console.log("\n--- POST-REVEAL STATE ---");
        string memory postRevealURI = nft.tokenURI(1);
        console.log("Metadata length:", bytes(postRevealURI).length);
        assertTrue(bytes(postRevealURI).length > 0, "Post-reveal metadata should exist");
        
        // Verify metadata changed
        assertNotEq(
            keccak256(bytes(preRevealURI)),
            keccak256(bytes(postRevealURI)),
            "Metadata should change after reveal"
        );
        
        console.log("\nSUCCESS: Token transitioned from countdown to revealed state!");
    }
    
    function testRevealMultipleTokensSequentially() public {
        console.log("\n=== TEST: Multiple Tokens Reveal Sequentially ===");
        
        // Mint 5 tokens
        for (uint256 i = 0; i < 5; i++) {
            nft.mint(user, uint32(12345 + i));
        }
        
        // Start at Jan 1, 2026 (token 1 reveals)
        uint256 jan1_2026 = 1735689600;
        vm.warp(jan1_2026);
        
        // Reveal token 1
        vm.startPrank(user);
        nft.prepareReveal(1);
        nft.finalizeReveal(1);
        vm.stopPrank();
        
        console.log("Token 1 revealed at year 2026");
        
        // Jump to Jan 1, 2027 (token 2 reveals)
        uint256 jan1_2027 = jan1_2026 + 365 days;
        vm.warp(jan1_2027);
        
        vm.startPrank(user);
        nft.prepareReveal(2);
        nft.finalizeReveal(2);
        vm.stopPrank();
        
        console.log("Token 2 revealed at year 2027");
        
        // Jump to Jan 1, 2028 (token 3 reveals)
        uint256 jan1_2028 = jan1_2027 + 365 days;
        vm.warp(jan1_2028);
        
        vm.startPrank(user);
        nft.prepareReveal(3);
        nft.finalizeReveal(3);
        vm.stopPrank();
        
        console.log("Token 3 revealed at year 2028");
        
        console.log("\nSUCCESS: 3 tokens revealed sequentially over 3 years!");
    }
    
    function testFastForward100Tokens() public {
        console.log("\n=== TEST: Fast Forward Through 100 Token Reveals ===");
        
        // Mint 10 tokens (100 would be slow in test)
        for (uint256 i = 0; i < 10; i++) {
            nft.mint(user, uint32(12345 + i));
        }
        
        uint256 jan1_2026 = 1735689600;
        
        // Reveal all 10 tokens by jumping 1 year at a time
        for (uint256 i = 1; i <= 10; i++) {
            uint256 year = 2026 + (i - 1);
            uint256 timestamp = jan1_2026 + ((i - 1) * 365 days);
            
            console.log("\nYear", year, "- Revealing token", i);
            vm.warp(timestamp);
            
            vm.startPrank(user);
            nft.prepareReveal(i);
            nft.finalizeReveal(i);
            vm.stopPrank();
            
            // Verify it's revealed
            string memory uri = nft.tokenURI(i);
            assertTrue(bytes(uri).length > 0, "Token should have metadata");
        }
        
        console.log("\nSUCCESS: All 10 tokens revealed across 10 years!");
    }
    
    function testCountdownToRevealMetadataChange() public {
        console.log("\n=== TEST: Countdown -> Reveal Metadata Change ===");
        
        // Mint token
        nft.mint(user, 99999);
        
        // Get pre-reveal metadata (before Jan 1, 2026)
        vm.warp(1735000000); // Before 2026
        string memory countdown = nft.tokenURI(1);
        
        // Warp to reveal time
        vm.warp(1735689600); // Jan 1, 2026
        
        // Reveal
        vm.startPrank(user);
        nft.prepareReveal(1);
        nft.finalizeReveal(1);
        vm.stopPrank();
        
        // Get post-reveal metadata
        string memory revealed = nft.tokenURI(1);
        
        // They should be different
        assertNotEq(
            keccak256(bytes(countdown)),
            keccak256(bytes(revealed)),
            "Metadata must change after reveal"
        );
        
        // Save both to files for inspection
        vm.writeFile("OUTPUTS/test-countdown.txt", countdown);
        vm.writeFile("OUTPUTS/test-revealed.txt", revealed);
        
        console.log("\nMetadata files saved:");
        console.log("  OUTPUTS/test-countdown.txt");
        console.log("  OUTPUTS/test-revealed.txt");
    }
}
