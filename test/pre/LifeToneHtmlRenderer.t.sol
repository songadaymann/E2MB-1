
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/render/pre/life/LifeLensInit.sol";
import "../../src/render/pre/life/LifeToneHtmlRenderer.sol";
import "../../src/render/IRenderTypes.sol";
import "../../src/core/SongAlgorithm.sol";
import "../mocks/MockERC721.sol";
import "../mocks/MockSeedSource.sol";
import "../mocks/MockToneSource.sol";
import "../mocks/MockGlyphFontSource.sol";

contract LifeToneHtmlRendererTest is Test {
    LifeLensInit private lifeLens;
    LifeToneHtmlRenderer private renderer;
    MockToneSource private toneSource;
    MockGlyphFontSource private fontSource;
    MockERC721 private nft;
    MockSeedSource private seedSource;
    address private owner = address(0x1);

    function setUp() public {
        nft = new MockERC721();
        vm.startPrank(owner);
        uint256 tokenId = nft.mint(owner);
        assertEq(tokenId, 1);
        vm.stopPrank();

        SongAlgorithm algorithm = new SongAlgorithm();
        seedSource = new MockSeedSource();
        seedSource.setTokenSeed(1, 0x12345678);
        seedSource.setSevenWords(1, keccak256("tone life words"));
        seedSource.setSevenWordsText(1, "tone life words");
        seedSource.setPreviousNotesHash(keccak256("tone-prev"));
        seedSource.setGlobalState(keccak256("tone-global"));
        seedSource.setTotalMinted(100);
        seedSource.setCurrentRank(1, 42);
        seedSource.setRevealed(1, false);
        seedSource.setRevealTimestamp(1, 0);

        lifeLens = new LifeLensInit(address(nft), seedSource, algorithm);
        toneSource = new MockToneSource();
        fontSource = new MockGlyphFontSource();
        renderer = new LifeToneHtmlRenderer(address(lifeLens), address(toneSource), address(fontSource));
    }

    function testRenderProducesToneHtml() public {
        RenderTypes.RenderCtx memory ctx = RenderTypes.RenderCtx({
            tokenId: 1,
            rank: 42,
            revealYear: 2026 + 42,
            closenessBps: 4200,
            blocksDisplay: 2_000_000,
            seed: seedSource.tokenSeed(1),
            nowTs: block.timestamp
        });

        string memory dataUri = renderer.render(ctx);
        assertTrue(bytes(dataUri).length > 0);
        assertTrue(_startsWith(dataUri, "data:text/html;base64,"));

        string memory html = string(_decodeBase64(_stripPrefix(dataUri)));
        assertTrue(_contains(html, "Tone.MonoSynth"));
        assertTrue(_contains(html, "Tone.PolySynth"));
        assertTrue(_contains(html, "padSynth.triggerAttack("));
        assertTrue(_contains(html, "const primeTone"));
        assertTrue(_contains(html, "registerPrimeTarget(document)"));
        assertTrue(_contains(html, "window.mockToneLoaded"));
        assertTrue(_contains(html, "window.lifeLensPlay"));
        assertTrue(_contains(html, "life-overlay"));
        assertFalse(_contains(html, "life-play"));
    }

    function _stripPrefix(string memory dataUri) private pure returns (bytes memory) {
        bytes memory uriBytes = bytes(dataUri);
        bytes memory prefix = bytes("data:text/html;base64,");
        bytes memory body = new bytes(uriBytes.length - prefix.length);
        for (uint256 i = 0; i < body.length; i++) {
            body[i] = uriBytes[i + prefix.length];
        }
        return body;
    }

    function _decodeBase64(bytes memory data) private pure returns (bytes memory) {
        require(data.length % 4 == 0, "LifeToneHtmlRendererTest: bad base64 len");
        bytes memory table = _decodeTable();
        uint256 decodedLen = (data.length / 4) * 3;
        if (data.length != 0 && data[data.length - 1] == bytes1("=")) decodedLen--;
        if (data.length > 1 && data[data.length - 2] == bytes1("=")) decodedLen--;

        bytes memory result = new bytes(decodedLen);
        uint256 idx;
        for (uint256 i = 0; i < data.length; i += 4) {
            uint256 chunk = (uint256(uint8(table[uint8(data[i])])) << 18)
                | (uint256(uint8(table[uint8(data[i + 1])])) << 12)
                | (uint256(uint8(table[uint8(data[i + 2])])) << 6)
                | uint256(uint8(table[uint8(data[i + 3])])); // '=' mapped to 0

            result[idx++] = bytes1(uint8(chunk >> 16));
            if (data[i + 2] != bytes1("=")) {
                result[idx++] = bytes1(uint8(chunk >> 8));
            }
            if (data[i + 3] != bytes1("=")) {
                result[idx++] = bytes1(uint8(chunk));
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

    function _startsWith(string memory haystack, string memory prefix) private pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory prefixBytes = bytes(prefix);
        if (prefixBytes.length > haystackBytes.length) return false;
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (haystackBytes[i] != prefixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function _contains(string memory haystack, string memory needle) private pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);
        if (needleBytes.length == 0 || needleBytes.length > haystackBytes.length) {
            return false;
        }
        for (uint256 i = 0; i <= haystackBytes.length - needleBytes.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < needleBytes.length; j++) {
                if (haystackBytes[i + j] != needleBytes[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) {
                return true;
            }
        }
        return false;
    }
}
