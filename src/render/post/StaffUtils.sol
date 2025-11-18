// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";
import "./SvgMusicGlyphs.sol";
import "../../interfaces/IStaffUtils.sol";

contract StaffUtils is IStaffUtils {
    using Strings for uint256;
    // StaffGeometry struct is defined in IStaffUtils interface

    function standardGeometry() internal pure returns (StaffGeometry memory) {
        return StaffGeometry({
            canvasWidth: 360,
            canvasHeight: 240,
            staffLeft: 40,
            staffRight: 320,
            trebleTop: 40,
            trebleBottom: 80,
            bassTop: 130, 
            bassBottom: 170,
            lineSpacing: 10
        });
    }

    function largeGeometry() external pure override returns (StaffGeometry memory) {
        return StaffGeometry({
            canvasWidth: 600,
            canvasHeight: 600,
            staffLeft: 100,  // Match Python x1="100"
            staffRight: 500, // Match Python x2="500"
            trebleTop: 80,   // Match Python treble y=80
            trebleBottom: 240, // Match Python treble y=240 (80 + 4*40)
            bassTop: 320,    // Match Python bass y=320
            bassBottom: 480, // Match Python bass y=480 (320 + 4*40)
            lineSpacing: 40  // Match Python STAFF_SPACE = 40
        });
    }

    function generateStaffLines(
        StaffGeometry memory geom, 
        string memory strokeColor
    ) external pure override returns (string memory) {
        return string(abi.encodePacked(
            '<g stroke="', strokeColor, '" stroke-width="6">',
                // Treble staff (5 lines)
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.trebleTop).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.trebleTop).toString(), '"/>',
                
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.trebleTop + geom.lineSpacing).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.trebleTop + geom.lineSpacing).toString(), '"/>',
                
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.trebleTop + 2*geom.lineSpacing).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.trebleTop + 2*geom.lineSpacing).toString(), '"/>',
                
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.trebleTop + 3*geom.lineSpacing).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.trebleTop + 3*geom.lineSpacing).toString(), '"/>',
                
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.trebleBottom).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.trebleBottom).toString(), '"/>',
                
                // Bass staff (5 lines)
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.bassTop).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.bassTop).toString(), '"/>',
                
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.bassTop + geom.lineSpacing).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.bassTop + geom.lineSpacing).toString(), '"/>',
                
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.bassTop + 2*geom.lineSpacing).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.bassTop + 2*geom.lineSpacing).toString(), '"/>',
                
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.bassTop + 3*geom.lineSpacing).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.bassTop + 3*geom.lineSpacing).toString(), '"/>',
                
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.bassBottom).toString(), 
                '" x2="', uint256(geom.staffRight).toString(), '" y2="', uint256(geom.bassBottom).toString(), '"/>',
                
                // Vertical bar lines (thicker stroke)
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.trebleTop - 12).toString(),
                '" x2="', uint256(geom.staffLeft).toString(), '" y2="', uint256(geom.trebleBottom + 12).toString(), '" stroke-width="14"/>',
                '<line x1="', uint256(geom.staffLeft).toString(), '" y1="', uint256(geom.bassTop - 12).toString(),
                '" x2="', uint256(geom.staffLeft).toString(), '" y2="', uint256(geom.bassBottom + 12).toString(), '" stroke-width="14"/>',
            '</g>'
        ));
    }

    function generateClefs(
        StaffGeometry memory geom,
        string memory fillColor
    ) external pure override returns (string memory) {
        // Calculate clef positions - treble curl on G line, bottom on bottom line
        // Scale 0.52, fine-tuned position
        int16 trebleClefX = int16(geom.staffLeft) - 128; // Left 3px more
        int16 bassClefX = int16(geom.staffLeft) + 27;
        int16 trebleClefY = int16(geom.trebleTop) - 75;  // Down 3px more from -78
        int16 bassClefY = int16(geom.bassTop);
        
        return string(abi.encodePacked(
            '<g fill="', fillColor, '" color="', fillColor, '">',
                // Treble clef - scale 0.52, moved up 10px
                '<g transform="translate(', _int16ToString(trebleClefX), ',', _int16ToString(trebleClefY), ') scale(0.52)">',
                    '<use href="#treble"/>',
                '</g>',
                // Bass clef (unchanged)
                '<g transform="translate(', _int16ToString(bassClefX), ',', _int16ToString(bassClefY), ') scale(0.23)">',
                    '<use href="#bass"/>',
                '</g>',
            '</g>'
        ));
    }

    function _int16ToString(int16 value) private pure returns (string memory) {
        if (value >= 0) {
            return uint256(int256(value)).toString();
        } else {
            return string(abi.encodePacked("-", uint256(int256(-value)).toString()));
        }
    }

    function generateGrandStaff(
        StaffGeometry memory geom,
        string memory strokeColor,
        string memory fillColor
    ) external view override returns (string memory) {
        return string(abi.encodePacked(
            this.generateStaffLines(geom, strokeColor),
            this.generateClefs(geom, fillColor)
        ));
    }
}
