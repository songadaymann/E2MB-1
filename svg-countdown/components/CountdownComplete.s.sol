// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Complete Countdown
 * @notice Combines: 12 animated digits + circle + ball progress indicator
 */
contract CountdownComplete is Script {
    
    function run() external {
        uint256 nowTs = block.timestamp;
        
        // BASE CYCLE - change this to speed up/slow down for testing!
        uint256 BASE = 1; // 1 second for fast testing, 12 seconds for real
        
        string memory svg = _generateSVG(nowTs, BASE);
        vm.writeFile("OUTPUTS/countdown-complete.svg", svg);
        console.log("Generated: OUTPUTS/countdown-complete.svg");
    }
    
    function _generateSVG(uint256 nowTs, uint256 BASE) private pure returns (string memory) {
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
        uint256 ballRadius = 12;
        
        // Ball animation timing (12 second cycle regardless of BASE)
        uint256 ballCycle = 12;
        uint256 secondsIntoBall = nowTs % ballCycle;
        uint256 ballTimeRemaining = ballCycle - secondsIntoBall;
        
        // Digit spacing for animations (from TwoDigits)
        uint256 digitSpacing = 100;
        
        string memory digits = "";
        string memory clipPaths = "";
        
        // Generate all 12 digit places with animations
        for (uint256 place = 0; place < 12; place++) {
            // Calculate grid position (right-aligned, bottom-up)
            uint256 col = 3 - (place % 4); // 3,2,1,0
            uint256 row = place / 4; // 0,1,2
            
            // Offset by half digit width (24px) to center on grid point
            uint256 x = startX + (col * spacing) - 24;
            uint256 y = startY + ((2 - row) * 120) - 40;
            
            // Calculate animation parameters for this place
            uint256 stepSec = BASE * (10 ** place);      // Time per digit flip
            uint256 cycleSec = stepSec * 10;             // Full 9→0 cycle
            uint256 secondsIntoCycle = nowTs % cycleSec;
            uint256 currentDigit = 9 - (secondsIntoCycle / stepSec);
            int256 baseOffsetY = -int256(digitSpacing * (9 - currentDigit));
            int256 beginPhase = -int256(secondsIntoCycle % stepSec);
            
            // Create clip path for this digit (48px wide × 80px tall window)
            clipPaths = string(abi.encodePacked(
                clipPaths,
                '<clipPath id="clip', _uint2str(place), '"><rect x="', _uint2str(x), '" y="', _uint2str(y), '" width="48" height="80"/></clipPath>'
            ));
            
            digits = string(abi.encodePacked(
                digits,
                _digitColumn(x, y, baseOffsetY, beginPhase, stepSec, place)
            ));
        }
        
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
            '<defs>',
            _digitGlyphs(),
            clipPaths,
            '<path id="circlePath" d="M 300,20 A 280,280 0 1,1 299.9,20" fill="none"/>',
            '</defs>',
            '<rect width="600" height="600" fill="#000"/>',
            
            // Circle
            '<circle cx="', _uint2str(circleCenterX), '" cy="', _uint2str(circleCenterY), '" r="', _uint2str(circleRadius), '" ',
            'fill="none" stroke="#fff" stroke-width="2"/>',
            
            // Digits
            '<g fill="#fff">',
            digits,
            '</g>',
            
            // Ball progress indicator
            '<circle r="', _uint2str(ballRadius), '" fill="#fff">',
            '<animateMotion dur="', _uint2str(ballTimeRemaining), 's" rotate="auto" fill="freeze">',
            '<mpath href="#circlePath"/>',
            '</animateMotion>',
            '<animateMotion dur="12s" begin="', _uint2str(ballTimeRemaining), 's" rotate="auto" repeatCount="indefinite">',
            '<mpath href="#circlePath"/>',
            '</animateMotion>',
            '</circle>',
            
            '</svg>'
        ));
    }
    
    function _digitColumn(
        uint256 x,
        uint256 y,
        int256 baseOffsetY,
        int256 beginPhase,
        uint256 stepSec,
        uint256 clipId
    ) private pure returns (string memory) {
        uint256 digitSpacing = 100;
        
        // Build the digit stack (9,8,7,6,5,4,3,2,1,0,9)
        string memory stack = string(abi.encodePacked(
            '<use href="#d9" y="0"/>',
            '<use href="#d8" y="', _uint2str(digitSpacing), '"/>',
            '<use href="#d7" y="', _uint2str(digitSpacing * 2), '"/>',
            '<use href="#d6" y="', _uint2str(digitSpacing * 3), '"/>',
            '<use href="#d5" y="', _uint2str(digitSpacing * 4), '"/>',
            '<use href="#d4" y="', _uint2str(digitSpacing * 5), '"/>',
            '<use href="#d3" y="', _uint2str(digitSpacing * 6), '"/>',
            '<use href="#d2" y="', _uint2str(digitSpacing * 7), '"/>',
            '<use href="#d1" y="', _uint2str(digitSpacing * 8), '"/>',
            '<use href="#d0" y="', _uint2str(digitSpacing * 9), '"/>',
            '<use href="#d9" y="', _uint2str(digitSpacing * 10), '"/>'
        ));
        
        // Discrete animation values (10 steps through the stack)
        string memory values = string(abi.encodePacked(
            '0;',
            _uint2str(digitSpacing), ';',
            _uint2str(digitSpacing * 2), ';',
            _uint2str(digitSpacing * 3), ';',
            _uint2str(digitSpacing * 4), ';',
            _uint2str(digitSpacing * 5), ';',
            _uint2str(digitSpacing * 6), ';',
            _uint2str(digitSpacing * 7), ';',
            _uint2str(digitSpacing * 8), ';',
            _uint2str(digitSpacing * 9)
        ));
        
        return string(abi.encodePacked(
            '<g clip-path="url(#clip', _uint2str(clipId), ')" transform="translate(', _uint2str(x), ',', _uint2str(y), ')">',
            '<g transform="translate(0,', _int2str(baseOffsetY), ')">',
            stack,
            '<animateTransform attributeName="transform" type="translate" ',
            'additive="sum" calcMode="discrete" ',
            'values="', values, '" ',
            'dur="', _uint2str(stepSec * 10), 's" ',
            'begin="', _int2str(beginPhase), 's" ',
            'repeatCount="indefinite"/>',
            '</g></g>'
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
    
    function _int2str(int256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        bool negative = value < 0;
        uint256 abs = uint256(negative ? -value : value);
        string memory num = _uint2str(abs);
        return negative ? string(abi.encodePacked("-", num)) : num;
    }
}
