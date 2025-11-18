// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../src/core/EveryTwoMillionBlocks.sol";
import "../../src/render/pre/IPreRevealRegistry.sol";

contract WireLifeLens is Script {
    function run() external {
        address msong = vm.envAddress("MSONG_ADDRESS");
        address svgRenderer = vm.envAddress("LIFE_LENS_SVG_RENDERER_ADDRESS");
        address htmlRenderer = vm.envAddress("LIFE_LENS_HTML_RENDERER_ADDRESS");

        vm.startBroadcast();
        address registryAddr = address(EveryTwoMillionBlocks(msong).preRevealRegistry());
        require(registryAddr != address(0), "Registry not set");
        IPreRevealRegistry registry = IPreRevealRegistry(registryAddr);
        uint256 rendererId = registry.addRenderer(
            svgRenderer,
            htmlRenderer,
            true
        );
        registry.setRendererRequiresSevenWords(rendererId, true);
        console2.log("Registered Life lens renderer id", rendererId);
        vm.stopBroadcast();
    }
}
