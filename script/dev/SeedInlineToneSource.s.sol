// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../src/render/pre/life/InlineToneSource.sol";

contract SeedInlineToneSource is Script {
    uint256 internal constant CHUNK_SIZE = 24_000;

    function run() external {
        address sourceAddr = vm.envOr(
            "INLINE_TONE_SOURCE_ADDRESS",
            vm.envAddress("BEGINNING_JS_ADDRESS")
        );
        InlineToneSource source = InlineToneSource(sourceAddr);

        string memory tonePath = vm.envOr(
            "TONE_JS_BASE64_PATH",
            string("script/data/tone_js_base64.txt")
        );
        string memory gunzipPath = vm.envOr(
            "GUNZIP_JS_BASE64_PATH",
            string("script/data/gunzip_scripts_base64.txt")
        );

        bytes memory toneData = bytes(vm.readFile(tonePath));
        bytes memory gunzipData = bytes(vm.readFile(gunzipPath));
        require(toneData.length > 0, "SeedInlineToneSource: tone empty");
        require(gunzipData.length > 0, "SeedInlineToneSource: gunzip empty");

        vm.startBroadcast();
        _upload(source, toneData, false);
        _upload(source, gunzipData, true);
        source.lock(false);
        source.lock(true);
        vm.stopBroadcast();

        console2.log("Seeded InlineToneSource", sourceAddr);
    }

    function _upload(InlineToneSource source, bytes memory data, bool isGunzip) internal {
        uint256 offset;
        while (offset < data.length) {
            uint256 remaining = data.length - offset;
            uint256 len = remaining < CHUNK_SIZE ? remaining : CHUNK_SIZE;
            bytes memory chunk = new bytes(len);
            for (uint256 i = 0; i < len; i++) {
                chunk[i] = data[offset + i];
            }
            source.uploadChunk(chunk, isGunzip);
            offset += len;
        }
    }
}
