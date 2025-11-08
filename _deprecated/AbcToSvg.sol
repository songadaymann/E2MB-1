// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "../render/post/SvgMusicGlyphs.sol";

/**
 * @title AbcToSvg
 * @notice Simplified ABC notation to SVG converter for Solidity
 * @dev Handles basic note placement from MusicLib output
 */
library AbcToSvg {
    using Strings for uint256;

    // Staff geometry constants
    uint16 constant CANVAS_WIDTH = 600;
    uint16 constant CANVAS_HEIGHT = 600;
    uint16 constant STAFF_SPACE = 40;
    uint16 constant TREBLE_TOP = 80;
    uint16 constant BASS_TOP = 320;
    uint16 constant NOTE_X = 350;

    // Simplified pitch to step mapping (treble clef)
    // Using MIDI note numbers for simplicity: C4=60 (middle C)
    function treblePitchToStep(int16 midiNote) internal pure returns (int16) {
        // Map MIDI notes to staff step positions
        // Step 0 = top line (F5=77), increases downward
        if (midiNote >= 77) return 0;  // F5+ on top line or above
        if (midiNote >= 76) return 1;  // E5 in top space
        if (midiNote >= 74) return 2;  // D5 on 2nd line
        if (midiNote >= 72) return 3;  // C5 in 2nd space
        if (midiNote >= 71) return 4;  // B4 on middle line
        if (midiNote >= 69) return 5;  // A4 in 3rd space
        if (midiNote >= 67) return 6;  // G4 on 4th line
        if (midiNote >= 65) return 7;  // F4 in bottom space
        if (midiNote >= 64) return 8;  // E4 on bottom line
        if (midiNote >= 62) return 9;  // D4 below staff
        if (midiNote >= 60) return 10; // C4 (middle C) on ledger line
        return 11; // Lower notes
    }

    // Simplified pitch to step mapping (bass clef)
    function bassPitchToStep(int16 midiNote) internal pure returns (int16) {
        // Bass clef: A2=45 on top line (step 0)
        if (midiNote >= 57) return 0;  // A3+ on top line or above
        if (midiNote >= 55) return 1;  // G3 in top space
        if (midiNote >= 53) return 2;  // F3 on 2nd line
        if (midiNote >= 52) return 3;  // E3 in 2nd space
        if (midiNote >= 50) return 4;  // D3 on middle line
        if (midiNote >= 48) return 5;  // C3 in 3rd space
        if (midiNote >= 47) return 6;  // B2 on 4th line
        if (midiNote >= 45) return 7;  // A2 in bottom space
        if (midiNote >= 43) return 8;  // G2 on bottom line
        if (midiNote >= 41) return 9;  // F2 below staff
        return 10; // Lower notes
    }

    // Convert step to Y coordinate
    function yForStep(bool isTreble, int16 step) internal pure returns (uint16) {
        uint16 base = isTreble ? TREBLE_TOP : BASS_TOP;
        return base + uint16(int16(STAFF_SPACE) * step / 2);
    }

    // Determine stem direction (simple rule: step <= 4 gets down stems)
    function getStemDirection(int16 step) internal pure returns (bool) {
        return step <= 4; // true = down, false = up
    }

    // Generate a single note element
    function generateNoteElement(
        int16 pitch,
        uint16 duration, 
        bool isTreble,
        uint16 x,
        bool isRest
    ) internal pure returns (string memory) {
        if (isRest) {
            // Simple rest in middle of staff
            uint16 restY = yForStep(isTreble, 4);
            return string(abi.encodePacked(
                '<g fill="#fff" transform="translate(', uint256(x).toString(), ',', uint256(restY).toString(), ') scale(0.26)">',
                '<use href="#rest-quarter"/>',
                '</g>'
            ));
        }

        // Get staff position
        int16 step = isTreble ? treblePitchToStep(pitch) : bassPitchToStep(pitch);
        uint16 y = yForStep(isTreble, step);
        bool stemDown = getStemDirection(step);

        // Map duration to note type (simplified)
        string memory noteType;
        if (duration >= 1920) noteType = "whole";        // Whole note
        else if (duration >= 960) noteType = "half";     // Half note  
        else if (duration >= 480) noteType = "quarter";  // Quarter note
        else noteType = "eighth";                        // Eighth note

        // Build glyph ID
        string memory glyphId;
        if (keccak256(bytes(noteType)) == keccak256(bytes("whole"))) {
            glyphId = "whole";
        } else {
            glyphId = string(abi.encodePacked(
                noteType, stemDown ? "-down" : "-up"
            ));
        }

        // Generate ledger lines if needed
        string memory ledgerLines = "";
        if (step < 0) {
            // Above staff - add ledger line at step -2 if note is at -2 or higher
            if (step <= -2) {
                uint16 ledgerY = yForStep(isTreble, -2);
                ledgerLines = string(abi.encodePacked(
                    '<line x1="', uint256(x-30).toString(), '" y1="', uint256(ledgerY).toString(), 
                    '" x2="', uint256(x+30).toString(), '" y2="', uint256(ledgerY).toString(), 
                    '" stroke="#fff" stroke-width="2"/>'
                ));
            }
        } else if (step > 8) {
            // Below staff - add ledger line at step 10 if note is at 10 or lower  
            if (step >= 10) {
                uint16 ledgerY = yForStep(isTreble, 10);
                ledgerLines = string(abi.encodePacked(
                    '<line x1="', uint256(x-30).toString(), '" y1="', uint256(ledgerY).toString(),
                    '" x2="', uint256(x+30).toString(), '" y2="', uint256(ledgerY).toString(),
                    '" stroke="#fff" stroke-width="2"/>'
                ));
            }
        }

        return string(abi.encodePacked(
            ledgerLines,
            '<g fill="#fff" transform="translate(', uint256(x).toString(), ',', uint256(y).toString(), ') scale(0.26)">',
            '<use href="#', glyphId, '"/>',
            '</g>'
        ));
    }

    // Generate complete SVG from MusicLib events
    function generateBeatSvg(
        int16 leadPitch,
        uint16 leadDur, 
        int16 bassPitch,
        uint16 bassDur,
        uint32 seed,
        uint32 beats
    ) internal pure returns (string memory) {
        // SVG header with defs
        string memory header = string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" ',
            'viewBox="0 0 ', uint256(CANVAS_WIDTH).toString(), ' ', uint256(CANVAS_HEIGHT).toString(), 
            '" width="', uint256(CANVAS_WIDTH).toString(), '" height="', uint256(CANVAS_HEIGHT).toString(), '">',
            '<defs>', SvgMusicGlyphs.defsMinimal(), '</defs>',
            '<rect width="100%" height="100%" fill="#fff"/>'
        ));

        // Staff lines
        string memory staff = string(abi.encodePacked(
            '<g stroke="#000" stroke-width="2">',
                // Treble staff
                '<line x1="40" y1="80" x2="500" y2="80"/>',
                '<line x1="40" y1="100" x2="500" y2="100"/>',
                '<line x1="40" y1="120" x2="500" y2="120"/>',
                '<line x1="40" y1="140" x2="500" y2="140"/>',
                '<line x1="40" y1="160" x2="500" y2="160"/>',
                // Bass staff  
                '<line x1="40" y1="320" x2="500" y2="320"/>',
                '<line x1="40" y1="340" x2="500" y2="340"/>',
                '<line x1="40" y1="360" x2="500" y2="360"/>',
                '<line x1="40" y1="380" x2="500" y2="380"/>',
                '<line x1="40" y1="400" x2="500" y2="400"/>',
            '</g>'
        ));

        // Clefs
        string memory clefs = string(abi.encodePacked(
            '<g fill="#000">',
                '<g transform="translate(48,38) scale(0.28)"><use href="#treble"/></g>',
                '<g transform="translate(48,296) scale(0.9)"><use href="#bass"/></g>',
            '</g>'
        ));

        // Generate notes
        string memory leadNote = generateNoteElement(
            leadPitch, leadDur, true, NOTE_X, leadPitch == -1
        );
        string memory bassNote = generateNoteElement(
            bassPitch, bassDur, false, NOTE_X, bassPitch == -1
        );

        // Debug info
        string memory debugInfo = string(abi.encodePacked(
            '<g fill="#000" font-family="monospace" font-size="10" opacity="0.8">',
            '<text x="40" y="580">seed=', uint256(seed).toString(), ' beats=', uint256(beats).toString(), '</text>',
            '</g>'
        ));

        return string(abi.encodePacked(
            header, staff, clefs, leadNote, bassNote, debugInfo, '</svg>'
        ));
    }
}
