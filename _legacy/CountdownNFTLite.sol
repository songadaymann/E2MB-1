// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import "openzeppelin-contracts/contracts/utils/Strings.sol";

// A lighter variant for onchain demo under EIP-170 size limit
contract CountdownNFTLite is ERC721, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    mapping(uint256 => uint256) public points;
    mapping(uint256 => uint256) public basePermutation;

    event PointsEarned(uint256 indexed tokenId, uint256 points, uint256 newTotal);

    constructor() ERC721("Countdown NFT Lite", "COUNTLITE") Ownable(msg.sender) {}

    function mint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter++;
        basePermutation[tokenId] = tokenId;
        _mint(to, tokenId);
    }

    function earnPoints(uint256 tokenId, uint256 amount) public {
        require(ownerOf(tokenId) == msg.sender, "Not token owner");
        points[tokenId] += amount;
        emit PointsEarned(tokenId, amount, points[tokenId]);
    }

    function getCurrentRank(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "DNE");
        return _getCurrentRank(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "DNE");
        string memory svg = _svg(tokenId);
        string memory json = string(abi.encodePacked(
            '{"name":"CountdownLite #', tokenId.toString(), '",',
            '"description":"Opacity-by-rank demo (lite)",',
            '"image":"data:image/svg+xml;base64,', Base64.encode(bytes(svg)), '"}'
        ));
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
    }

    function _svg(uint256 tokenId) internal view returns (string memory) {
        uint256 cBps = (_tokenIdCounter > 1)
            ? (10000 - (_getCurrentRank(tokenId) * 10000) / (_tokenIdCounter - 1))
            : 0;
        string memory opacity = _bpsToDec4(uint16(1500 + (uint256(8500) * cBps) / 10000));
        string memory bg = _grayCss(uint16(10000 - cBps));
        string memory yearCol = _grayCss(uint16(cBps));

        uint256 displayNumber = _calcBlocks(tokenId);
        uint256 currentRank = _getCurrentRank(tokenId);
        uint256 revealYear = 2026 + currentRank;

        string memory head = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 360 300" width="360" height="300">',
            '<defs>', _digitDefs(), _clip(), '</defs>',
            '<rect width="100%" height="100%" fill="', bg, '"/>'
        ));

        string memory row = _row(displayNumber, yearCol, opacity);
        string memory yr = _year(revealYear, yearCol);
        return string(abi.encodePacked(head, row, yr, '</svg>'));
    }

    function _row(uint256 displayNumber, string memory col, string memory opacity) internal view returns (string memory) {
        return string(abi.encodePacked(
            '<g transform="translate(65, 120)">',
            _col(0,   (displayNumber / 1000) % 10, col, opacity, 120000, true),
            _col(60,  (displayNumber / 100) % 10, col, opacity, 12000,  true),
            _col(120, (displayNumber / 10) % 10, col, opacity, 1200,   true),
            _col(180, displayNumber % 10,       col, opacity, 120,    false),
            '</g>'
        ));
    }

    function _col(uint256 xPos, uint256 startDigit, string memory color, string memory opacity, uint256 cycleSeconds, bool discrete) internal view returns (string memory) {
        startDigit = startDigit % 10;
        uint256 elapsed = cycleSeconds == 0 ? 0 : (block.timestamp % cycleSeconds);
        string memory anim;
        string memory initialY;
        if (discrete) {
            uint256 step = cycleSeconds / 10;
            uint256 timeInto = step == 0 ? 0 : (elapsed % step);
            uint256 timeToNext = step == 0 ? 0 : (step - timeInto) % step;
            string memory beginAttr = string(abi.encodePacked(timeToNext.toString(), "s"));
            string memory durAttr = string(abi.encodePacked((step * 10).toString(), "s"));
            initialY = "0";
            anim = string(abi.encodePacked(
                '<animateTransform attributeName="transform" type="translate" calcMode="discrete" ',
                'values="13 0;13 -50;13 -100;13 -150;13 -200;13 -250;13 -300;13 -350;13 -400;13 -450;13 -500;13 0" ',
                'keyTimes="0;0.1;0.2;0.3;0.4;0.5;0.6;0.7;0.8;0.9;1" dur="', durAttr, '" begin="', beginAttr, '" repeatCount="indefinite"/>'
            ));
        } else {
            int256 y0 = -int256((500 * elapsed) / (cycleSeconds == 0 ? 1 : cycleSeconds));
            uint256 tRem = cycleSeconds == 0 ? 0 : ((cycleSeconds - elapsed) % cycleSeconds);
            initialY = _i2s(y0);
            string memory firstDur = string(abi.encodePacked(tRem.toString(), "s"));
            string memory loopDur = string(abi.encodePacked(cycleSeconds.toString(), "s"));
            anim = string(abi.encodePacked(
                '<animateTransform attributeName="transform" type="translate" from="13 ', _i2s(y0), '" to="13 -500" dur="', firstDur, '" begin="0s" fill="freeze"/>',
                '<animateTransform attributeName="transform" type="translate" from="13 0" to="13 -500" dur="', loopDur, '" begin="', firstDur, '" repeatCount="indefinite"/>'
            ));
        }
        return string(abi.encodePacked(
            '<g transform="translate(', xPos.toString(), ', 0)" clip-path="url(#digitWindow)">',
            '<g fill="', color, '" fill-opacity="', opacity, '" shape-rendering="crispEdges">',
            '<g transform="translate(13, ', initialY, ')">',
            _seq(startDigit), anim,
            '</g></g></g>'
        ));
    }

    function _calcBlocks(uint256 tokenId) internal view returns (uint256) {
        uint256 revealYear = 2026 + _getCurrentRank(tokenId);
        uint256 revealTimestamp = _jan1(revealYear);
        if (block.timestamp >= revealTimestamp) return 0;
        uint256 secondsRemaining = revealTimestamp - block.timestamp;
        uint256 blocksRemaining = secondsRemaining / 12;
        if (blocksRemaining > 9999) return 9999;
        return blocksRemaining;
    }

    function _getCurrentRank(uint256 tokenId) internal view returns (uint256) {
        uint256 myPoints = points[tokenId];
        uint256 myBasePermutation = basePermutation[tokenId];
        uint256 rank = 0;
        for (uint256 i = 0; i < _tokenIdCounter; i++) {
            if (i == tokenId) continue;
            uint256 op = points[i];
            uint256 ob = basePermutation[i];
            if (op > myPoints) rank++;
            else if (op == myPoints && ob < myBasePermutation) rank++;
        }
        return rank;
    }

    function _exists(uint256 tokenId) internal view returns (bool) { return tokenId < _tokenIdCounter; }

    function _jan1(uint256 year) internal pure returns (uint256) {
        uint256 y = year - 1970; uint256 leap = y / 4; return (y * 365 + leap) * 86400;
    }

    function _digitDefs() internal pure returns (string memory) {
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

    function _clip() internal pure returns (string memory) {
        return '<clipPath id="digitWindow" clipPathUnits="userSpaceOnUse"><rect x="0" y="0" width="50" height="50"/></clipPath>';
    }

    function _year(uint256 year, string memory fillColor) internal pure returns (string memory) {
        string memory d1 = ((year / 1000) % 10).toString();
        string memory d2 = ((year / 100) % 10).toString();
        string memory d3 = ((year / 10) % 10).toString();
        string memory d4 = (year % 10).toString();
        return string(abi.encodePacked(
            '<g transform="translate(38, 220)" fill="', fillColor, '"><g transform="scale(1.5)">',
            '<use href="#d', d1, '" x="0" y="0"/>',
            '<use href="#d', d2, '" x="55" y="0"/>',
            '<use href="#d', d3, '" x="110" y="0"/>',
            '<use href="#d', d4, '" x="165" y="0"/>',
            '</g></g>'
        ));
    }

    function _seq(uint256 startDigit) internal pure returns (string memory) {
        return string(abi.encodePacked(
            '<use href="#d', startDigit.toString(), '" y="0"/>',
            '<use href="#d', ((startDigit + 9) % 10).toString(), '" y="50"/>',
            '<use href="#d', ((startDigit + 8) % 10).toString(), '" y="100"/>',
            '<use href="#d', ((startDigit + 7) % 10).toString(), '" y="150"/>',
            '<use href="#d', ((startDigit + 6) % 10).toString(), '" y="200"/>',
            '<use href="#d', ((startDigit + 5) % 10).toString(), '" y="250"/>',
            '<use href="#d', ((startDigit + 4) % 10).toString(), '" y="300"/>',
            '<use href="#d', ((startDigit + 3) % 10).toString(), '" y="350"/>',
            '<use href="#d', ((startDigit + 2) % 10).toString(), '" y="400"/>',
            '<use href="#d', ((startDigit + 1) % 10).toString(), '" y="450"/>',
            '<use href="#d', startDigit.toString(), '" y="500"/>'
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

    function _i2s(int256 v) private pure returns (string memory) {
        if (v == 0) return "0";
        bool neg = v < 0;
        uint256 u = uint256(neg ? -v : v);
        string memory s = u.toString();
        return neg ? string(abi.encodePacked("-", s)) : s;
    }
}
