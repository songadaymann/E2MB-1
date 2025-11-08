// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../src/core/EveryTwoMillionBlocks.sol";

/**
 * @title 02_DeployMain
 * @notice Deploys the main EveryTwoMillionBlocks NFT contract
 * @dev Phase 1, Step 2: Deploy main contract (renderers wired in step 3)
 * 
 * Prerequisites:
 *   - Run 01_DeployRenderers.s.sol first
 *   - Make sure deployed-renderers.env exists OR set addresses in .env
 * 
 * Run with:
 *   source .env
 *   source deployed-renderers.env
 *   forge script script/deploy/02_DeployMain.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 */
contract DeployMain is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying EveryTwoMillionBlocks NFT...");
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        
        // Deploy main contract (owner = deployer)
        EveryTwoMillionBlocks msong = new EveryTwoMillionBlocks();
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("EveryTwoMillionBlocks Address:", address(msong));
        console.log("Owner:", msong.owner());
        
        vm.stopBroadcast();

        console.log("\nFor next steps, export this address:");
        console.log("export MSONG_ADDRESS=%s", address(msong));
        console.log("\nNext step: Run 03_WireRenderers.s.sol");
    }
}
