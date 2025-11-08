// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Single Digit + Progress Bar
 * @notice One digit that flips 9→8→7...→0 every 12 seconds, synced with progress bar
 */
contract SingleDigit is Script {
    
    function run() external {
        uint256 nowTs = block.timestamp;
        uint256 secondsInto12 = nowTs % 12;
        
        // For progress bar
        uint256 currentWidth = (secondsInto12 * 260) / 12;
        uint256 timeRemaining = 12 - secondsInto12;
        
        // For digit: which digit are we currently showing?
        // secondsInto12 = 0 → show 9
        // secondsInto12 = 1 → show 9 (still)
        // ... after 12 seconds wraps to show 8, etc.
        // Actually we want to count DOWN so:
        // We're in a 120-second cycle for full 9→0 countdown
        uint256 secondsInto120 = nowTs % 120;
        uint256 currentDigit = 9 - (secondsInto120 / 12); // 0-11 secs = 9, 12-23 = 8, etc.
        
        // Base offset to show current digit
        int256 baseOffset = -int256(50 * (9 - currentDigit)); // 50px spacing
        
        // Phase for animation timing (when does next flip happen?)
        int256 beginPhase = -int256(secondsInto120 % 12);
        
        string memory svg = _generateSVG(currentWidth, timeRemaining, baseOffset, beginPhase);
        
        vm.writeFile("OUTPUTS/single-digit.svg", svg);
        
        console.log("Generated single-digit.svg");
        console.log("Seconds into 120s cycle:", secondsInto120);
        console.log("Current digit showing:", currentDigit);
        console.log("Base offset:", baseOffset);
        console.log("Next flip in:", 12 - (secondsInto120 % 12), "seconds");
    }
    
    function _generateSVG(
        uint256 startWidth, 
        uint256 duration,
        int256 baseOffset,
        int256 beginPhase
    ) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="360" height="200" viewBox="0 0 360 200">',
            
            '<defs>',
            '<style>',
            '.bg { fill: #0a0a0f; }',
            '.digit-box { fill: #171723; stroke: #2a2a3b; stroke-width: 2; }',
            '.digit { fill: #e9eef7; font-family: monospace; font-weight: 700; font-size: 48px; text-anchor: middle; }',
            '</style>',
            '</defs>',
            
            '<rect class="bg" width="360" height="200"/>',
            
            // Digit box
            '<rect class="digit-box" x="155" y="40" width="50" height="60" rx="8"/>',
            
            // Clip window
            '<clipPath id="digitClip">',
            '<rect x="155" y="40" width="50" height="60" rx="8"/>',
            '</clipPath>',
            
            // Digit stack with animation
            '<g clip-path="url(#digitClip)">',
            '<g transform="translate(0,', _int2str(baseOffset), ')">',
            
            // Stack of digits (50px spacing)
            '<text class="digit" x="180" y="85">9</text>',
            '<text class="digit" x="180" y="135">8</text>',
            '<text class="digit" x="180" y="185">7</text>',
            '<text class="digit" x="180" y="235">6</text>',
            '<text class="digit" x="180" y="285">5</text>',
            '<text class="digit" x="180" y="335">4</text>',
            '<text class="digit" x="180" y="385">3</text>',
            '<text class="digit" x="180" y="435">2</text>',
            '<text class="digit" x="180" y="485">1</text>',
            '<text class="digit" x="180" y="535">0</text>',
            
            // Discrete animation - flips every 12 seconds (10 values × 12s = 120s)
            '<animateTransform attributeName="transform" type="translate" additive="sum" calcMode="discrete" ',
            'dur="120s" begin="', _int2str(beginPhase), 's" repeatCount="indefinite" ',
            'values="0,0;0,-50;0,-100;0,-150;0,-200;0,-250;0,-300;0,-350;0,-400;0,-450"/>',
            
            '</g>',
            '</g>',
            
            // Progress bar (same as before)
            '<rect x="50" y="140" width="260" height="20" rx="10" fill="#232336"/>',
            '<rect x="50" y="140" width="260" height="20" rx="10" fill="#4c9cff">',
            '<animate attributeName="width" from="', _uint2str(startWidth), '" to="260" dur="', _uint2str(duration), 's" begin="0s" fill="freeze"/>',
            '<animate attributeName="width" from="0" to="260" dur="12s" begin="', _uint2str(duration), 's" repeatCount="indefinite"/>',
            '</rect>',
            
            '<text x="180" y="180" fill="#9aa6be" font-family="monospace" font-size="11" text-anchor="middle">',
            'digit flips when bar fills',
            '</text>',
            
            '</svg>'
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
