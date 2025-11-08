// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

/**
 * @title Circle Ball Animation
 * @notice A ball that travels around a circle once every 12 seconds
 */
contract CircleBall is Script {
    
    function run() external {
        uint256 nowTs = block.timestamp;
        
        // 12 second cycle
        uint256 BASE = 12;
        uint256 secondsIntoBase = nowTs % BASE;
        uint256 timeRemaining = BASE - secondsIntoBase;
        
        string memory svg = _generateSVG(nowTs, secondsIntoBase, timeRemaining);
        vm.writeFile("OUTPUTS/circle-ball.svg", svg);
        console.log("Generated: OUTPUTS/circle-ball.svg");
        console.log("Seconds into cycle:", secondsIntoBase);
    }
    
    function _generateSVG(uint256 nowTs, uint256 secondsInto, uint256 timeRemaining) private pure returns (string memory) {
        uint256 circleRadius = 280;
        uint256 circleCenterX = 300;
        uint256 circleCenterY = 300;
        
        // Ball size
        uint256 ballRadius = 12;
        
        // Calculate current angle (0° = top, clockwise)
        // Progress through cycle: secondsInto / 12
        // Angle in degrees: progress * 360
        // We want to start at top (270° in standard coords, or -90°)
        
        // For animateMotion, we use a path - a circle centered at (300,300) with radius 280
        // Path goes: start at top (300, 20), go clockwise
        
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">',
            '<rect width="600" height="600" fill="#000"/>',
            
            // Circle path
            '<circle cx="', _uint2str(circleCenterX), '" cy="', _uint2str(circleCenterY), '" r="', _uint2str(circleRadius), '" ',
            'fill="none" stroke="#fff" stroke-width="2"/>',
            
            // Ball that moves around the circle
            '<circle r="', _uint2str(ballRadius), '" fill="#fff">',
            // Start at current position based on time
            '<animateMotion ',
            'dur="', _uint2str(timeRemaining), 's" ',
            'rotate="auto" ',
            'fill="freeze">',
            '<mpath href="#circlePath"/>',
            '</animateMotion>',
            // Continue cycling
            '<animateMotion ',
            'dur="12s" ',
            'begin="', _uint2str(timeRemaining), 's" ',
            'rotate="auto" ',
            'repeatCount="indefinite">',
            '<mpath href="#circlePath"/>',
            '</animateMotion>',
            '</circle>',
            
            // Define the path for the ball to follow
            '<defs>',
            '<path id="circlePath" d="M 300,20 A 280,280 0 1,1 299.9,20" fill="none"/>',
            '</defs>',
            
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
}
