// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Progress Bar Test
 * @notice Just a simple progress bar that fills over 12 seconds
 */
contract ProgressBar is Script {
    
    function run() external {
        // Get current timestamp modulo 12 to know where we are in the cycle
        uint256 nowTs = block.timestamp;
        uint256 secondsInto12 = nowTs % 12;
        
        // Calculate how much we've filled (0-260px)
        uint256 currentWidth = (secondsInto12 * 260) / 12;
        
        // Calculate time remaining in this 12s cycle
        uint256 timeRemaining = 12 - secondsInto12;
        
        string memory svg = _generateProgressBar(currentWidth, timeRemaining);
        
        vm.writeFile("OUTPUTS/progress-bar.svg", svg);
        
        console.log("Generated progress-bar.svg");
        console.log("Current position in 12s cycle:", secondsInto12, "seconds");
        console.log("Starting at width:", currentWidth, "px");
        console.log("Will animate to 260px over", timeRemaining, "seconds");
        console.log("Then loop back every 12 seconds");
    }
    
    function _generateProgressBar(uint256 startWidth, uint256 duration) private pure returns (string memory) {
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="360" height="100" viewBox="0 0 360 100">',
            '<rect x="0" y="0" width="360" height="100" fill="#0a0a0f"/>',
            
            // Track (background)
            '<rect x="50" y="40" width="260" height="20" rx="10" fill="#232336"/>',
            
            // Fill bar (animated)
            '<rect x="50" y="40" width="260" height="20" rx="10" fill="#4c9cff">',
            
            // First animation: from current position to end of cycle
            '<animate attributeName="width" ',
            'from="', _uint2str(startWidth), '" ',
            'to="260" ',
            'dur="', _uint2str(duration), 's" ',
            'begin="0s" ',
            'fill="freeze"/>',
            
            // Second animation: repeat full cycle after first completes
            '<animate attributeName="width" ',
            'from="0" ',
            'to="260" ',
            'dur="12s" ',
            'begin="', _uint2str(duration), 's" ',
            'repeatCount="indefinite"/>',
            
            '</rect>',
            
            // Label
            '<text x="180" y="75" fill="#9aa6be" font-family="monospace" font-size="12" text-anchor="middle">',
            '12 second progress bar',
            '</text>',
            
            '</svg>'
        ));
    }
    
    function _uint2str(uint256 value) private pure returns (string memory) {
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
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
