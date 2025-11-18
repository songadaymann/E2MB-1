// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../src/core/EveryTwoMillionBlocks.sol";
import "../../src/render/pre/IPreRevealRegistry.sol";

contract InspectRendererChoices is Script {
    function run() external {
        address msong = vm.envAddress("MSONG_ADDRESS");
        uint256 tokenId = vm.envOr("INSPECT_TOKEN_ID", uint256(1));

        address registryAddr = address(EveryTwoMillionBlocks(msong).preRevealRegistry());
        require(registryAddr != address(0), "Registry not set");
        IPreRevealRegistry registry = IPreRevealRegistry(registryAddr);
        (uint256 rendererId, bool isCustom) = registry.getTokenRenderer(tokenId);
        console2.log("token", tokenId);
        console2.log("rendererId", rendererId);
        console2.log("isCustom", isCustom);
        console2.log("defaultRendererId", registry.defaultRendererId());
    }
}
