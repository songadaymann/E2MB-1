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
        // Compute rank closeness in basis points (0..10000)
        uint256 cBps = (_tokenIdCounter > 1)
            ? (10000 - (_getCurrentRank(tokenId) * 10000) / (_tokenIdCounter - 1))
            : 0;
        
        // Background and year grayscale based on closeness
        string memory bgColor = _grayCss(uint16(10000 - cBps)); // white->black
        string memory yearColor = _grayCss(uint16(cBps));       // black->white
        
        string memory head = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 360 420" width="360" height="420">',
            '<defs>', _generateDigitDefs(), _generateClipPath(), '</defs>',
            '<rect width="100%" height="100%" fill="', bgColor, '"/>'
        ));
        string memory body = _generateOdometerDigits(tokenId, cBps, yearColor);
        return string(abi.encodePacked(head, body, '</svg>'));
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
    
    function _generateOdometerDigits(uint256 tokenId, uint256 cBps, string memory yearColor) internal view returns (string memory) {
        uint256 displayNumber = _calculateCountdownBlocks(tokenId);
        uint256 currentRank = _getCurrentRank(tokenId);
        uint256 revealYear = 2026 + currentRank;
        
        // Opacity ramp: 0.15 + 0.85 * closeness
        uint16 opacityBps = uint16(1500 + (uint256(8500) * cBps) / 10000);
        string memory opacityStr = _bpsToDec4(opacityBps);
        
        uint16 hueBase = uint16((300 * cBps) / 10000);
        uint16 sBps = uint16(2500 + (7000 * cBps) / 10000);
        uint16 lBps = 6000;
        uint16 hueTop = hueBase > 8 ? hueBase - 8 : 0;
        uint16 hueMid = hueBase;
        uint16 hueBot = hueBase + 8 > 300 ? 300 : hueBase + 8;
        
        return string(abi.encodePacked(
            _generateTopRow(displayNumber, _hslCss(hueTop, sBps, lBps), opacityStr),
            _generateMiddleRow(displayNumber, _hslCss(hueMid, sBps, lBps), opacityStr),
            _generateBottomRow(displayNumber, _hslCss(hueBot, sBps, lBps), opacityStr),
            _generateRevealYear(revealYear, yearColor)
        ));
    }
    
    function _generateTopRow(uint256 displayNumber, string memory col, string memory opacity) internal view returns (string memory) {
        return string(abi.encodePacked(
            '<g transform="translate(65, 80)">',
            _generateAnimatedDigitColumn(0,   (displayNumber / 100000000000) % 10, col, opacity, "1200000000000s", 1200000000000, true),
            _generateAnimatedDigitColumn(60,  (displayNumber / 10000000000) % 10,  col, opacity, "120000000000s", 120000000000, true),
            _generateAnimatedDigitColumn(120, (displayNumber / 1000000000) % 10,   col, opacity, "12000000000s", 12000000000, true),
            _generateAnimatedDigitColumn(180, (displayNumber / 100000000) % 10,    col, opacity, "1200000000s", 1200000000, true),
            '</g>'
        ));
    }
    
    function _generateMiddleRow(uint256 displayNumber, string memory col, string memory opacity) internal view returns (string memory) {
        return string(abi.encodePacked(
            '<g transform="translate(65, 140)">',
            _generateAnimatedDigitColumn(0,   (displayNumber / 10000000) % 10, col, opacity, "120000000s", 120000000, true),
            _generateAnimatedDigitColumn(60,  (displayNumber / 1000000) % 10, col, opacity, "12000000s", 12000000, true),
            _generateAnimatedDigitColumn(120, (displayNumber / 100000) % 10, col, opacity, "1200000s", 1200000, true),
            _generateAnimatedDigitColumn(180, (displayNumber / 10000) % 10, col, opacity, "120000s", 120000, true),
            '</g>'
        ));
    }
    
    function _generateBottomRow(uint256 displayNumber, string memory col, string memory opacity) internal view returns (string memory) {
        return string(abi.encodePacked(
            '<g transform="translate(65, 200)">',
            _generateAnimatedDigitColumn(0,   (displayNumber / 1000) % 10, col, opacity, "120000s", 120000, true),
            _generateAnimatedDigitColumn(60,  (displayNumber / 100) % 10, col, opacity, "12000s", 12000, true),
            _generateAnimatedDigitColumn(120, (displayNumber / 10) % 10, col, opacity, "1200s", 1200, true),
            _generateAnimatedDigitColumn(180, displayNumber % 10, col, opacity, "120s", 120, false),
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
    
    function _generateAnimatedDigitColumn(uint256 xPos, uint256 startDigit, string memory color, string memory opacity, string memory duration, uint256 cycleSeconds, bool discrete) internal view returns (string memory) {
        // Ensure startDigit is single digit
        startDigit = startDigit % 10;
        uint256 elapsed = cycleSeconds == 0 ? 0 : (block.timestamp % cycleSeconds);

        string memory anim;
        string memory initialY;
        if (discrete) {
            // 10 steps per full cycle, advance 50px per step
            uint256 step = cycleSeconds / 10; // assume divisible
            uint256 timeInto = step == 0 ? 0 : (elapsed % step);
            uint256 timeToNext = step == 0 ? 0 : (step - timeInto) % step;
            string memory beginAttr = string(abi.encodePacked(timeToNext.toString(), "s"));
            string memory durAttr = string(abi.encodePacked((step * 10).toString(), "s"));
            initialY = "0"; // current digit is already at y=0 in the stack
            anim = string(
                abi.encodePacked(
                    '<animateTransform attributeName="transform" type="translate" calcMode="discrete" ',
                    'values="13 0;13 -50;13 -100;13 -150;13 -200;13 -250;13 -300;13 -350;13 -400;13 -450;13 -500;13 0" ',
                    'keyTimes="0;0.1;0.2;0.3;0.4;0.5;0.6;0.7;0.8;0.9;1" dur="', durAttr, '" begin="', beginAttr, '" repeatCount="indefinite"/>'
                )
            );
        } else {
            // Continuous scroll over full range in cycleSeconds (e.g., 120s)
            int256 y0 = -int256((500 * elapsed) / (cycleSeconds == 0 ? 1 : cycleSeconds));
            uint256 tRem = cycleSeconds == 0 ? 0 : ((cycleSeconds - elapsed) % cycleSeconds);
            initialY = _i2s(y0);
            string memory firstDur = string(abi.encodePacked(tRem.toString(), "s"));
            string memory loopDur = string(abi.encodePacked(cycleSeconds.toString(), "s"));
            anim = string(
                abi.encodePacked(
                    '<animateTransform attributeName="transform" type="translate" from="13 ', _i2s(y0), '" to="13 -500" dur="', firstDur, '" begin="0s" fill="freeze"/>',
                    '<animateTransform attributeName="transform" type="translate" from="13 0" to="13 -500" dur="', loopDur, '" begin="', firstDur, '" repeatCount="indefinite"/>'
                )
            );
        }

        return string(abi.encodePacked(
            '<g transform="translate(', xPos.toString(), ', 0)" clip-path="url(#digitWindow)">',
            '<g fill="', color, '" fill-opacity="', opacity, '" shape-rendering="crispEdges">',
            '<g transform="translate(13, ', initialY, ')">',
            _generateDigitSequence(startDigit),
            anim,
            '</g>',
            '</g>',
            '</g>'
        ));
    }

    function _i2s(int256 v) private pure returns (string memory) {
        if (v == 0) return "0";
        bool neg = v < 0;
        uint256 u = uint256(neg ? -v : v);
        string memory s = u.toString();
        return neg ? string(abi.encodePacked("-", s)) : s;
    }
    
    function _generateRevealYear(uint256 year, string memory fillColor) internal pure returns (string memory) {
        string memory d1 = ((year / 1000) % 10).toString();
        string memory d2 = ((year / 100) % 10).toString();
        string memory d3 = ((year / 10) % 10).toString();
        string memory d4 = (year % 10).toString();
        return string(abi.encodePacked(
            '<g transform="translate(38, 310)" fill="', fillColor, '">',
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

    // ----- Color helpers -----
    function _grayCss(uint16 gBps) private pure returns (string memory) {
        // gBps in 0..10000 maps to 0..255
        uint8 b = uint8((uint32(gBps) * 255 + 5000) / 10000);
        return string(abi.encodePacked("rgb(", uint256(b).toString(), ",", uint256(b).toString(), ",", uint256(b).toString(), ")"));
    }

    function _hslCss(uint16 hDeg, uint16 sBps, uint16 lBps) private pure returns (string memory) {
        // hDeg 0..360, s/l in 0..10000 bps; output hsl(h, s%, l%)
        string memory h = uint256(hDeg % 360).toString();
        string memory s = uint256((uint32(sBps) * 100 + 5000) / 10000).toString();
        string memory l = uint256((uint32(lBps) * 100 + 5000) / 10000).toString();
        return string(abi.encodePacked("hsl(", h, ",", s, "%,", l, "%)"));
    }

    // Convert 0..10000 bps to a fixed 4-decimal 0.xxxx (or "1" for 10000)
    function _bpsToDec4(uint16 bps) private pure returns (string memory) {
        if (bps >= 10000) return "1";
        uint256 frac = uint256(bps % 10000);
        return string(abi.encodePacked("0.", _pad4(frac)));
    }

    function _pad4(uint256 v) private pure returns (string memory) {
        if (v >= 1000) return v.toString();
        if (v >= 100)  return string(abi.encodePacked("0", v.toString()));
        if (v >= 10)   return string(abi.encodePacked("00", v.toString()));
        return string(abi.encodePacked("000", v.toString()));
    }
}

