// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ILifeLens.sol";

library LifeSVG {
    function generateSVG(ILifeLens.LifeBoard memory board, bytes[2] memory colors) internal pure returns (string memory) {
        require(board.width > 0 && board.height > 0, "LifeSVG: empty board");
        require(board.initialCells.length == uint256(board.width) * board.height, "LifeSVG: invalid seed");
        uint256 cellSize = 72;
        uint256 padding = 16;
        uint256 inset = 8;
        // Slightly smaller glyphs so ledger symbols stay within each cell’s bounds
        uint256 glyphFont = (cellSize * 11) / 20;
        uint256 svgWidth = padding * 2 + cellSize * board.width;
        uint256 svgHeight = padding * 2 + cellSize * board.height;

        bytes memory svgHeader = abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ',
            _toString(svgWidth),
            " ",
            _toString(svgHeight),
            '" width="',
            _toString(svgWidth),
            '" height="',
            _toString(svgHeight),
            '" shape-rendering="crispEdges">',
            '<rect width="100%" height="100%" fill="',
            colors[0],
            '"/>'
        );

        bytes memory defs = abi.encodePacked(
            "<style>",
            ".grid line{stroke:#2a2a2a;stroke-width:1.25;opacity:1;}",
            ".cell{fill:transparent;stroke:none;opacity:0;}",
            ".label{fill:",
            colors[1],
            ';font-size:22px;font-family:"Inter","Helvetica Neue",Arial,sans-serif;letter-spacing:2px;text-transform:uppercase;opacity:0.4;pointer-events:none;}',
            ".glyph{fill:",
            colors[1],
            ";opacity:0;font-family:'LifeGlyphs','Noto Music','Bravura','Petaluma','Apple Symbols','Segoe UI Symbol','IBM Plex Mono','SFMono-Regular','Menlo','Monaco','Consolas','Courier New',monospace;font-size:",
            _toString(glyphFont),
            "px;text-anchor:middle;dominant-baseline:central;pointer-events:none;}",
            "</style>"
        );

        bytes memory gridLines;
        for (uint256 x = 0; x <= board.width; x++) {
            uint256 xCoord = padding + x * cellSize;
            gridLines = abi.encodePacked(
                gridLines,
                '<line x1="',
                _toString(xCoord),
                '" y1="',
                _toString(padding),
                '" x2="',
                _toString(xCoord),
                '" y2="',
                _toString(svgHeight - padding),
                '"/>'
            );
        }
        for (uint256 y = 0; y <= board.height; y++) {
            uint256 yCoord = padding + y * cellSize;
            gridLines = abi.encodePacked(
                gridLines,
                '<line y1="',
                _toString(yCoord),
                '" x1="',
                _toString(padding),
                '" y2="',
                _toString(yCoord),
                '" x2="',
                _toString(svgWidth - padding),
                '"/>'
            );
        }

        bytes memory rects;
        bytes memory glyphs;
        uint256 index = 0;
        for (uint256 y = 0; y < board.height; y++) {
            for (uint256 x = 0; x < board.width; x++) {
                bool alive = board.initialCells[index] == bytes1(uint8(1));
                string memory rectOpacity = alive ? "0.08" : "0";
                string memory glyphOpacity = alive ? "1" : "0";
                bytes1 glyphChar = alive ? _glyphForIndex(index) : bytes1(uint8(32)); // space for dead
                uint256 rectX = padding + x * cellSize + inset / 2;
                uint256 rectY = padding + y * cellSize + inset / 2;
                uint256 rectSize = cellSize - inset;
                uint256 glyphX = rectX + rectSize / 2;
                uint256 glyphY = rectY + rectSize / 2;
                rects = abi.encodePacked(
                    rects,
                    '<rect class="cell" data-idx="',
                    _toString(index),
                    '" x="',
                    _toString(rectX),
                    '" y="',
                    _toString(rectY),
                    '" width="',
                    _toString(rectSize),
                    '" height="',
                    _toString(rectSize),
                    '" rx="8" ry="8" style="opacity:',
                    rectOpacity,
                    '"/>'
                );
                glyphs = abi.encodePacked(
                    glyphs,
                    '<text class="glyph" data-idx="',
                    _toString(index),
                    '" x="',
                    _toString(glyphX),
                    '" y="',
                    _toString(glyphY),
                    '" style="opacity:',
                    glyphOpacity,
                    '">',
                    glyphChar,
                    "</text>"
                );
                index++;
            }
        }

        return string(
            abi.encodePacked(
                svgHeader,
                defs,
                '<g class="grid">',
                gridLines,
                "</g>",
                rects,
                glyphs,
                "</svg>"
            )
        );
    }

    function _toString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(buffer);
    }


    function _glyphForIndex(uint256 index) internal pure returns (bytes1) {
        bytes memory glyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789#%*+=?@$/!^";
        return glyphs[index % glyphs.length];
    }
}
