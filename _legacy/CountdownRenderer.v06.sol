// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../IRenderTypes.sol";

/**
 * @title CountdownRenderer v0.6 - Dynamic Layout
 * @notice Smart countdown that only shows needed digits, arranged in 4-digit rows
 * @dev No leading zeros - expands vertically as needed. Efficient and clean.
 * 
 * Examples:
 *   60240 →     "    6" / "0240" (2 rows, 5 digits)
 *   1004940 →   "  100" / "4940" (2 rows, 7 digits)
 *   999999999 → "9999" / "9999" / "9999" (3 rows, 12 digits)
 */
library CountdownRenderer {
    using Strings for uint256;
    using RenderTypes for RenderTypes.RenderCtx;

    struct PlaceParams {
        int256 baseOffsetY;
        int256 beginPhase;
        uint256 duration;
    }

    function render(RenderTypes.RenderCtx memory ctx) internal pure returns (string memory) {
        uint256 revealTimestamp = ctx.revealYear * 365 days + 1735689600;
        uint256 secondsRemaining = ctx.nowTs >= revealTimestamp ? 0 : (revealTimestamp - ctx.nowTs);
        
        // Cap at max representable (12 digits worth of seconds)
        uint256 maxSeconds = 999999999999;
        if (secondsRemaining > maxSeconds) {
            secondsRemaining = maxSeconds;
        }

        return string(abi.encodePacked(
            _svgHeader(secondsRemaining),
            _svgDefs(secondsRemaining),
            _svgBackground(),
            _renderDigits(secondsRemaining),
            _progressBar(secondsRemaining),
            _footer(),
            '</svg>'
        ));
    }

    function _svgHeader(uint256 secondsRemaining) private pure returns (string memory) {
        // Calculate viewport height based on number of rows needed
        uint256 numDigits = _countDigits(secondsRemaining);
        uint256 numRows = (numDigits + 3) / 4; // Ceiling division
        uint256 height = 140 + (numRows * 110); // Base + rows
        
        return string(abi.encodePacked(
            '<?xml version="1.0" encoding="UTF-8"?>',
            '<svg xmlns="http://www.w3.org/2000/svg" width="360" height="',
            height.toString(),
            '" viewBox="0 0 360 ',
            height.toString(),
            '" preserveAspectRatio="xMidYMid meet">'
        ));
    }

    function _countDigits(uint256 value) private pure returns (uint256) {
        if (value == 0) return 1;
        uint256 digits = 0;
        while (value > 0) {
            digits++;
            value /= 10;
        }
        return digits;
    }

    function _renderDigits(uint256 secondsRemaining) private pure returns (string memory) {
        uint256 numDigits = _countDigits(secondsRemaining);
        
        // Build digit by digit from right to left (place 0, 1, 2, ...)
        string memory result = "";
        
        for (uint256 place = 0; place < numDigits; place++) {
            // Calculate position in 4-column grid, right-aligned
            uint256 positionFromRight = place; // 0 = ones, 1 = tens, etc.
            uint256 col = 3 - (positionFromRight % 4); // Right-align in 4 columns
            uint256 row = positionFromRight / 4;
            
            uint256 x = 50 + (col * 80); // Column spacing
            uint256 y = 40 + (row * 110); // Row spacing
            
            string memory clipId = string(abi.encodePacked("c", place.toString()));
            
            result = string(abi.encodePacked(
                result,
                _renderDigitAt(x, y, secondsRemaining, place, clipId)
            ));
        }
        
        return result;
    }

    function _renderDigitAt(
        uint256 x,
        uint256 y,
        uint256 secondsRemaining,
        uint256 place,
        string memory clipId
    ) private pure returns (string memory) {
        PlaceParams memory params = _calculatePlace(secondsRemaining, place);
        
        string memory baseYStr = _int256ToString(params.baseOffsetY);
        string memory beginStr = _int256ToString(params.beginPhase);
        string memory durStr = params.duration.toString();
        
        string memory animation = secondsRemaining > 0 
            ? string(abi.encodePacked(
                '<animateTransform attributeName="transform" type="translate" additive="sum" calcMode="discrete" ',
                'dur="', durStr, 's" begin="', beginStr, 's" repeatCount="indefinite" fill="freeze" ',
                'values="0,0;0,-50;0,-100;0,-150;0,-200;0,-250;0,-300;0,-350;0,-400;0,-450;0,0"/>'
            ))
            : '';
        
        return string(abi.encodePacked(
            // Clip path definition
            '<clipPath id="', clipId, '"><rect x="', x.toString(), '" y="', y.toString(), '" width="60" height="50" rx="6" ry="6"/></clipPath>',
            // Digit box background
            '<rect class="digit-bg" x="', x.toString(), '" y="', y.toString(), '" width="60" height="50" rx="6" ry="6"/>',
            // Digit group with animation
            '<g clip-path="url(#', clipId, ')">',
            '<g transform="translate(0,', baseYStr, ')">',
            _digitStack(x + 30, y), // Center x in 60px box
            animation,
            '</g>',
            '</g>'
        ));
    }

    function _calculatePlace(uint256 secondsRemaining, uint256 place) private pure returns (PlaceParams memory params) {
        uint256 stepSec = 12 * (10 ** place);
        uint256 cycleSec = stepSec * 10;
        uint256 r = secondsRemaining % cycleSec;
        uint256 digit = r / stepSec;
        uint256 stackIdx = 9 - digit;
        
        params.baseOffsetY = -int256(50 * stackIdx); // 50px spacing (smaller for compact)
        params.beginPhase = -int256(r % stepSec);
        params.duration = cycleSec;
    }

    function _digitStack(uint256 xPos, uint256 yBase) private pure returns (string memory) {
        string memory x = xPos.toString();
        // Smaller digits, 50px spacing
        return string(abi.encodePacked(
            '<text class="digit-text" x="', x, '" y="', (yBase + 37).toString(), '">9</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 87).toString(), '">8</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 137).toString(), '">7</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 187).toString(), '">6</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 237).toString(), '">5</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 287).toString(), '">4</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 337).toString(), '">3</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 387).toString(), '">2</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 437).toString(), '">1</text>',
            '<text class="digit-text" x="', x, '" y="', (yBase + 487).toString(), '">0</text>'
        ));
    }

    function _progressBar(uint256 secondsRemaining) private pure returns (string memory) {
        uint256 numDigits = _countDigits(secondsRemaining);
        uint256 numRows = (numDigits + 3) / 4;
        uint256 yPos = 60 + (numRows * 110); // Below digits
        
        string memory durStr = secondsRemaining > 0 ? secondsRemaining.toString() : "1";
        
        return string(abi.encodePacked(
            '<g transform="translate(50, ', yPos.toString(), ')">',
            '<rect class="progress-track" x="0" y="0" width="260" height="6" rx="3" ry="3"/>',
            '<rect class="progress-bar" x="0" y="0" width="260" height="6" rx="3" ry="3">',
            secondsRemaining > 0 
                ? string(abi.encodePacked(
                    '<animate attributeName="width" from="260" to="0" dur="', durStr, 's" begin="0s" fill="freeze"/>'
                ))
                : '',
            '</rect>',
            '</g>'
        ));
    }

    function _svgDefs(uint256 secondsRemaining) private pure returns (string memory) {
        // Add split seam for each row
        uint256 numDigits = _countDigits(secondsRemaining);
        uint256 numRows = (numDigits + 3) / 4;
        
        string memory seams = "";
        for (uint256 row = 0; row < numRows; row++) {
            uint256 y = 40 + (row * 110) + 25; // Middle of each 50px box
            seams = string(abi.encodePacked(
                seams,
                '<line class="seam-dark" x1="50" y1="', y.toString(), '" x2="310" y2="', y.toString(), '"/>',
                '<line class="seam-light" x1="50" y1="', (y + 2).toString(), '" x2="310" y2="', (y + 2).toString(), '"/>'
            ));
        }
        
        return string(abi.encodePacked(
            '<defs>',
            '<style>'
            '.bg { fill: #0a0a0f; }'
            '.frame { fill: #12121a; stroke: #1e1e2a; stroke-width: 2; }'
            '.digit-bg { fill: #171723; stroke: #2a2a3b; stroke-width: 1; }'
            '.digit-text { fill: #e9eef7; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-weight: 700; font-size: 42px; text-anchor: middle; }'
            '.seam-dark { stroke: rgba(0,0,0,0.55); stroke-width: 1; }'
            '.seam-light { stroke: rgba(255,255,255,0.16); stroke-width: 1; }'
            '.progress-track { fill: #232336; }'
            '.progress-bar { fill: #4c9cff; }'
            '</style>',
            '</defs>',
            '<g>', seams, '</g>'
        ));
    }

    function _svgBackground() private pure returns (string memory) {
        return '<rect class="bg" x="0" y="0" width="100%" height="100%"/>';
    }

    function _footer() private pure returns (string memory) {
        return '<text x="180" y="40" fill="#9aa6be" '
               'font-family="system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial" '
               'font-size="12" text-anchor="middle" opacity="0.6">blocks until reveal</text>';
    }

    function _int256ToString(int256 value) private pure returns (string memory) {
        if (value >= 0) {
            return uint256(value).toString();
        } else {
            return string(abi.encodePacked('-', uint256(-value).toString()));
        }
    }
}
