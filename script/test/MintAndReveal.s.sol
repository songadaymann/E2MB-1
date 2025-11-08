// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/core/EveryTwoMillionBlocks.sol";

/**
 * @title MintAndReveal
 * @notice Mint a token and force-reveal it for testing
 * @dev Generates a revealed token you can view immediately
 * 
 * Run with:
 *   source .env
 *   source deployed-main.env
 *   forge script script/test/MintAndReveal.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
 */
contract MintAndReveal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address msongAddress = vm.envAddress("MSONG_ADDRESS");
        
        console.log("Minting and revealing token...");
        console.log("Contract:", msongAddress);
        console.log("Minting to:", deployer);
        
        vm.startBroadcast(deployerPrivateKey);
        
        EveryTwoMillionBlocks msong = EveryTwoMillionBlocks(msongAddress);
        
        // Mint token with random seed
        uint32 seed = uint32(uint256(keccak256(abi.encodePacked(block.timestamp, deployer))));
        msong.mint(deployer, seed);
        
        uint256 tokenId = msong.totalSupply();
        console.log("\nMinted token #%s with seed %s", tokenId, seed);
        
        // Force reveal (test-only function)
        msong.forceReveal(tokenId);
        console.log("Token revealed!");
        
        // Get the reveal data
        (int16 leadPitch, uint32 leadDur) = msong.revealedLeadNote(tokenId);
        (int16 bassPitch, uint32 bassDur) = msong.revealedBassNote(tokenId);
        
        console.log("\n=== REVEALED NOTES ===");
        if (leadPitch == -1) {
            console.log("Lead: REST");
        } else {
            console.log("Lead: MIDI %s (duration %s ticks)", uint16(leadPitch), leadDur);
        }
        console.log("Bass: MIDI %s (duration %s ticks)", uint16(bassPitch), bassDur);
        
        vm.stopBroadcast();
        
        console.log("\n=== NEXT STEPS ===");
        console.log("View metadata:");
        console.log("  cast call %s 'tokenURI(uint256)' %s --rpc-url $SEPOLIA_RPC_URL", msongAddress, tokenId);
        console.log("\nDecode and save:");
        console.log("  forge script script/test/DecodeMetadata.s.sol --sig 'run(uint256)' %s", tokenId);
        console.log("\nView on Rarible:");
        console.log("  https://testnet.rarible.com/token/sepolia/%s:%s", msongAddress, tokenId);
    }
}
