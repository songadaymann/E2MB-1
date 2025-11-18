// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockGlyphFontSource {
    function fontFaceCSS() external pure returns (string memory) {
        return "@font-face{font-family:'LifeGlyphs';src:url(data:font/woff2;base64,TEST) format('woff2');}";
    }
}
