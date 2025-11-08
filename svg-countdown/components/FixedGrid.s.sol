// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Fixed Grid Layout
 * @notice Always shows 12 digits (3 rows × 4 columns) with leading zeros
 * @dev Much simpler - no dynamic centering needed!
 */
contract FixedGrid is Script {
    
    function run() external {
        _testLayout(694054, "694054");
        _testLayout(49583402840, "49583402840");
        _testLayout(123, "123");
        _testLayout(1234567890, "1234567890");
    }
    
    function _testLayout(uint256 blockCount, string memory label) private {
        string memory svg = _generateSVG(blockCount, label);
        string memory filename = string(abi.encodePacked("OUTPUTS/grid-", label, ".svg"));
        vm.writeFile(filename, svg);
        console.log("Generated:", filename);
    }
    
    function _generateSVG(uint256 blockCount, string memory label) private pure returns (string memory) {
        // Always 3 rows × 4 columns = 12 digits (2× glyphs, NO SCALING)
        uint256 spacing = 100; // Space between digit centers
        
        // Grid dimensions: 3 gaps × 100px spacing = 300px wide, 2 gaps × 120px = 240px tall
        uint256 gridWidth = 3 * spacing;  // Width between first and last column centers
        uint256 gridHeight = 2 * 120;      // Height between first and last row centers
        
        // Center the grid around circle center (300, 300)
        uint256 startX = 300 - (gridWidth / 2);  // Left-most column center
        uint256 startY = 300 - (gridHeight / 2); // Top-most row center
        
        // Circle around the numbers
        uint256 circleRadius = 280;
        uint256 circleCenterX = 300;
        uint256 circleCenterY = 300;
        
        string memory digits = "";
        
        // Generate all 12 digits (places 11 down to 0)
        for (uint256 place = 0; place < 12; place++) {
            uint256 digit = (blockCount / (10 ** place)) % 10;
            
            // Calculate grid position (right-aligned, bottom-up)
            uint256 col = 3 - (place % 4); // 3,2,1,0
            uint256 row = place / 4; // 0,1,2
            
            // Offset by half digit width (24px) to center on grid point
            uint256 x = startX + (col * spacing) - 24;
            uint256 y = startY + ((2 - row) * 120) - 40; // Also center vertically (half of 80px height)
            
            digits = string(abi.encodePacked(
                digits,
                '<use href="#d', _uint2str(digit), '" transform="translate(', _uint2str(x), ',', _uint2str(y), ')"/>'
            ));
        }
        
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
            '<defs>',
            _digitGlyphs(),
            '</defs>',
            '<rect width="600" height="600" fill="#000"/>',
            '<circle cx="', _uint2str(circleCenterX), '" cy="', _uint2str(circleCenterY), '" r="', _uint2str(circleRadius), '" ',
            'fill="none" stroke="#fff" stroke-width="2"/>',
            '<text x="300" y="60" fill="#666" font-family="monospace" font-size="14" text-anchor="middle">',
            label, ' blocks',
            '</text>',
            '<g fill="#fff">',
            digits,
            '</g>',
            '</svg>'
        ));
    }
    
    function _digitGlyphs() private pure returns (string memory) {
        // 2× larger glyphs (48px wide × 80px tall)
        return string(abi.encodePacked(
            '<g id="d0" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d1" transform="translate(8,0)"><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>',
            '<g id="d2" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d3" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d4" transform="translate(8,0)"><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>',
            '<g id="d5" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d6" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d7" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="32" y="8" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/></g>',
            '<g id="d8" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="-8" y="44" width="8" height="32"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>',
            '<g id="d9" transform="translate(8,0)"><rect x="0" y="0" width="32" height="8"/><rect x="-8" y="8" width="8" height="32"/><rect x="32" y="8" width="8" height="32"/><rect x="0" y="36" width="32" height="8"/><rect x="32" y="44" width="8" height="32"/><rect x="0" y="72" width="32" height="8"/></g>'
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
