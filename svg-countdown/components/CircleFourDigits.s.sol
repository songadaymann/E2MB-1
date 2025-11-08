// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Circle + Four Animated Digits
 * @notice Circle with 4 animated digits (ones, tens, hundreds, thousands) + ball
 */
contract CircleFourDigits is Script {
    
    function run() external {
        uint256 nowTs = block.timestamp;
        uint256 BASE = 12; // 12 seconds for real-time
        
        string memory svg = _generateSVG(nowTs, BASE);
        vm.writeFile("OUTPUTS/circle-four-digits.svg", svg);
        console.log("Generated: OUTPUTS/circle-four-digits.svg");
    }
    
    function _generateSVG(uint256 nowTs, uint256 BASE) private pure returns (string memory) {
        // Grid setup
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
        
        // Ball animation timing (uses BASE for cycle)
        uint256 secondsIntoBall = nowTs % BASE;
        uint256 ballTimeRemaining = BASE - secondsIntoBall;
        
        // Animation parameters
        uint256 digitSpacing = 80; // Match digit height (80px)
        
        // ONES PLACE (place=0, BASE per flip, BASE*10 full cycle)
        uint256 cycle1 = BASE * 10;
        uint256 secondsIntoCycle1 = nowTs % cycle1;
        uint256 onesDigit = 9 - (secondsIntoCycle1 / BASE);
        int256 onesBaseOffset = -int256(digitSpacing * (9 - onesDigit));
        int256 onesBeginPhase = -int256(secondsIntoCycle1 % BASE);
        uint256 onesX = startX + (3 * spacing) - 24; // Col 3
        uint256 onesY = startY + ((2 - 0) * 120) - 40; // Row 0
        
        // TENS PLACE (place=1, BASE*10 per flip, BASE*100 full cycle)
        uint256 cycle2 = BASE * 100;
        uint256 secondsIntoCycle2 = nowTs % cycle2;
        uint256 tensDigit = 9 - (secondsIntoCycle2 / (BASE * 10));
        int256 tensBaseOffset = -int256(digitSpacing * (9 - tensDigit));
        int256 tensBeginPhase = -int256(secondsIntoCycle2 % (BASE * 10));
        uint256 tensX = startX + (2 * spacing) - 24; // Col 2
        uint256 tensY = startY + ((2 - 0) * 120) - 40; // Row 0
        
        // HUNDREDS PLACE (place=2, BASE*100 per flip, BASE*1000 full cycle)
        uint256 cycle3 = BASE * 1000;
        uint256 secondsIntoCycle3 = nowTs % cycle3;
        uint256 hundredsDigit = 9 - (secondsIntoCycle3 / (BASE * 100));
        int256 hundredsBaseOffset = -int256(digitSpacing * (9 - hundredsDigit));
        int256 hundredsBeginPhase = -int256(secondsIntoCycle3 % (BASE * 100));
        uint256 hundredsX = startX + (1 * spacing) - 24; // Col 1
        uint256 hundredsY = startY + ((2 - 0) * 120) - 40; // Row 0
        
        // THOUSANDS PLACE (place=3, BASE*1000 per flip, BASE*10000 full cycle)
        uint256 cycle4 = BASE * 10000;
        uint256 secondsIntoCycle4 = nowTs % cycle4;
        uint256 thousandsDigit = 9 - (secondsIntoCycle4 / (BASE * 1000));
        int256 thousandsBaseOffset = -int256(digitSpacing * (9 - thousandsDigit));
        int256 thousandsBeginPhase = -int256(secondsIntoCycle4 % (BASE * 1000));
        uint256 thousandsX = startX + (0 * spacing) - 24; // Col 0
        uint256 thousandsY = startY + ((2 - 0) * 120) - 40; // Row 0
        
        string memory digits = "";
        
        // Generate all 12 digits (first 4 will be animated separately)
        for (uint256 place = 4; place < 12; place++) { // Start at 4, skip ones/tens/hundreds/thousands
            uint256 digit = 0; // All zeros for now
            
            // Calculate grid position (right-aligned, bottom-up)
            uint256 col = 3 - (place % 4);
            uint256 row = place / 4;
            
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
            // Clip paths for animated digits (at 0,0 since applied to transformed groups)
            '<clipPath id="onesClip"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="tensClip"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="hundredsClip"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            '<clipPath id="thousandsClip"><rect x="0" y="0" width="48" height="80"/></clipPath>',
            // Circle path for ball animation
            '<path id="circlePath" d="M 300,20 A 280,280 0 1,1 299.9,20" fill="none"/>',
            '</defs>',
            '<rect width="600" height="600" fill="#000"/>',
            
            // Circle
            '<circle cx="', _uint2str(circleCenterX), '" cy="', _uint2str(circleCenterY), '" r="', _uint2str(circleRadius), '" ',
            'fill="none" stroke="#fff" stroke-width="2"/>',
            
            // Static digits
            '<g fill="#fff">',
            digits,
            
            // Animated thousands place
            '<g clip-path="url(#thousandsClip)" transform="translate(', _uint2str(thousandsX), ',', _uint2str(thousandsY), ')">',
            '<g transform="translate(0,', _int2str(thousandsBaseOffset), ')">',
            '<use href="#d9" y="0"/>',
            '<use href="#d8" y="80"/>',
            '<use href="#d7" y="160"/>',
            '<use href="#d6" y="240"/>',
            '<use href="#d5" y="320"/>',
            '<use href="#d4" y="400"/>',
            '<use href="#d3" y="480"/>',
            '<use href="#d2" y="560"/>',
            '<use href="#d1" y="640"/>',
            '<use href="#d0" y="720"/>',
            '<use href="#d9" y="800"/>',
            '<animateTransform attributeName="transform" type="translate" ',
            'additive="sum" calcMode="discrete" ',
            'values="0,0;0,-80;0,-160;0,-240;0,-320;0,-400;0,-480;0,-560;0,-640;0,-720" ',
            'dur="', _uint2str(BASE * 10000), 's" ',
            'begin="', _int2str(thousandsBeginPhase), 's" ',
            'repeatCount="indefinite"/>',
            '</g></g>',
            
            // Animated hundreds place
            '<g clip-path="url(#hundredsClip)" transform="translate(', _uint2str(hundredsX), ',', _uint2str(hundredsY), ')">',
            '<g transform="translate(0,', _int2str(hundredsBaseOffset), ')">',
            '<use href="#d9" y="0"/>',
            '<use href="#d8" y="80"/>',
            '<use href="#d7" y="160"/>',
            '<use href="#d6" y="240"/>',
            '<use href="#d5" y="320"/>',
            '<use href="#d4" y="400"/>',
            '<use href="#d3" y="480"/>',
            '<use href="#d2" y="560"/>',
            '<use href="#d1" y="640"/>',
            '<use href="#d0" y="720"/>',
            '<use href="#d9" y="800"/>',
            '<animateTransform attributeName="transform" type="translate" ',
            'additive="sum" calcMode="discrete" ',
            'values="0,0;0,-80;0,-160;0,-240;0,-320;0,-400;0,-480;0,-560;0,-640;0,-720" ',
            'dur="', _uint2str(BASE * 1000), 's" ',
            'begin="', _int2str(hundredsBeginPhase), 's" ',
            'repeatCount="indefinite"/>',
            '</g></g>',
            
            // Animated tens place
            '<g clip-path="url(#tensClip)" transform="translate(', _uint2str(tensX), ',', _uint2str(tensY), ')">',
            '<g transform="translate(0,', _int2str(tensBaseOffset), ')">',
            '<use href="#d9" y="0"/>',
            '<use href="#d8" y="80"/>',
            '<use href="#d7" y="160"/>',
            '<use href="#d6" y="240"/>',
            '<use href="#d5" y="320"/>',
            '<use href="#d4" y="400"/>',
            '<use href="#d3" y="480"/>',
            '<use href="#d2" y="560"/>',
            '<use href="#d1" y="640"/>',
            '<use href="#d0" y="720"/>',
            '<use href="#d9" y="800"/>',
            '<animateTransform attributeName="transform" type="translate" ',
            'additive="sum" calcMode="discrete" ',
            'values="0,0;0,-80;0,-160;0,-240;0,-320;0,-400;0,-480;0,-560;0,-640;0,-720" ',
            'dur="', _uint2str(BASE * 100), 's" ',
            'begin="', _int2str(tensBeginPhase), 's" ',
            'repeatCount="indefinite"/>',
            '</g></g>',
            
            // Animated ones place
            '<g clip-path="url(#onesClip)" transform="translate(', _uint2str(onesX), ',', _uint2str(onesY), ')">',
            '<g transform="translate(0,', _int2str(onesBaseOffset), ')">',
            // Digit stack (9,8,7,6,5,4,3,2,1,0,9) - 80px spacing
            '<use href="#d9" y="0"/>',
            '<use href="#d8" y="80"/>',
            '<use href="#d7" y="160"/>',
            '<use href="#d6" y="240"/>',
            '<use href="#d5" y="320"/>',
            '<use href="#d4" y="400"/>',
            '<use href="#d3" y="480"/>',
            '<use href="#d2" y="560"/>',
            '<use href="#d1" y="640"/>',
            '<use href="#d0" y="720"/>',
            '<use href="#d9" y="800"/>',
            '<animateTransform attributeName="transform" type="translate" ',
            'additive="sum" calcMode="discrete" ',
            'values="0,0;0,-80;0,-160;0,-240;0,-320;0,-400;0,-480;0,-560;0,-640;0,-720" ',
            'dur="', _uint2str(BASE * 10), 's" ',
            'begin="', _int2str(onesBeginPhase), 's" ',
            'repeatCount="indefinite"/>',
            '</g></g>',
            
            '</g>',
            
            // Ball progress indicator
            '<circle r="', _uint2str(ballRadius), '" fill="#fff">',
            '<animateMotion dur="', _uint2str(ballTimeRemaining), 's" rotate="auto" fill="freeze">',
            '<mpath href="#circlePath"/>',
            '</animateMotion>',
            '<animateMotion dur="', _uint2str(BASE), 's" begin="', _uint2str(ballTimeRemaining), 's" rotate="auto" repeatCount="indefinite">',
            '<mpath href="#circlePath"/>',
            '</animateMotion>',
            '</circle>',
            
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
    
    function _int2str(int256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        bool negative = value < 0;
        uint256 abs = uint256(negative ? -value : value);
        string memory num = _uint2str(abs);
        return negative ? string(abi.encodePacked("-", num)) : num;
    }
}
