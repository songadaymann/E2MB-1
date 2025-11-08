// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Layout Test
 * @notice Just tests placing static digits in the right positions for any block count
 * @dev No animation - just figuring out the grid placement
 */
contract LayoutTest is Script {
    
    function run() external {
        // Test different block counts
        _testLayout(694054, "694054");
        _testLayout(49583402840, "49583402840");
        _testLayout(123, "123");
        _testLayout(1234567890, "1234567890");
    }
    
    function _testLayout(uint256 blockCount, string memory label) private {
        console.log("Testing layout for:", label);
        
        // Count digits
        uint256 numDigits = _countDigits(blockCount);
        console.log("Number of digits:", numDigits);
        
        // Calculate grid positions for each digit
        console.log("Positions (row, col):");
        for (uint256 i = 0; i < numDigits; i++) {
            uint256 place = i; // 0 = ones, 1 = tens, etc.
            uint256 digit = (blockCount / (10 ** place)) % 10;
            
            // 4 columns, right-aligned, bottom row first
            uint256 col = 3 - (place % 4); // Right-align: 3,2,1,0
            uint256 row = place / 4; // Bottom row = 0, then up
            
            console.log("  Digit at row/col:", digit, row, col);
        }
        
        // Generate SVG
        string memory svg = _generateLayoutSVG(blockCount, label);
        string memory filename = string(abi.encodePacked("OUTPUTS/layout-", label, ".svg"));
        vm.writeFile(filename, svg);
        console.log("Generated:", filename);
        console.log("");
    }
    
    function _generateLayoutSVG(uint256 blockCount, string memory label) private pure returns (string memory) {
        uint256 numDigits = _countDigits(blockCount);
        uint256 numRows = (numDigits + 3) / 4;
        
        // Calculate total content height and center it
        uint256 digitsHeight = numRows * 120; // Rows stacked 120px apart
        uint256 gapToBar = 150; // Space between digits and bar
        uint256 barHeight = 16;
        uint256 totalHeight = digitsHeight + gapToBar + barHeight;
        uint256 topY = (600 - totalHeight) / 2;
        uint256 baseY = topY + digitsHeight; // Bottom row position
        uint256 horizontalOffset = 0; // No horizontal shift
        
        // Build digit placements row by row
        string memory digits = "";
        for (uint256 row = 0; row < numRows; row++) {
            // Figure out how many digits in this row
            uint256 digitsInRow;
            if (row < numRows - 1) {
                digitsInRow = 4; // Full rows
            } else {
                // Top row may have 1-4 digits
                digitsInRow = numDigits % 4;
                if (digitsInRow == 0) digitsInRow = 4;
            }
            
            // Center this row
            uint256 rowWidth = digitsInRow * 100;
            uint256 rowStartX = (600 - rowWidth) / 2 + horizontalOffset;
            uint256 y = baseY - (row * 120);
            
            // Add digits for this row
            for (uint256 colInRow = 0; colInRow < digitsInRow; colInRow++) {
                uint256 place = (row * 4) + (digitsInRow - 1 - colInRow); // Right to left
                uint256 digit = (blockCount / (10 ** place)) % 10;
                uint256 x = rowStartX + (colInRow * 100);
                
                digits = string(abi.encodePacked(
                    digits,
                    '<g transform="translate(', _uint2str(x), ',', _uint2str(y), ') scale(2)">',
                    '<use href="#d', _uint2str(digit), '"/>',
                    '</g>'
                ));
            }
        }
        
        // Progress bar - wide, centered
        uint256 barWidth = 500;
        uint256 barX = (600 - barWidth) / 2 + horizontalOffset;
        uint256 barY = baseY + gapToBar;
        string memory progressBar = string(abi.encodePacked(
            '<rect x="', _uint2str(barX), '" y="', _uint2str(barY), '" width="', _uint2str(barWidth), '" height="16" fill="#222" stroke="#444" stroke-width="2"/>',
            '<rect x="', _uint2str(barX + 2), '" y="', _uint2str(barY + 2), '" width="', _uint2str(barWidth - 4), '" height="12" fill="#fff"/>'
        ));
        
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
            '<defs>',
            _digitGlyphs(),
            '</defs>',
            '<rect width="600" height="600" fill="#000"/>',
            '<text x="300" y="30" fill="#fff" font-family="monospace" font-size="14" text-anchor="middle">',
            label, ' blocks',
            '</text>',
            '<g fill="#fff">',
            digits,
            '</g>',
            progressBar,
            '</svg>'
        ));
    }
    
    function _countDigits(uint256 value) private pure returns (uint256) {
        if (value == 0) return 1;
        uint256 digits = 0;
        while (value > 0) {
            digits++;
            value /= 10;
        }
        return digits;
    }
    
    function _digitGlyphs() private pure returns (string memory) {
        return string(abi.encodePacked(
            '<g id="d0" transform="translate(4,0)"><rect x="0" y="0" width="16" height="4"/><rect x="-4" y="4" width="4" height="16"/><rect x="16" y="4" width="4" height="16"/><rect x="-4" y="22" width="4" height="16"/><rect x="16" y="22" width="4" height="16"/><rect x="0" y="36" width="16" height="4"/></g>',
            '<g id="d1" transform="translate(4,0)"><rect x="16" y="4" width="4" height="16"/><rect x="16" y="22" width="4" height="16"/></g>',
            '<g id="d2" transform="translate(4,0)"><rect x="0" y="0" width="16" height="4"/><rect x="16" y="4" width="4" height="16"/><rect x="0" y="18" width="16" height="4"/><rect x="-4" y="22" width="4" height="16"/><rect x="0" y="36" width="16" height="4"/></g>',
            '<g id="d3" transform="translate(4,0)"><rect x="0" y="0" width="16" height="4"/><rect x="16" y="4" width="4" height="16"/><rect x="0" y="18" width="16" height="4"/><rect x="16" y="22" width="4" height="16"/><rect x="0" y="36" width="16" height="4"/></g>',
            '<g id="d4" transform="translate(4,0)"><rect x="-4" y="4" width="4" height="16"/><rect x="0" y="18" width="16" height="4"/><rect x="16" y="4" width="4" height="16"/><rect x="16" y="22" width="4" height="16"/></g>',
            '<g id="d5" transform="translate(4,0)"><rect x="0" y="0" width="16" height="4"/><rect x="-4" y="4" width="4" height="16"/><rect x="0" y="18" width="16" height="4"/><rect x="16" y="22" width="4" height="16"/><rect x="0" y="36" width="16" height="4"/></g>',
            '<g id="d6" transform="translate(4,0)"><rect x="0" y="0" width="16" height="4"/><rect x="-4" y="4" width="4" height="16"/><rect x="0" y="18" width="16" height="4"/><rect x="-4" y="22" width="4" height="16"/><rect x="16" y="22" width="4" height="16"/><rect x="0" y="36" width="16" height="4"/></g>',
            '<g id="d7" transform="translate(4,0)"><rect x="0" y="0" width="16" height="4"/><rect x="16" y="4" width="4" height="16"/><rect x="16" y="22" width="4" height="16"/></g>',
            '<g id="d8" transform="translate(4,0)"><rect x="0" y="0" width="16" height="4"/><rect x="-4" y="4" width="4" height="16"/><rect x="16" y="4" width="4" height="16"/><rect x="0" y="18" width="16" height="4"/><rect x="-4" y="22" width="4" height="16"/><rect x="16" y="22" width="4" height="16"/><rect x="0" y="36" width="16" height="4"/></g>',
            '<g id="d9" transform="translate(4,0)"><rect x="0" y="0" width="16" height="4"/><rect x="-4" y="4" width="4" height="16"/><rect x="16" y="4" width="4" height="16"/><rect x="0" y="18" width="16" height="4"/><rect x="16" y="22" width="4" height="16"/><rect x="0" y="36" width="16" height="4"/></g>'
        ));
    }
    
    function _uint2str(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
