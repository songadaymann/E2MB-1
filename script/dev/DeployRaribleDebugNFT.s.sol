// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../../test/rarible_debug/RaribleDebugNFT.sol";

/**
 * @notice Deploys the RaribleDebugNFT contract to Sepolia and mints one token.
 *
 * Usage:
 *   source .env
 *   forge script script/dev/DeployRaribleDebugNFT.s.sol \
 *     --rpc-url $SEPOLIA_RPC_URL \
 *     --broadcast --legacy \
 *     --private-key $PRIVATE_KEY
 *
 * Optional env var:
 *   RARIBLE_DEBUG_MINT_TO - address to receive the first mint (defaults to deployer)
 */
contract DeployRaribleDebugNFT is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address mintTo = vm.envOr("RARIBLE_DEBUG_MINT_TO", vm.addr(deployerKey));
        string memory customUri = vm.envOr("RARIBLE_DEBUG_CUSTOM_URI", string(""));

        vm.startBroadcast(deployerKey);

        RaribleDebugNFT nft = new RaribleDebugNFT();
        uint256 tokenId = nft.mint(mintTo, customUri);

        vm.stopBroadcast();

        console2.log("RaribleDebugNFT deployed at", address(nft));
        console2.log("Minted token ID", tokenId, "to", mintTo);
        console2.log("Custom URI used:", bytes(customUri).length == 0 ? nft.DEFAULT_TOKEN_URI() : customUri);
        console2.log("Verify with:");
        console2.log(
            "  forge script script/dev/DeployRaribleDebugNFT.s.sol --sig run "
            "--rpc-url $SEPOLIA_RPC_URL --verify --etherscan-api-key $ETHERSCAN_API_KEY --broadcast --legacy --private-key $PRIVATE_KEY"
        );
    }
}
