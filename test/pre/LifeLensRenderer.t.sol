// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/render/pre/life/LifeLensRenderer.sol";
import "../../src/render/pre/life/LifeLensInit.sol";
import "../../src/core/SongAlgorithm.sol";
import "../mocks/MockERC721.sol";
import "../mocks/MockSeedSource.sol";

contract LifeLensRendererTest is Test {
    MockERC721 private nft;
    LifeLensInit private initialLens;
    LifeLensRenderer private renderer;
    SongAlgorithm private algorithm;
    MockSeedSource private seedSource;

    address private owner = address(0x1);
    address private user = address(0x2);

    function setUp() public {
        nft = new MockERC721();
        vm.startPrank(owner);
        uint256 tokenId = nft.mint(owner);
        assertEq(tokenId, 1);
        vm.stopPrank();

        algorithm = new SongAlgorithm();
        seedSource = new MockSeedSource();
        seedSource.setTokenSeed(1, 0xBEEF);
        seedSource.setSevenWords(1, keccak256("words"));
        seedSource.setPreviousNotesHash(keccak256("prev"));
        seedSource.setGlobalState(keccak256("global"));
        seedSource.setTotalMinted(50);
        seedSource.setCurrentRank(1, 25);
        seedSource.setRevealed(1, false);
        seedSource.setRevealTimestamp(1, 0);

        initialLens = new LifeLensInit(address(nft), seedSource, algorithm);
        renderer = new LifeLensRenderer(address(nft), address(initialLens));
    }

    function testTokenURIProducesJson() public {
        string memory tokenUri = renderer.tokenURI(1);
        assertTrue(bytes(tokenUri).length > 0);
        assertTrue(_startsWith(tokenUri, "data:application/json;base64,"));

        string memory json = _decodeJson(tokenUri);
        assertTrue(_contains(json, '"name":"Life Lens'));
        assertTrue(_contains(json, '"description":"Game of Life pre-reveal lens."'));
        string memory html = _extractHtml(json);
        assertTrue(_contains(html, "baseLeadSeq"));
        assertTrue(_contains(html, "midiToFreq"));
        assertTrue(_contains(html, "const baseSeed="));
        assertTrue(_contains(html, "const chaos="));
    }

    function testSetTokenLens() public {
        LifeLensInit lensTwo = new LifeLensInit(address(nft), seedSource, algorithm);
        renderer.registerLens(2, address(lensTwo));

        vm.prank(owner);
        renderer.setTokenLens(1, 2);

        assertEq(renderer.getTokenLens(1), 2);
        string memory tokenUri = renderer.tokenURI(1);
        assertTrue(_startsWith(tokenUri, "data:application/json;base64,"));
        string memory json = _decodeJson(tokenUri);
        assertTrue(_contains(json, lensTwo.name()));
        string memory html = _extractHtml(json);
        assertTrue(_contains(html, "baseLeadSeq"));
        assertTrue(_contains(html, "const baseSeed="));
        assertTrue(_contains(html, "const chaos="));
    }

    function testUnauthorizedSetLensReverts() public {
        vm.expectRevert("LifeLensRenderer: not authorized");
        renderer.setTokenLens(1, 1);
    }

    function _startsWith(string memory haystack, string memory prefix) private pure returns (bool) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory prefixBytes = bytes(prefix);
        if (prefixBytes.length > haystackBytes.length) {
            return false;
        }
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (haystackBytes[i] != prefixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function _decodeJson(string memory tokenUri) private pure returns (string memory) {
        bytes memory uriBytes = bytes(tokenUri);
        uint256 prefixLen = bytes("data:application/json;base64,").length;
        bytes memory base64Body = new bytes(uriBytes.length - prefixLen);
        for (uint256 i = prefixLen; i < uriBytes.length; i++) {
            base64Body[i - prefixLen] = uriBytes[i];
        }
        return string(_decodeBase64(base64Body));
    }

    function _decodeBase64(bytes memory data) private pure returns (bytes memory) {
        require(data.length % 4 == 0, "invalid Base64 length");
        bytes memory table = _decodeTable();
        uint256 decodedLen = (data.length / 4) * 3;
        if (data.length != 0 && data[data.length - 1] == bytes1("=")) decodedLen--;
        if (data.length > 1 && data[data.length - 2] == bytes1("=")) decodedLen--;

        bytes memory result = new bytes(decodedLen);
        uint256 resultIndex;

        for (uint256 i = 0; i < data.length; i += 4) {
            uint256 chunk = (uint256(uint8(table[uint8(data[i])])) << 18)
                | (uint256(uint8(table[uint8(data[i + 1])])) << 12)
                | (uint256(uint8(table[uint8(data[i + 2])])) << 6)
                | uint256(uint8(table[uint8(data[i + 3])])); // '=' mapped to 0

            result[resultIndex++] = bytes1(uint8(chunk >> 16));
            if (data[i + 2] != bytes1("=")) {
                result[resultIndex++] = bytes1(uint8(chunk >> 8));
            }
            if (data[i + 3] != bytes1("=")) {
                result[resultIndex++] = bytes1(uint8(chunk));
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

    function _extractHtml(string memory json) private pure returns (string memory) {
        string memory key = '"animation_url":"data:text/html;base64,';
        int256 start = _indexOf(json, key);
        require(start >= 0, "LifeLensRendererTest: animation URL missing");
        bytes memory jsonBytes = bytes(json);
        uint256 htmlStart = uint256(start) + bytes(key).length;
        uint256 end = htmlStart;
        while (end < jsonBytes.length && jsonBytes[end] != '"') {
            end++;
        }
        bytes memory encoded = new bytes(end - htmlStart);
        for (uint256 i = 0; i < encoded.length; i++) {
            encoded[i] = jsonBytes[htmlStart + i];
        }
        return string(_decodeBase64(encoded));
    }

    function _contains(string memory haystack, string memory needle) private pure returns (bool) {
        return bytes(haystack).length >= bytes(needle).length && _indexOf(haystack, needle) >= 0;
    }

    function _indexOf(string memory haystack, string memory needle) private pure returns (int256) {
        bytes memory haystackBytes = bytes(haystack);
        bytes memory needleBytes = bytes(needle);
        if (needleBytes.length == 0 || needleBytes.length > haystackBytes.length) {
            return -1;
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
                return int256(i);
            }
        }
        return -1;
    }
}
