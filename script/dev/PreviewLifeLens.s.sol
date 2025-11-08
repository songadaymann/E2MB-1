// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "../../test/mocks/MockERC721.sol";
import "../../test/mocks/MockSeedSource.sol";
import "../../src/render/pre/life/LifeLensRenderer.sol";
import "../../src/render/pre/life/LifeLensInit.sol";
import "../../src/core/SongAlgorithm.sol";

/// @notice Standalone script that materializes a Life lens preview under OUTPUTS/.
/// Runs entirely locally: deploys the mock NFT + lens renderer, fetches the
/// tokenURI for token #1, writes the decoded JSON, and expands the embedded HTML
/// to OUTPUTS/life_lens_token_1.html so it can be viewed in a browser.
contract PreviewLifeLens is Script {
    function run() external {
        MockERC721 nft = new MockERC721();
        address previewOwner = vm.addr(1);
        nft.mint(previewOwner);

        SongAlgorithm algorithm = new SongAlgorithm();
        MockSeedSource seedSource = new MockSeedSource();
        seedSource.setTokenSeed(1, 0xBEEF1234);
        seedSource.setSevenWords(1, keccak256("tap into the music"));
        seedSource.setPreviousNotesHash(keccak256("preview-notes"));
        seedSource.setGlobalState(keccak256("preview-global"));
        seedSource.setTotalMinted(50);
        seedSource.setCurrentRank(1, 18);
        seedSource.setRevealed(1, false);
        seedSource.setRevealTimestamp(1, 0);

        LifeLensInit initialLens = new LifeLensInit(address(nft), seedSource, algorithm);
        LifeLensRenderer renderer = new LifeLensRenderer(address(nft), address(initialLens));

        string memory tokenUri = renderer.tokenURI(1);
        string memory json = string(_decodeTokenURI(tokenUri));

        vm.writeFile("OUTPUTS/life_lens_token_1.json", json);

        string memory html = _extractHtml(json);
        vm.writeFile("OUTPUTS/life_lens_token_1.html", html);
    }

    function _decodeTokenURI(string memory tokenUri) private pure returns (bytes memory) {
        bytes memory uriBytes = bytes(tokenUri);
        bytes memory prefix = bytes("data:application/json;base64,");
        require(uriBytes.length > prefix.length, "PreviewLifeLens: short URI");

        bytes memory base64Body = new bytes(uriBytes.length - prefix.length);
        for (uint256 i = 0; i < base64Body.length; i++) {
            base64Body[i] = uriBytes[i + prefix.length];
        }
        return _base64Decode(base64Body);
    }

    function _extractHtml(string memory json) private pure returns (string memory) {
        bytes memory jsonBytes = bytes(json);
        bytes memory key = bytes('"animation_url":"data:text/html;base64,');
        int256 start = _indexOf(jsonBytes, key);
        require(start >= 0, "PreviewLifeLens: animation_url missing");

        uint256 htmlStart = uint256(start) + key.length;
        uint256 end = htmlStart;
        while (end < jsonBytes.length && jsonBytes[end] != '"') {
            end++;
        }

        bytes memory base64Html = new bytes(end - htmlStart);
        for (uint256 i = 0; i < base64Html.length; i++) {
            base64Html[i] = jsonBytes[htmlStart + i];
        }

        return string(_base64Decode(base64Html));
    }

    function _indexOf(bytes memory haystack, bytes memory needle) private pure returns (int256) {
        if (needle.length == 0 || needle.length > haystack.length) {
            return -1;
        }
        for (uint256 i = 0; i <= haystack.length - needle.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < needle.length; j++) {
                if (haystack[i + j] != needle[j]) {
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

    function _base64Decode(bytes memory data) private pure returns (bytes memory) {
        require(data.length % 4 == 0, "PreviewLifeLens: invalid base64 length");

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
}
