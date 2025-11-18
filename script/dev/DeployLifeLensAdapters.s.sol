// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../src/render/pre/life/LifeLensInit.sol";
import "../../src/render/pre/life/LifeLensSvgRenderer.sol";
import "../../src/render/pre/life/LifeToneHtmlRenderer.sol";

contract DeployLifeLensAdapters is Script {
    function run() external {
        address lifeLensInit = vm.envAddress("LIFE_LENS_INIT_ADDRESS");
        address toneSource = vm.envAddress("BEGINNING_JS_ADDRESS");
        address glyphFont = vm.envAddress("LIFE_GLYPH_FONT_ADDRESS");

        vm.startBroadcast();

        LifeLensSvgRenderer svgRenderer = new LifeLensSvgRenderer(lifeLensInit);
        LifeToneHtmlRenderer htmlRenderer = new LifeToneHtmlRenderer(lifeLensInit, toneSource, glyphFont);

        vm.stopBroadcast();

        console2.log("LifeLensSvgRenderer deployed at", address(svgRenderer));
        console2.log("LifeToneHtmlRenderer deployed at", address(htmlRenderer));
    }
}
