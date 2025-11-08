// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/core/EveryTwoMillionBlocks.sol";
import "../../src/render/post/SvgMusicGlyphs.sol";
import "../../src/render/post/StaffUtils.sol";
import "../../src/render/post/MidiToStaff.sol";
import "../../src/render/post/NotePositioning.sol";
import "../../src/contracts/MusicRendererOrchestrator.sol";
import "../../src/render/post/AudioRenderer.sol";
import "../../src/core/SongAlgorithm.sol";

/// @title TestRevealWithTimeWarp
/// @notice Test ACTUAL EveryTwoMillionBlocks contract using time manipulation
/// @dev Uses Foundry's vm.warp() to fast-forward time instead of modifying contracts
contract TestRevealWithTimeWarp is Script {
    
    EveryTwoMillionBlocks public nft;
    MusicRendererOrchestrator public musicRenderer;
    AudioRenderer public audioRenderer;
    SongAlgorithm public songAlgorithm;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        console.log("=== DEPLOYING REAL CONTRACT ===");
        console.log("Current time:", block.timestamp);
        
        vm.startBroadcast(deployerPrivateKey);
        
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
            address(musicRenderer),
            address(audioRenderer),
            address(songAlgorithm)
        );
        
        // Mint 5 test tokens
        console.log("\n=== MINTING 5 TOKENS ===");
        for (uint256 i = 0; i < 5; i++) {
            uint32 seed = uint32(block.timestamp + i);
            nft.mint(msg.sender, seed);
            console.log("Minted token", i + 1, "with seed", seed);
        }
        
        vm.stopBroadcast();
        
        // Save addresses
        string memory addresses = string(abi.encodePacked(
            "NFT=", vm.toString(address(nft)), "\n",
            "MUSIC_RENDERER=", vm.toString(address(musicRenderer)), "\n",
            "AUDIO_RENDERER=", vm.toString(address(audioRenderer)), "\n",
            "SONG_ALGORITHM=", vm.toString(address(songAlgorithm)), "\n"
        ));
        vm.writeFile("deployed-timewarp.env", addresses);
        
        console.log("\n=== TESTING TIME MANIPULATION ===");
        
        // Get token 1 info
        uint256 rank1 = nft.getCurrentRank(1);
        console.log("Token 1 rank:", rank1);
        
        // In production, this would be Jan 1, 2026
        // We'll warp to that time to test
        uint256 year2026 = 1735689600; // Jan 1, 2026 00:00:00 UTC
        
        console.log("\nCurrent timestamp:", block.timestamp);
        console.log("Need to reach:", year2026);
        console.log("Time to warp:", year2026 - block.timestamp, "seconds");
        
        // NOTE: vm.warp only works in tests, not in scripts broadcasting to real networks
        // For local testing, see the Test contract version
        
        console.log("\n=== NEXT STEPS ===");
        console.log("To test reveals with time manipulation:");
        console.log("");
        console.log("OPTION 1 - Local Anvil (recommended):");
        console.log("1. anvil  # Start local blockchain");
        console.log("2. Deploy this script to local: --rpc-url http://localhost:8545");
        console.log("3. Fast-forward: cast rpc evm_increaseTime 31536000  # +1 year");
        console.log("4. Mine block: cast rpc anvil_mine 1");
        console.log("5. Check reveal: cast call $NFT 'tokenURI(uint256)' 1");
        console.log("");
        console.log("OPTION 2 - Foundry Test:");
        console.log("forge test --match-test testRevealTransition -vvv");
    }
}
