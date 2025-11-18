// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import "../../test/mocks/MockERC721.sol";
import "../../test/mocks/MockSeedSource.sol";
import "../../src/render/IRenderTypes.sol";
import "../../src/render/pre/life/LifeLensInit.sol";
import "../../src/render/pre/life/LifeToneHtmlRenderer.sol";
import "../../src/core/SongAlgorithm.sol";
import "../../test/mocks/MockToneSource.sol";
import "../../src/render/pre/life/InlineToneSource.sol";
import "../../src/render/pre/life/InlineGlyphFontSource.sol";

/// @notice Generates an HTML preview that uses the Tone.js-backed Life renderer.
contract PreviewLifeToneLens is Script {
    function run() external {
        bool doBroadcast = vm.envOr("PREVIEW_BROADCAST", false);
        if (doBroadcast) {
            vm.startBroadcast();
        }

        MockERC721 nft = new MockERC721();
        address previewOwner = vm.addr(2);
        if (previewOwner.code.length != 0) {
            // Forked networks may already have contracts at the deterministic cheatcode addr.
            // Fall back to a hashed address that should be empty.
            previewOwner = address(uint160(uint256(keccak256("life-tone-preview-owner"))));
            require(previewOwner.code.length == 0, "Preview owner already deployed");
        }
        nft.mint(previewOwner);

        SongAlgorithm algorithm = new SongAlgorithm();
        MockSeedSource seedSource = new MockSeedSource();
        seedSource.setTokenSeed(1, 0x1234BEEF);
        string memory sevenWords = _envOrString("PREVIEW_SEVEN_WORDS", "tone drives the chaos");
        seedSource.setSevenWords(1, keccak256(bytes(sevenWords)));
        seedSource.setPreviousNotesHash(keccak256("tone-preview-notes"));
        seedSource.setGlobalState(keccak256("tone-preview-global"));
        seedSource.setTotalMinted(64);
        seedSource.setCurrentRank(1, 12);
        seedSource.setRevealed(1, false);
        seedSource.setRevealTimestamp(1, 0);

        LifeLensInit lifeLens = new LifeLensInit(address(nft), seedSource, algorithm);

        address configuredToneSource = _envOrAddress("BEGINNING_JS_ADDRESS");
        address configuredFontSource = _envOrAddress("LIFE_GLYPH_FONT_ADDRESS");
        if (vm.envOr("PREVIEW_TONE_FROM_FILES", false)) {
            string memory tonePath = vm.envOr(
                "TONE_JS_BASE64_PATH",
                string("script/data/tone_js_base64.txt")
            );
            string memory gunzipPath = vm.envOr(
                "GUNZIP_JS_BASE64_PATH",
                string("script/data/gunzip_scripts_base64.txt")
            );
            InlineToneSource tempSource = new InlineToneSource();
            _seedInlineToneSource(tempSource, bytes(vm.readFile(tonePath)), false);
            _seedInlineToneSource(tempSource, bytes(vm.readFile(gunzipPath)), true);
            tempSource.lock(false);
            tempSource.lock(true);
            configuredToneSource = address(tempSource);
        }
        if (configuredFontSource == address(0) || vm.envOr("PREVIEW_FONT_FROM_FILES", false)) {
            string memory fontPath = vm.envOr(
                "LIFE_GLYPH_BASE64_PATH",
                string("script/data/life_bravura_subset_base64.txt")
            );
            InlineGlyphFontSource tempFont = new InlineGlyphFontSource();
            _seedInlineGlyphFont(tempFont, bytes(vm.readFile(fontPath)));
            configuredFontSource = address(tempFont);
        }
        LifeToneHtmlRenderer renderer;
        address effectiveToneSource;
        if (configuredToneSource == address(0)) {
            MockToneSource toneMock = new MockToneSource();
            renderer = new LifeToneHtmlRenderer(address(lifeLens), address(toneMock), configuredFontSource);
            effectiveToneSource = address(toneMock);
        } else {
            bool installBytecode = vm.envOr("BEGINNING_JS_INSTALL_BYTECODE", false);
            if (installBytecode) {
                string memory bytecodePath = vm.envOr("BEGINNING_JS_BYTECODE_PATH", string(""));
                require(bytes(bytecodePath).length > 0, "Bytecode path required");
                bytes memory toneBytecode = vm.readFileBinary(bytecodePath);
                require(toneBytecode.length > 0, "Tone bytecode empty");
                vm.etch(configuredToneSource, toneBytecode);
            }
            renderer = new LifeToneHtmlRenderer(address(lifeLens), configuredToneSource, configuredFontSource);
            effectiveToneSource = configuredToneSource;
        }

        if (doBroadcast) {
            vm.stopBroadcast();
        }

        console2.log("MockERC721:", address(nft));
        console2.log("MockSeedSource:", address(seedSource));
        console2.log("LifeLensInit:", address(lifeLens));
        console2.log("LifeToneHtmlRenderer:", address(renderer));
        console2.log("ToneSource:", effectiveToneSource);
        console2.log("FontSource:", configuredFontSource);

        RenderTypes.RenderCtx memory ctx = RenderTypes.RenderCtx({
            tokenId: 1,
            rank: 12,
            revealYear: 2026 + 12,
            closenessBps: 4200,
            blocksDisplay: 2_000_000,
            seed: seedSource.tokenSeed(1),
            nowTs: block.timestamp
        });

        string memory dataUri = renderer.render(ctx);
        string memory html = _decodeDataUri(dataUri);
        vm.writeFile("OUTPUTS/life_lens_tone_token_1.html", html);
    }

    function _envOrString(string memory key, string memory defaultValue) private returns (string memory) {
        try vm.envString(key) returns (string memory value) {
            return value;
        } catch {
            return defaultValue;
        }
    }

    function _envOrAddress(string memory key) private returns (address) {
        try vm.envAddress(key) returns (address value) {
            return value;
        } catch {
            return address(0);
        }
    }

    function _decodeDataUri(string memory dataUri) private pure returns (string memory) {
        bytes memory uriBytes = bytes(dataUri);
        bytes memory prefix = bytes("data:text/html;base64,");
        require(uriBytes.length > prefix.length, "PreviewLifeToneLens: invalid data URI");

        bytes memory base64Body = new bytes(uriBytes.length - prefix.length);
        for (uint256 i = 0; i < base64Body.length; i++) {
            base64Body[i] = uriBytes[i + prefix.length];
        }

        return string(_base64Decode(base64Body));
    }

    function _base64Decode(bytes memory data) private pure returns (bytes memory) {
        require(data.length % 4 == 0, "PreviewLifeToneLens: invalid base64");

        bytes memory table = _decodeTable();
        uint256 decodedLen = (data.length / 4) * 3;
        if (data.length != 0 && data[data.length - 1] == bytes1("=")) decodedLen--;
        if (data.length > 1 && data[data.length - 2] == bytes1("=")) decodedLen--;

        bytes memory result = new bytes(decodedLen);
        uint256 index;

        for (uint256 i = 0; i < data.length; i += 4) {
            uint256 chunk = (uint256(uint8(table[uint8(data[i])])) << 18)
                | (uint256(uint8(table[uint8(data[i + 1])])) << 12)
                | (uint256(uint8(table[uint8(data[i + 2])])) << 6)
                | uint256(uint8(table[uint8(data[i + 3])])); // '=' mapped to 0

            result[index++] = bytes1(uint8(chunk >> 16));
            if (data[i + 2] != bytes1("=")) {
                result[index++] = bytes1(uint8(chunk >> 8));
            }
            if (data[i + 3] != bytes1("=")) {
                result[index++] = bytes1(uint8(chunk));
            }
        }

        return result;
    }

    function _decodeTable() private pure returns (bytes memory table) {
        table = new bytes(256);
        bytes memory chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        for (uint256 i = 0; i < chars.length; i++) {
            table[uint256(uint8(chars[i]))] = bytes1(uint8(i));
        }
    }

    function _seedInlineToneSource(
        InlineToneSource source,
        bytes memory data,
        bool isGunzip
    ) private {
        uint256 chunkSize = 24_000;
        require(data.length > 0, "Preview: tone data empty");
        uint256 offset;
        while (offset < data.length) {
            uint256 remaining = data.length - offset;
            uint256 len = remaining < chunkSize ? remaining : chunkSize;
            bytes memory chunk = new bytes(len);
            for (uint256 i = 0; i < len; i++) {
                chunk[i] = data[offset + i];
            }
            source.uploadChunk(chunk, isGunzip);
            offset += len;
        }
    }

    function _seedInlineGlyphFont(InlineGlyphFontSource source, bytes memory data) private {
        require(data.length > 0, "Preview: font data empty");
        source.uploadFont(data);
        source.lockFont();
    }
}
