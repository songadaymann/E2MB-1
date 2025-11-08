// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Two Digits + Progress Bar
 * @notice Ones place flips every 12s, tens place flips every 120s
 */
contract TwoDigits is Script {
    
    function run() external {
        uint256 nowTs = block.timestamp;
        
        // BASE CYCLE - change this to speed up/slow down for testing!
        uint256 BASE = 1; // 1 second for fast testing, 12 seconds for real
        
        // Progress bar
        uint256 secondsIntoBase = nowTs % BASE;
        uint256 currentWidth = (secondsIntoBase * 260) / BASE;
        uint256 timeRemaining = BASE - secondsIntoBase;
        
        // Digit spacing (consistent across all calculations and animations)
        uint256 digitSpacing = 100;
        
        // ONES PLACE (BASE per flip, BASE*10 full cycle)
        uint256 cycle1 = BASE * 10;
        uint256 secondsIntoCycle1 = nowTs % cycle1;
        uint256 onesDigit = 9 - (secondsIntoCycle1 / BASE);
        int256 onesBaseOffset = -int256(digitSpacing * (9 - onesDigit));
        int256 onesBeginPhase = -int256(secondsIntoCycle1 % BASE);
        
        // TENS PLACE (BASE*10 per flip, BASE*100 full cycle)
        uint256 cycle2 = BASE * 100;
        uint256 secondsIntoCycle2 = nowTs % cycle2;
        uint256 tensDigit = 9 - (secondsIntoCycle2 / (BASE * 10));
        int256 tensBaseOffset = -int256(digitSpacing * (9 - tensDigit));
        int256 tensBeginPhase = -int256(secondsIntoCycle2 % (BASE * 10));
        
        // HUNDREDS PLACE (BASE*100 per flip, BASE*1000 full cycle)
        uint256 cycle3 = BASE * 1000;
        uint256 secondsIntoCycle3 = nowTs % cycle3;
        uint256 hundredsDigit = 9 - (secondsIntoCycle3 / (BASE * 100));
        int256 hundredsBaseOffset = -int256(digitSpacing * (9 - hundredsDigit));
        int256 hundredsBeginPhase = -int256(secondsIntoCycle3 % (BASE * 100));
        
        // THOUSANDS PLACE (BASE*1000 per flip, BASE*10000 full cycle)
        uint256 cycle4 = BASE * 10000;
        uint256 secondsIntoCycle4 = nowTs % cycle4;
        uint256 thousandsDigit = 9 - (secondsIntoCycle4 / (BASE * 1000));
        int256 thousandsBaseOffset = -int256(digitSpacing * (9 - thousandsDigit));
        int256 thousandsBeginPhase = -int256(secondsIntoCycle4 % (BASE * 1000));
        
        string memory svg = _generateSVG(
            currentWidth, 
            timeRemaining,
            onesBaseOffset,
            onesBeginPhase,
            tensBaseOffset,
            tensBeginPhase,
            hundredsBaseOffset,
            hundredsBeginPhase,
            thousandsBaseOffset,
            thousandsBeginPhase,
            BASE
        );
        
        vm.writeFile("OUTPUTS/four-digits.svg", svg);
        
        console.log("Generated four-digits.svg");
        console.log("Ones digit:", onesDigit);
        console.log("Tens digit:", tensDigit);
        console.log("Hundreds digit:", hundredsDigit);
        console.log("Thousands digit:", thousandsDigit);
    }
    
    function _generateSVG(
        uint256 startWidth, 
        uint256 duration,
        int256 onesBaseOffset,
        int256 onesBeginPhase,
        int256 tensBaseOffset,
        int256 tensBeginPhase,
        int256 hundredsBaseOffset,
        int256 hundredsBeginPhase,
        int256 thousandsBaseOffset,
        int256 thousandsBeginPhase,
        uint256 BASE
    ) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
            
            '<defs>',
            _digitGlyphs(),
            
            // Clip paths (centered, bigger digits with 100px spacing)
            '<clipPath id="thousandsClip"><rect x="120" y="200" width="60" height="100"/></clipPath>',
            '<clipPath id="hundredsClip"><rect x="220" y="200" width="60" height="100"/></clipPath>',
            '<clipPath id="tensClip"><rect x="320" y="200" width="60" height="100"/></clipPath>',
            '<clipPath id="onesClip"><rect x="420" y="200" width="60" height="100"/></clipPath>',
            
            '</defs>',
            
            '<rect width="600" height="600" fill="#000"/>',
            
            _renderDigit(120, thousandsBaseOffset, thousandsBeginPhase, _uint2str(BASE * 10000), "thousandsClip"),
            _renderDigit(220, hundredsBaseOffset, hundredsBeginPhase, _uint2str(BASE * 1000), "hundredsClip"),
            _renderDigit(320, tensBaseOffset, tensBeginPhase, _uint2str(BASE * 100), "tensClip"),
            _renderDigit(420, onesBaseOffset, onesBeginPhase, _uint2str(BASE * 10), "onesClip"),
            
            // Progress bar (blocky pixel style, centered below digits)
            '<rect x="120" y="380" width="360" height="16" fill="#222" stroke="#444" stroke-width="2"/>',
            '<rect x="122" y="382" width="356" height="12" fill="#fff">',
            '<animate attributeName="width" from="0" to="356" dur="', _uint2str(BASE), 's" begin="0s" repeatCount="indefinite"/>',
            '</rect>',
            
            '</svg>'
        ));
    }
    
    function _renderDigit(
        uint256 xPos,
        int256 baseOffset,
        int256 beginPhase,
        string memory duration,
        string memory clipId
    ) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<g clip-path="url(#', clipId, ')" fill="#fff">',
            '<g transform="translate(0,', _int2str(baseOffset), ') scale(2)">',
            
            // Stack of 7-segment digits (50px spacing, then scaled 2x = 100px final)
            '<use href="#d9" x="', _uint2str(xPos / 2), '" y="105"/>',
            '<use href="#d8" x="', _uint2str(xPos / 2), '" y="155"/>',
            '<use href="#d7" x="', _uint2str(xPos / 2), '" y="205"/>',
            '<use href="#d6" x="', _uint2str(xPos / 2), '" y="255"/>',
            '<use href="#d5" x="', _uint2str(xPos / 2), '" y="305"/>',
            '<use href="#d4" x="', _uint2str(xPos / 2), '" y="355"/>',
            '<use href="#d3" x="', _uint2str(xPos / 2), '" y="405"/>',
            '<use href="#d2" x="', _uint2str(xPos / 2), '" y="455"/>',
            '<use href="#d1" x="', _uint2str(xPos / 2), '" y="505"/>',
            '<use href="#d0" x="', _uint2str(xPos / 2), '" y="555"/>',
            '<use href="#d9" x="', _uint2str(xPos / 2), '" y="605"/>',
            
            '<animateTransform attributeName="transform" type="translate" additive="sum" calcMode="discrete" ',
            'dur="', duration, 's" begin="', _int2str(beginPhase), 's" repeatCount="indefinite" ',
            'values="0,0;0,-50;0,-100;0,-150;0,-200;0,-250;0,-300;0,-350;0,-400;0,-450"/>',
            
            '</g>',
            '</g>'
        ));
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
    
    function _int2str(int256 value) private pure returns (string memory) {
        if (value >= 0) {
            return _uint2str(uint256(value));
        } else {
            return string(abi.encodePacked('-', _uint2str(uint256(-value))));
        }
    }
}
