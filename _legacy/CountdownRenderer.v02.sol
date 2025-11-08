// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../IRenderTypes.sol";

/**
 * @title CountdownRenderer v0.2
 * @notice Simplified discrete-flip countdown (no scrolling)
 * @dev Each digit flips instantly based on blocks elapsed
 */
library CountdownRenderer {
    using Strings for uint256;
    using RenderTypes for RenderTypes.RenderCtx;

    function render(RenderTypes.RenderCtx memory ctx) internal pure returns (string memory) {
        // Opacity ramp: 0.15 + 0.85 * closeness (capped at 100%)
        uint256 closenessCapped = ctx.closenessBps > 10000 ? 10000 : ctx.closenessBps;
        string memory opacity = _bpsToDec4(uint16(1500 + (uint256(8500) * closenessCapped) / 10000));
        
        // Background brightness
        uint256 bgBrightness = closenessCapped >= 10000 ? 0 : (10000 - closenessCapped);
        string memory bg = _grayCss(uint16(bgBrightness));
        
        // Digit color
        string memory digitCol = (ctx.closenessBps >= 5000) ? "rgb(255,255,255)" : "rgb(0,0,0)";

        // Calculate current block count based on time elapsed
        // blocksDisplay is blocks remaining, but we recalculate from time for animation
        uint256 blocksElapsed = ctx.nowTs / 12; // Assume 12 sec per block
        uint256 currentBlocks = ctx.blocksDisplay > blocksElapsed ? ctx.blocksDisplay - blocksElapsed : 0;

        string memory head = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 420" width="360" height="420">',
            '<defs>', _digitDefs(), '</defs>',
            '<rect width="100%" height="100%" fill="', bg, '"/>'
        ));

        // Three rows of 4 digits each (12 total digits for large block counts)
        string memory rows = string(abi.encodePacked(
            _digitRow(80, currentBlocks, digitCol, opacity, 100000000000, 10000000000, 1000000000, 100000000),
            _digitRow(140, currentBlocks, digitCol, opacity, 10000000, 1000000, 100000, 10000),
            _digitRow(200, currentBlocks, digitCol, opacity, 1000, 100, 10, 1)
        ));
        
        string memory yr = _year(ctx.revealYear, digitCol);
        return string(abi.encodePacked(head, rows, yr, '</svg>'));
    }

    function _digitRow(
        uint256 y,
        uint256 displayNumber,
        string memory col,
        string memory opacity,
        uint256 d3, uint256 d2, uint256 d1, uint256 d0
    ) private pure returns (string memory) {
        uint256 dig3 = (displayNumber / d3) % 10;
        uint256 dig2 = (displayNumber / d2) % 10;
        uint256 dig1 = (displayNumber / d1) % 10;
        uint256 dig0 = (displayNumber / d0) % 10;
        
        return string(abi.encodePacked(
            '<g transform="translate(65,', y.toString(), ')" fill="', col, '" fill-opacity="', opacity, '">',
            '<use href="#d', dig3.toString(), '" x="13"/>',
            '<use href="#d', dig2.toString(), '" x="73"/>',
            '<use href="#d', dig1.toString(), '" x="133"/>',
            '<use href="#d', dig0.toString(), '" x="193"/>',
            '</g>'
        ));
    }

    function _digitDefs() private pure returns (string memory) {
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

    function _year(uint256 year, string memory fillColor) private pure returns (string memory) {
        string memory d1 = ((year / 1000) % 10).toString();
        string memory d2 = ((year / 100) % 10).toString();
        string memory d3 = ((year / 10) % 10).toString();
        string memory d4 = (year % 10).toString();
        return string(abi.encodePacked(
            '<g transform="translate(38, 310)" fill="', fillColor, '"><g transform="scale(1.5)">',
            '<use href="#d', d1, '" x="0" y="0"/>',
            '<use href="#d', d2, '" x="55" y="0"/>',
            '<use href="#d', d3, '" x="110" y="0"/>',
            '<use href="#d', d4, '" x="165" y="0"/>',
            '</g></g>'
        ));
    }

    function _grayCss(uint16 gBps) private pure returns (string memory) {
        uint8 b = uint8((uint32(gBps) * 255 + 5000) / 10000);
        return string(abi.encodePacked("rgb(", uint256(b).toString(), ",", uint256(b).toString(), ",", uint256(b).toString(), ")"));
    }

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
