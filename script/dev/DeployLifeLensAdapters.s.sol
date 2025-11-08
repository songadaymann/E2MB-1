// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "../../src/render/pre/life/LifeLensInit.sol";
import "../../src/render/pre/life/LifeLensSvgRenderer.sol";
import "../../src/render/pre/life/LifeLensHtmlRenderer.sol";

contract DeployLifeLensAdapters is Script {
    function run() external {
        address lifeLensInit = vm.envAddress("LIFE_LENS_INIT_ADDRESS");

        vm.startBroadcast();

        LifeLensSvgRenderer svgRenderer = new LifeLensSvgRenderer(lifeLensInit);
        LifeLensHtmlRenderer htmlRenderer = new LifeLensHtmlRenderer(lifeLensInit);

        vm.stopBroadcast();

        console2.log("LifeLensSvgRenderer deployed at", address(svgRenderer));
        console2.log("LifeLensHtmlRenderer deployed at", address(htmlRenderer));
    }
}
