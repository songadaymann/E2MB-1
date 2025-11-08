// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ILifeLens.sol";

library LifeSVG {
    function generateSVG(ILifeLens.LifeBoard memory board, bytes[2] memory colors) internal pure returns (string memory) {
        require(board.width > 0 && board.height > 0, "LifeSVG: empty board");
        require(board.initialCells.length == uint256(board.width) * board.height, "LifeSVG: invalid seed");
        uint256 cellSize = 72;
        uint256 padding = 16;
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
            ".grid line{stroke:#222;stroke-width:1.25;opacity:0.35;}",
            ".cell{transition:opacity 0.25s ease-in-out,transform 0.4s ease;fill:",
            colors[1],
            ";opacity:0;transform-origin:50% 50%;}",
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
        uint256 index = 0;
        for (uint256 y = 0; y < board.height; y++) {
            for (uint256 x = 0; x < board.width; x++) {
                bool alive = board.initialCells[index] == bytes1(uint8(1));
                uint256 rectX = padding + x * cellSize;
                uint256 rectY = padding + y * cellSize;
                rects = abi.encodePacked(
                    rects,
                    '<rect class="cell" data-idx="',
                    _toString(index),
                    '" x="',
                    _toString(rectX),
                    '" y="',
                    _toString(rectY),
                    '" width="',
                    _toString(cellSize),
                    '" height="',
                    _toString(cellSize),
                    '" rx="6" ry="6" style="opacity:',
                    alive ? "1" : "0",
                    '"/>'
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

}
