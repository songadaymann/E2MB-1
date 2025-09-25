// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

contract CountdownNFT is ERC721, Ownable {
    using Strings for uint256;
    
    uint256 private _tokenIdCounter;
    
    // Points system for dynamic ranking
    mapping(uint256 => uint256) public points;
    mapping(uint256 => uint256) public basePermutation; // VRF-style tiebreaker (simplified)
    
    event PointsEarned(uint256 indexed tokenId, uint256 points, uint256 newTotal);
    
    constructor() ERC721("Countdown NFT", "COUNTDOWN") Ownable(msg.sender) {}
    
    function mint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter++;
        
        // Initialize base permutation (simplified VRF - just use tokenId for testing)
        basePermutation[tokenId] = tokenId;
        
        _mint(to, tokenId);
    }
    
    // Simulate earning points from burning assets
    function earnPoints(uint256 tokenId, uint256 amount) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        
        points[tokenId] += amount;
        emit PointsEarned(tokenId, amount, points[tokenId]);
    }
    
    // Get current rank of a token in the reveal queue
    function getCurrentRank(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return _getCurrentRank(tokenId);
    }
    
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        string memory svg = generateCountdownSVG(tokenId);
        string memory json = string(abi.encodePacked(
            '{"name": "Countdown #', tokenId.toString(),
            '", "description": "An animated countdown odometer", ',
            '"image": "data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));
        
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }
    
    function generateCountdownSVG(uint256 tokenId) internal view returns (string memory) {
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 360 420" width="360" height="420">',
            '<defs>',
            _generateDigitDefs(),
            _generateClipPath(),
            '</defs>',
            '<rect width="100%" height="100%" fill="#000"/>',
            _generateOdometerDigits(tokenId),
            '</svg>'
        ));
    }
    
    function _generateDigitDefs() internal pure returns (string memory) {
        return string(abi.encodePacked(
            // Digit 0
            '<g id="d0" transform="translate(4,0)">',
            '<rect x="0" y="0" width="16" height="4"/>',
            '<rect x="-4" y="4" width="4" height="16"/>',
            '<rect x="16" y="4" width="4" height="16"/>',
            '<rect x="-4" y="22" width="4" height="16"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '<rect x="0" y="36" width="16" height="4"/>',
            '</g>',
            // Digit 1
            '<g id="d1" transform="translate(4,0)">',
            '<rect x="16" y="4" width="4" height="16"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '</g>',
            // Digit 2
            '<g id="d2" transform="translate(4,0)">',
            '<rect x="0" y="0" width="16" height="4"/>',
            '<rect x="16" y="4" width="4" height="16"/>',
            '<rect x="0" y="18" width="16" height="4"/>',
            '<rect x="-4" y="22" width="4" height="16"/>',
            '<rect x="0" y="36" width="16" height="4"/>',
            '</g>',
            // Add more digits...
            _generateMoreDigits()
        ));
    }
    
    function _generateMoreDigits() internal pure returns (string memory) {
        return string(abi.encodePacked(
            // Digit 3
            '<g id="d3" transform="translate(4,0)">',
            '<rect x="0" y="0" width="16" height="4"/>',
            '<rect x="16" y="4" width="4" height="16"/>',
            '<rect x="0" y="18" width="16" height="4"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '<rect x="0" y="36" width="16" height="4"/>',
            '</g>',
            // Digit 4
            '<g id="d4" transform="translate(4,0)">',
            '<rect x="-4" y="4" width="4" height="16"/>',
            '<rect x="0" y="18" width="16" height="4"/>',
            '<rect x="16" y="4" width="4" height="16"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '</g>',
            // Digit 5
            '<g id="d5" transform="translate(4,0)">',
            '<rect x="0" y="0" width="16" height="4"/>',
            '<rect x="-4" y="4" width="4" height="16"/>',
            '<rect x="0" y="18" width="16" height="4"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '<rect x="0" y="36" width="16" height="4"/>',
            '</g>',
            _generateDigits6to9()
        ));
    }
    
    function _generateDigits6to9() internal pure returns (string memory) {
        return string(abi.encodePacked(
            // Digit 6
            '<g id="d6" transform="translate(4,0)">',
            '<rect x="0" y="0" width="16" height="4"/>',
            '<rect x="-4" y="4" width="4" height="16"/>',
            '<rect x="0" y="18" width="16" height="4"/>',
            '<rect x="-4" y="22" width="4" height="16"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '<rect x="0" y="36" width="16" height="4"/>',
            '</g>',
            // Digit 7
            '<g id="d7" transform="translate(4,0)">',
            '<rect x="0" y="0" width="16" height="4"/>',
            '<rect x="16" y="4" width="4" height="16"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '</g>',
            // Digit 8
            '<g id="d8" transform="translate(4,0)">',
            '<rect x="0" y="0" width="16" height="4"/>',
            '<rect x="-4" y="4" width="4" height="16"/>',
            '<rect x="16" y="4" width="4" height="16"/>',
            '<rect x="0" y="18" width="16" height="4"/>',
            '<rect x="-4" y="22" width="4" height="16"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '<rect x="0" y="36" width="16" height="4"/>',
            '</g>',
            // Digit 9
            '<g id="d9" transform="translate(4,0)">',
            '<rect x="0" y="0" width="16" height="4"/>',
            '<rect x="-4" y="4" width="4" height="16"/>',
            '<rect x="16" y="4" width="4" height="16"/>',
            '<rect x="0" y="18" width="16" height="4"/>',
            '<rect x="16" y="22" width="4" height="16"/>',
            '<rect x="0" y="36" width="16" height="4"/>',
            '</g>'
        ));
    }
    
    function _generateClipPath() internal pure returns (string memory) {
        // Tight window equal to the per-digit vertical step (50px) to prevent neighbor bleed
        return '<clipPath id="digitWindow" clipPathUnits="userSpaceOnUse"><rect x="0" y="0" width="50" height="50"/></clipPath>';
    }
    
    function _generateOdometerDigits(uint256 tokenId) internal view returns (string memory) {
        uint256 displayNumber = _calculateCountdownBlocks(tokenId);
        uint256 currentRank = _getCurrentRank(tokenId);
        uint256 revealYear = 2026 + currentRank;
        
        return string(abi.encodePacked(
            _generateTopRow(displayNumber),
            _generateMiddleRow(displayNumber),
            _generateBottomRow(displayNumber),
            _generateRevealYear(revealYear)
        ));
    }
    
    function _generateTopRow(uint256 displayNumber) internal view returns (string memory) {
        return string(abi.encodePacked(
            '<g transform="translate(65, 80)">',
            _generateAnimatedDigitColumn(0,   (displayNumber / 100000000000) % 10, "#0f0", "1200000000000s", 1200000000000, true),
            _generateAnimatedDigitColumn(60,  (displayNumber / 10000000000) % 10,  "#0f0", "120000000000s", 120000000000, true),
            _generateAnimatedDigitColumn(120, (displayNumber / 1000000000) % 10,   "#0f0", "12000000000s", 12000000000, true),
            _generateAnimatedDigitColumn(180, (displayNumber / 100000000) % 10,    "#0f0", "1200000000s", 1200000000, true),
            '</g>'
        ));
    }
    
    function _generateMiddleRow(uint256 displayNumber) internal view returns (string memory) {
        return string(abi.encodePacked(
            '<g transform="translate(65, 140)">',
            _generateAnimatedDigitColumn(0,   (displayNumber / 10000000) % 10, "#0f0", "120000000s", 120000000, true),
            _generateAnimatedDigitColumn(60,  (displayNumber / 1000000) % 10, "#0f0", "12000000s", 12000000, true),
            _generateAnimatedDigitColumn(120, (displayNumber / 100000) % 10, "#0f0", "1200000s", 1200000, true),
            _generateAnimatedDigitColumn(180, (displayNumber / 10000) % 10, "#0f0", "120000s", 120000, true),
            '</g>'
        ));
    }
    
    function _generateBottomRow(uint256 displayNumber) internal view returns (string memory) {
        return string(abi.encodePacked(
            '<g transform="translate(65, 200)">',
            _generateAnimatedDigitColumn(0,   (displayNumber / 1000) % 10, "#ff0", "120000s", 120000, true),
            _generateAnimatedDigitColumn(60,  (displayNumber / 100) % 10, "#ff0", "12000s", 12000, true),
            _generateAnimatedDigitColumn(120, (displayNumber / 10) % 10, "#ff0", "1200s", 1200, true),
            _generateAnimatedDigitColumn(180, displayNumber % 10, "#ff0", "120s", 120, false),
            '</g>'
        ));
    }
    
    function _calculateCountdownBlocks(uint256 tokenId) internal view returns (uint256) {
        // Get current rank instead of using tokenId
        uint256 currentRank = _getCurrentRank(tokenId);
        
        // Each token reveals on Jan 1 of (2026 + rank) at 00:00:00 UTC
        uint256 revealYear = 2026 + currentRank;
        uint256 revealTimestamp = _getJan1Timestamp(revealYear);
        
        // If already past reveal time, show 0
        if (block.timestamp >= revealTimestamp) {
            return 0;
        }
        
        // Calculate seconds remaining and convert to "blocks" (assume ~12 seconds per block)
        uint256 secondsRemaining = revealTimestamp - block.timestamp;
        uint256 blocksRemaining = secondsRemaining / 12;
        
        // Cap at 999,999,999,999 for 12-digit display
        if (blocksRemaining > 999999999999) {
            return 999999999999;
        }
        
        return blocksRemaining;
    }
    
    function _getCurrentRank(uint256 tokenId) internal view returns (uint256) {
        uint256 myPoints = points[tokenId];
        uint256 myBasePermutation = basePermutation[tokenId];
        uint256 rank = 0;
        
        // Count how many tokens have higher priority
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (i == tokenId) continue;
            
            uint256 otherPoints = points[i];
            uint256 otherBasePermutation = basePermutation[i];
            
            // Higher points = better rank
            if (otherPoints > myPoints) {
                rank++;
            }
            // Equal points -> use base permutation as tiebreaker (lower = better)
            else if (otherPoints == myPoints && otherBasePermutation < myBasePermutation) {
                rank++;
            }
        }
        
        return rank;
    }
    
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId < _tokenIdCounter;
    }
    
    function _getJan1Timestamp(uint256 year) internal pure returns (uint256) {
        // Calculate Unix timestamp for Jan 1, 00:00:00 UTC of given year
        // This is a simplified calculation - in production you'd want more precise leap year handling
        
        // Years since 1970
        uint256 yearsSince1970 = year - 1970;
        
        // Approximate leap years (every 4 years, with some exceptions we'll ignore for simplicity)
        uint256 leapDays = yearsSince1970 / 4;
        
        // Total days = regular years * 365 + leap days
        uint256 totalDays = yearsSince1970 * 365 + leapDays;
        
        // Convert to seconds (86400 seconds per day)
        return totalDays * 86400;
    }
    
    function _generateAnimatedDigitColumn(uint256 xPos, uint256 startDigit, string memory color, string memory duration, uint256 cycleSeconds, bool discrete) internal view returns (string memory) {
        // Ensure startDigit is single digit
        startDigit = startDigit % 10;
        // Time-synced begin offset so refreshes resume at correct position
        uint256 elapsed = block.timestamp % cycleSeconds;
        string memory beginAttr = string(abi.encodePacked("-", elapsed.toString(), "s"));
        
        return string(abi.encodePacked(
            '<g transform="translate(', xPos.toString(), ', 0)" clip-path="url(#digitWindow)">',
            '<g fill="', color, '" shape-rendering="crispEdges">',
            '<g transform="translate(13, 0)">',
            _generateDigitSequence(startDigit),
            (discrete
                ? string(
                    abi.encodePacked(
                        '<animateTransform attributeName="transform" type="translate" calcMode="discrete" ',
                        'values="13 0;13 -50;13 -100;13 -150;13 -200;13 -250;13 -300;13 -350;13 -400;13 -450;13 -500" ',
                        'keyTimes="0;0.1;0.2;0.3;0.4;0.5;0.6;0.7;0.8;0.9;1" dur="', duration, '" begin="', beginAttr, '" repeatCount="indefinite"/>'
                    )
                )
                : string(
                    abi.encodePacked(
                        '<animateTransform attributeName="transform" type="translate" from="13 0" to="13 -500" dur="', duration, '" begin="', beginAttr, '" repeatCount="indefinite"/>'
                    )
                )
            ),
            '</g>',
            '</g>',
            '</g>'
        ));
    }
    
    function _generateRevealYear(uint256 year) internal pure returns (string memory) {
        string memory d1 = ((year / 1000) % 10).toString();
        string memory d2 = ((year / 100) % 10).toString();
        string memory d3 = ((year / 10) % 10).toString();
        string memory d4 = (year % 10).toString();
        return string(abi.encodePacked(
            '<g transform="translate(38, 310)" fill="#fff">',
            '<g transform="scale(1.5)">',
            '<use href="#d', d1, '" x="0" y="0"/>',
            '<use href="#d', d2, '" x="55" y="0"/>',
            '<use href="#d', d3, '" x="110" y="0"/>',
            '<use href="#d', d4, '" x="165" y="0"/>',
            '</g>',
            '</g>'
        ));
    }
    
    function _generateDigitSequence(uint256 startDigit) internal pure returns (string memory) {
        // Generate a sequence of digits starting from startDigit, going backwards
        string memory sequence = string(abi.encodePacked(
            '<use href="#d', startDigit.toString(), '" y="0"/>',
            '<use href="#d', ((startDigit + 9) % 10).toString(), '" y="50"/>',
            '<use href="#d', ((startDigit + 8) % 10).toString(), '" y="100"/>',
            '<use href="#d', ((startDigit + 7) % 10).toString(), '" y="150"/>',
            '<use href="#d', ((startDigit + 6) % 10).toString(), '" y="200"/>'
        ));
        
        return string(abi.encodePacked(
            sequence,
            '<use href="#d', ((startDigit + 5) % 10).toString(), '" y="250"/>',
            '<use href="#d', ((startDigit + 4) % 10).toString(), '" y="300"/>',
            '<use href="#d', ((startDigit + 3) % 10).toString(), '" y="350"/>',
            '<use href="#d', ((startDigit + 2) % 10).toString(), '" y="400"/>',
            '<use href="#d', ((startDigit + 1) % 10).toString(), '" y="450"/>',
            '<use href="#d', startDigit.toString(), '" y="500"/>'
        ));
    }
}
