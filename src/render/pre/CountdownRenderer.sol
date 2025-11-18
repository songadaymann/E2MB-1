// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "../IRenderTypes.sol";

library CountdownRenderer {
    using Strings for uint256;
    using RenderTypes for RenderTypes.RenderCtx;

    function render(RenderTypes.RenderCtx memory ctx) internal pure returns (string memory) {
        uint256 closenessCapped = ctx.closenessBps > 10000 ? 10000 : ctx.closenessBps;
        string memory opacity = _bpsToDec4(uint16(1500 + (uint256(8500) * closenessCapped) / 10000));
        
        uint256 bgBrightness = closenessCapped >= 10000 ? 0 : (10000 - closenessCapped);
        string memory bg = _grayCss(uint16(bgBrightness));
        
        string memory digitCol = (ctx.closenessBps >= 5000) ? "rgb(255,255,255)" : "rgb(0,0,0)";

        string memory head = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 360 420" width="360" height="420">',
            '<defs>', _digitDefs(), '</defs>',
            '<rect width="100%" height="100%" fill="', bg, '"/>'
        ));

        string memory rows = string(abi.encodePacked(
            _digitRow(80, ctx.blocksDisplay, digitCol, opacity, ctx.nowTs, 100000000000, 10000000000, 1000000000, 100000000),
            _digitRow(140, ctx.blocksDisplay, digitCol, opacity, ctx.nowTs, 10000000, 1000000, 100000, 10000),
            _digitRow(200, ctx.blocksDisplay, digitCol, opacity, ctx.nowTs, 1000, 100, 10, 1)
        ));
        
        string memory progressBar = _progressBar(digitCol, ctx.nowTs);
        
        string memory yr = _year(ctx.revealYear, digitCol);
        
        return string(abi.encodePacked(head, rows, progressBar, yr, '</svg>'));
    }

    function _digitRow(
        uint256 y,
        uint256 displayNumber,
        string memory col,
        string memory opacity,
        uint256 nowTs,
        uint256 d3, uint256 d2, uint256 d1, uint256 d0
    ) private pure returns (string memory) {
        uint256 blocksElapsed = nowTs / 12;
        uint256 currentBlocks = displayNumber > blocksElapsed ? displayNumber - blocksElapsed : 0;
        
        uint256 dig3 = (currentBlocks / d3) % 10;
        uint256 dig2 = (currentBlocks / d2) % 10;
        uint256 dig1 = (currentBlocks / d1) % 10;
        uint256 dig0 = (currentBlocks / d0) % 10;
        
        return string(abi.encodePacked(
            '<g transform="translate(65,', y.toString(), ')" fill="', col, '" fill-opacity="', opacity, '">',
            '<use href="#d', dig3.toString(), '" x="13"/>',
            '<use href="#d', dig2.toString(), '" x="73"/>',
            '<use href="#d', dig1.toString(), '" x="133"/>',
            '<use href="#d', dig0.toString(), '" x="193"/>',
            '</g>'
        ));
    }

    function _progressBar(string memory color, uint256 nowTs) private pure returns (string memory) {
        uint256 secondsIntoBlock = nowTs % 12;
        uint256 progressWidth = (secondsIntoBlock * 260) / 12; // 0-260px over 12 seconds
        
        uint256 timeRemaining = 12 - secondsIntoBlock;
        
        return string(abi.encodePacked(
            '<g transform="translate(50, 270)">',
            // Background track
            '<rect x="0" y="0" width="260" height="6" fill="', color, '" opacity="0.1" rx="3"/>',
            // Animated fill bar
            '<rect x="0" y="0" height="6" fill="', color, '" opacity="0.6" rx="3">',
            '<animate attributeName="width" ',
            'from="', progressWidth.toString(), '" to="260" ',
            'dur="', timeRemaining.toString(), 's" begin="0s" fill="freeze"/>',
            '<animate attributeName="width" ',
            'from="0" to="260" ',
            'dur="12s" begin="', timeRemaining.toString(), 's" repeatCount="indefinite"/>',
            '</rect>',
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
            '<g transform="translate(38, 335)" fill="', fillColor, '"><g transform="scale(1.5)">',
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
