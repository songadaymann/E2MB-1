// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/core/EveryTwoMillionBlocks.sol";

/**
 * @title 03_WireRenderers
 * @notice Connects the rendering contracts to EveryTwoMillionBlocks
 * @dev Phase 1, Step 3: Wire everything together
 * 
 * Prerequisites:
 *   - Run 01_DeployRenderers.s.sol
 *   - Run 02_DeployMain.s.sol
 *   - Addresses in deployed-renderers.env and deployed-main.env
 * 
 * Run with:
 *   source .env
 *   source deployed-renderers.env
 *   source deployed-main.env
 *   forge script script/deploy/03_WireRenderers.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
 */
contract WireRenderers is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Load deployed addresses
        address msongAddress = vm.envAddress("MSONG_ADDRESS");
        address musicRendererAddress = vm.envAddress("MUSIC_RENDERER_ADDRESS");
        address audioRendererAddress = vm.envAddress("AUDIO_RENDERER_ADDRESS");
        address songAlgorithmAddress = vm.envAddress("SONG_ALGORITHM_ADDRESS");
        address countdownSvgAddress = vm.envAddress("COUNTDOWN_SVG_ADDRESS");
        address countdownHtmlAddress = vm.envAddress("COUNTDOWN_HTML_ADDRESS");
        
        console.log("Wiring renderers to EveryTwoMillionBlocks...");
        console.log("EveryTwoMillionBlocks:", msongAddress);
        console.log("MusicRenderer:", musicRendererAddress);
        console.log("AudioRenderer:", audioRendererAddress);
        console.log("SongAlgorithm:", songAlgorithmAddress);
        console.log("Countdown SVG:", countdownSvgAddress);
        console.log("Countdown HTML:", countdownHtmlAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        
        EveryTwoMillionBlocks msong = EveryTwoMillionBlocks(msongAddress);
        
        // Set renderer addresses (songAlgorithm, music, audio)
        msong.setRenderers(
            songAlgorithmAddress,
            musicRendererAddress,
            audioRendererAddress
        );
        
        msong.setCountdownRenderer(countdownSvgAddress);
        msong.setCountdownHtmlRenderer(countdownHtmlAddress);
        
        console.log("\n=== WIRING COMPLETE ===");
        console.log("Renderers connected successfully!");
        console.log("\nYou can now:");
        console.log("1. Mint tokens: forge script script/test/MintAndReveal.s.sol");
        console.log("2. Force reveal: cast send $MSONG_ADDRESS 'forceReveal(uint256)' 1");
        console.log("3. View metadata: cast call $MSONG_ADDRESS 'tokenURI(uint256)' 1");
        
        vm.stopBroadcast();
    }
}
