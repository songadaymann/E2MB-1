// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Circle + Static Numbers
 * @notice Just the circle with static 12-digit grid, no animations
 */
contract CircleStatic is Script {
    
    function run() external {
        uint256 blockCount = 1234567890;
        string memory svg = _generateSVG(blockCount);
        vm.writeFile("OUTPUTS/circle-static.svg", svg);
        console.log("Generated: OUTPUTS/circle-static.svg");
    }
    
    function _generateSVG(uint256 blockCount) private pure returns (string memory) {
        // Grid setup (from FixedGrid)
        uint256 spacing = 100;
        uint256 gridWidth = 3 * spacing;
        uint256 gridHeight = 2 * 120;
        uint256 startX = 300 - (gridWidth / 2);
        uint256 startY = 300 - (gridHeight / 2);
        
        // Circle setup
        uint256 circleRadius = 280;
        uint256 circleCenterX = 300;
        uint256 circleCenterY = 300;
        
        string memory digits = "";
        
        // Generate all 12 static digits
        for (uint256 place = 0; place < 12; place++) {
            uint256 digit = (blockCount / (10 ** place)) % 10;
            
            // Calculate grid position (right-aligned, bottom-up)
            uint256 col = 3 - (place % 4); // 3,2,1,0
            uint256 row = place / 4; // 0,1,2
            
            // Offset by half digit width (24px) to center on grid point
            uint256 x = startX + (col * spacing) - 24;
            uint256 y = startY + ((2 - row) * 120) - 40;
            
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
            
            // Circle
            '<circle cx="', _uint2str(circleCenterX), '" cy="', _uint2str(circleCenterY), '" r="', _uint2str(circleRadius), '" ',
            'fill="none" stroke="#fff" stroke-width="2"/>',
            
            // Static digits
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
