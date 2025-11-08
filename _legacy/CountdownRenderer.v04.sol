// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../IRenderTypes.sol";

/**
 * @title CountdownRenderer v0.4 - Flip Clock with Negative Begin
 * @notice Pure on-chain SVG countdown using discrete flip animations synced via negative begin
 * @dev Based on Oracle's approach: each digit place animates independently (10s, 100s, 1000s, 10000s)
 *      with negative begin values to sync to current time. No JavaScript required.
 * 
 * Key Innovation: SMIL animations can use begin="-Xs" to start "in the past", syncing perfectly
 * to the current countdown state. Each tokenURI() call recalculates phases for accuracy.
 */
library CountdownRenderer {
    using Strings for uint256;
    using Strings for int256;
    using RenderTypes for RenderTypes.RenderCtx;

    function render(RenderTypes.RenderCtx memory ctx) internal pure returns (string memory) {
        // Calculate time parameters for countdown
        uint256 revealTimestamp = ctx.revealYear * 365 days + 1735689600; // Approximate Jan 1 timestamp
        uint256 secondsRemaining = ctx.nowTs >= revealTimestamp ? 0 : (revealTimestamp - ctx.nowTs);
        
        // Total countdown duration (from some past start point; we'll use a large value)
        // For simplicity, use 999,999 seconds as max (11.5 days worth)
        uint256 totalSeconds = 999999;
        if (secondsRemaining > totalSeconds) {
            secondsRemaining = totalSeconds;
        }
        
        // Calculate how much time has elapsed (negative value for begin)
        int256 elapsedSeconds = int256(totalSeconds - secondsRemaining);
        
        // Calculate begin phases for each digit place
        // These are negative values representing how far "into" each cycle we are
        int256 onesBegin = -int256(secondsRemaining % 10);
        int256 tensBegin = -int256(secondsRemaining % 100);
        int256 hundredsBegin = -int256(secondsRemaining % 1000);
        int256 thousandsBegin = -int256(secondsRemaining % 10000);
        
        return string(abi.encodePacked(
            _svgHeader(),
            _svgDefs(),
            _svgBackground(),
            _digitBoxes(),
            _splitBarSeam(),
            _renderDigit(124, thousandsBegin, "10000", secondsRemaining, "clip-thousands"),
            _renderDigit(232, hundredsBegin, "1000", secondsRemaining, "clip-hundreds"),
            _renderDigit(340, tensBegin, "100", secondsRemaining, "clip-tens"),
            _renderDigit(448, onesBegin, "10", secondsRemaining, "clip-ones"),
            _progressBar(elapsedSeconds, totalSeconds, secondsRemaining),
            _footer(),
            '</svg>'
        ));
    }

    function _svgHeader() private pure returns (string memory) {
        return '<?xml version="1.0" encoding="UTF-8"?>'
               '<svg xmlns="http://www.w3.org/2000/svg" width="640" height="260" viewBox="0 0 640 260" preserveAspectRatio="xMidYMid meet">';
    }

    function _svgDefs() private pure returns (string memory) {
        return string(abi.encodePacked(
            '<defs>',
            '<style>'
            '.bg { fill: #0a0a0f; }'
            '.frame { fill: #12121a; stroke: #1e1e2a; stroke-width: 2; }'
            '.digit-bg { fill: #171723; stroke: #2a2a3b; stroke-width: 2; rx: 10; ry: 10; }'
            '.digit-text { fill: #e9eef7; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, "Liberation Mono", monospace; font-weight: 700; font-size: 84px; text-anchor: middle; }'
            '.seam-dark { stroke: rgba(0,0,0,0.55); stroke-width: 2; }'
            '.seam-light { stroke: rgba(255,255,255,0.16); stroke-width: 1; }'
            '.progress-track { fill: #232336; }'
            '.progress-bar { fill: #4c9cff; }'
            '</style>',
            '<clipPath id="clip-thousands"><rect x="76" y="40" width="96" height="100" rx="10" ry="10"/></clipPath>',
            '<clipPath id="clip-hundreds"><rect x="184" y="40" width="96" height="100" rx="10" ry="10"/></clipPath>',
            '<clipPath id="clip-tens"><rect x="292" y="40" width="96" height="100" rx="10" ry="10"/></clipPath>',
            '<clipPath id="clip-ones"><rect x="400" y="40" width="96" height="100" rx="10" ry="10"/></clipPath>',
            '</defs>'
        ));
    }

    function _svgBackground() private pure returns (string memory) {
        return '<rect class="bg" x="0" y="0" width="640" height="260"/>'
               '<rect class="frame" x="24" y="20" width="592" height="220" rx="14" ry="14"/>';
    }

    function _digitBoxes() private pure returns (string memory) {
        return '<rect class="digit-bg" x="76" y="40" width="96" height="100"/>'
               '<rect class="digit-bg" x="184" y="40" width="96" height="100"/>'
               '<rect class="digit-bg" x="292" y="40" width="96" height="100"/>'
               '<rect class="digit-bg" x="400" y="40" width="96" height="100"/>';
    }

    function _splitBarSeam() private pure returns (string memory) {
        return '<g>'
               '<line class="seam-dark" x1="76" y1="90" x2="496" y2="90"/>'
               '<line class="seam-light" x1="76" y1="92" x2="496" y2="92"/>'
               '</g>';
    }

    function _renderDigit(
        uint256 xPos,
        int256 beginPhase,
        string memory duration,
        uint256 secondsRemaining,
        string memory clipId
    ) private pure returns (string memory) {
        string memory beginStr = _int256ToString(beginPhase);
        string memory endStr = uint256(secondsRemaining).toString();
        
        return string(abi.encodePacked(
            '<g clip-path="url(#', clipId, ')">',
            '<g transform="translate(0,0)">',
            _digitStack(xPos),
            '<animateTransform attributeName="transform" type="translate" calcMode="discrete" ',
            'dur="', duration, 's" begin="', beginStr, 's" end="', endStr, 's" ',
            'repeatCount="indefinite" fill="freeze" ',
            'values="0,0;0,-100;0,-200;0,-300;0,-400;0,-500;0,-600;0,-700;0,-800;0,-900;0,0"/>',
            '</g>',
            '</g>'
        ));
    }

    function _digitStack(uint256 xPos) private pure returns (string memory) {
        string memory x = xPos.toString();
        return string(abi.encodePacked(
            '<text class="digit-text" x="', x, '" y="74">9</text>',
            '<text class="digit-text" x="', x, '" y="174">8</text>',
            '<text class="digit-text" x="', x, '" y="274">7</text>',
            '<text class="digit-text" x="', x, '" y="374">6</text>',
            '<text class="digit-text" x="', x, '" y="474">5</text>',
            '<text class="digit-text" x="', x, '" y="574">4</text>',
            '<text class="digit-text" x="', x, '" y="674">3</text>',
            '<text class="digit-text" x="', x, '" y="774">2</text>',
            '<text class="digit-text" x="', x, '" y="874">1</text>',
            '<text class="digit-text" x="', x, '" y="974">0</text>'
        ));
    }

    function _progressBar(int256 elapsed, uint256 total, uint256 remaining) private pure returns (string memory) {
        string memory totalStr = total.toString();
        string memory beginStr = _int256ToString(-elapsed);
        string memory endStr = remaining.toString();
        
        return string(abi.encodePacked(
            '<g transform="translate(76, 170)">',
            '<rect class="progress-track" x="0" y="0" width="420" height="8" rx="4" ry="4"/>',
            '<rect class="progress-bar" x="0" y="0" width="420" height="8" rx="4" ry="4">',
            '<animate attributeName="width" from="420" to="0" ',
            'dur="', totalStr, 's" begin="', beginStr, 's" end="', endStr, 's" fill="freeze"/>',
            '</rect>',
            '</g>'
        ));
    }

    function _footer() private pure returns (string memory) {
        return '<text x="320" y="210" fill="#9aa6be" '
               'font-family="system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial" '
               'font-size="14" text-anchor="middle">Time remaining</text>';
    }

    // Helper to convert int256 to string (including negative values)
    function _int256ToString(int256 value) private pure returns (string memory) {
        if (value >= 0) {
            return uint256(value).toString();
        } else {
            return string(abi.encodePacked('-', uint256(-value).toString()));
        }
    }
}
