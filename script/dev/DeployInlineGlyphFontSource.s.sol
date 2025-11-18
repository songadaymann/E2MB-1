// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../src/render/pre/life/InlineGlyphFontSource.sol";

contract DeployInlineGlyphFontSource is Script {
    function run() external {
        string memory base64Path = vm.envOr(
            "LIFE_GLYPH_BASE64_PATH",
            string("script/data/life_bravura_subset_base64.txt")
        );
        bytes memory fontData = bytes(vm.readFile(base64Path));
        require(fontData.length > 0, "InlineGlyphFontSource: base64 empty");

        vm.startBroadcast();
        InlineGlyphFontSource source = new InlineGlyphFontSource();
        source.uploadFont(fontData);
        source.lockFont();
        vm.stopBroadcast();

        console2.log("InlineGlyphFontSource deployed at", address(source));
    }
}
