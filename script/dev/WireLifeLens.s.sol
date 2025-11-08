// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "../../src/core/EveryTwoMillionBlocks.sol";

contract WireLifeLens is Script {
    function run() external {
        address msong = vm.envAddress("MSONG_ADDRESS");
        address svgRenderer = vm.envAddress("LIFE_LENS_SVG_RENDERER_ADDRESS");
        address htmlRenderer = vm.envAddress("LIFE_LENS_HTML_RENDERER_ADDRESS");

        vm.startBroadcast();
        uint256 rendererId = EveryTwoMillionBlocks(msong).addPreRevealRenderer(
            svgRenderer,
            htmlRenderer,
            true
        );
        console2.log("Registered Life lens renderer id", rendererId);
        vm.stopBroadcast();
    }
}
