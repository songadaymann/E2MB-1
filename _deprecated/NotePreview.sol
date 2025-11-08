// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/utils/Strings.sol";
import "openzeppelin-contracts/contracts/utils/Base64.sol";
import {SvgMusicGlyphs} from "../render/post/SvgMusicGlyphs.sol";
import {SongAlgorithm} from "../core/SongAlgorithm.sol";

/// @title NotePreview
/// @notice Test/preview-only renderer to visualize post-reveal music using SongAlgorithm.
///         Produces a compact grand-staff SVG with a small sequence of beats for a given seed.
///         This DOES NOT affect the main tokenURI; it is for local testing and iteration only.
contract NotePreview {
    using Strings for uint256;

    // Mirror key duration thresholds from MusicLib (keep in sync if updated).
    uint16 private constant QUARTER = 480;
    uint16 private constant DOTTED_QUART = 720;
    uint16 private constant HALF_NOTE = 960;
    uint16 private constant WHOLE = 1920;

    struct BeatCfg {
        uint32 seed;
        uint32 startBeat; // inclusive
        uint32 count;     // number of beats to render
    }

    // --- Public preview helpers ---

    function previewSVG(uint32 seed, uint32 beats) external pure returns (string memory svg) {
        BeatCfg memory cfg = BeatCfg({seed: seed, startBeat: 0, count: beats});
        svg = _renderPreview(cfg);
    }

    function previewSVGDataURI(uint32 seed, uint32 beats) external pure returns (string memory uri) {
        BeatCfg memory cfg = BeatCfg({seed: seed, startBeat: 0, count: beats});
        string memory svg = _renderPreview(cfg);
        uri = string(abi.encodePacked("data:image/svg+xml;base64,", Base64.encode(bytes(svg))));
    }

    function previewABC(uint32 beat, uint32 seed) external pure returns (string memory abc) {
        abc = SongAlgorithm.generateAbcBeat(beat, seed);
    }

    // --- Internal rendering ---

    function _renderPreview(BeatCfg memory cfg) internal pure returns (string memory) {
        // Theme - match Python script (white background, black lines/notes)
        string memory bg = "#fff";
        string memory fg = "#000";

        string memory head = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 600 600" width="600" height="600">',
                '<defs>', SvgMusicGlyphs.defsMinimal(), '</defs>',
                '<rect width="100%" height="100%" fill="', bg, '"/>'
            )
        );

        // Staff lines
        string memory staff = string(
            abi.encodePacked(
                '<g stroke="', fg, '" stroke-width="2">',
                    // Treble staff (y: 40..80)
                    '<line x1="40" y1="40" x2="320" y2="40"/>',
                    '<line x1="40" y1="50" x2="320" y2="50"/>',
                    '<line x1="40" y1="60" x2="320" y2="60"/>',
                    '<line x1="40" y1="70" x2="320" y2="70"/>',
                    '<line x1="40" y1="80" x2="320" y2="80"/>',
                    // Bass staff (y: 130..170)
                    '<line x1="40" y1="130" x2="320" y2="130"/>',
                    '<line x1="40" y1="140" x2="320" y2="140"/>',
                    '<line x1="40" y1="150" x2="320" y2="150"/>',
                    '<line x1="40" y1="160" x2="320" y2="160"/>',
                    '<line x1="40" y1="170" x2="320" y2="170"/>',
                '</g>'
            )
        );

        // Clefs
        string memory clefs = string(
            abi.encodePacked(
                '<g fill="', fg, '">',
                    '<g transform="translate(48,38) scale(0.28)"><use href="#treble"/></g>',
                    '<g transform="translate(48,136) scale(0.9)"><use href="#bass"/></g>',
                '</g>'
            )
        );

        // Notes for a small sequence of beats
        uint256 xStart = 90; // left of first note
        uint256 dx = 24;     // advance per beat

        string memory notes;
        for (uint32 i = 0; i < cfg.count; i++) {
            uint32 beat = cfg.startBeat + i;
            (SongAlgorithm.Event memory L, SongAlgorithm.Event memory B) = SongAlgorithm.generateBeat(beat, cfg.seed);
            // treble voice (lead)
            notes = string(abi.encodePacked(
                notes,
                _emitGlyphForEvent(true, xStart + i*dx, L)
            ));
            // bass voice
            notes = string(abi.encodePacked(
                notes,
                _emitGlyphForEvent(false, xStart + i*dx, B)
            ));
        }

        // Title/footer
        string memory footer = string(
            abi.encodePacked(
                '<g fill="', fg, '" font-family="monospace" font-size="10" opacity="0.8">',
                    '<text x="40" y="210">seed=', uint256(cfg.seed).toString(), ' beats=', uint256(cfg.count).toString(), '</text>',
                '</g>'
            )
        );

        return string(abi.encodePacked(head, staff, clefs, notes, footer, '</svg>'));
    }

    // Map SongAlgorithm.Event -> SVG glyph <use> with placement for treble/bass
    function _emitGlyphForEvent(bool treble, uint256 x, SongAlgorithm.Event memory ev) internal pure returns (string memory) {
        string memory fg = "#fff";
        // Choose glyph id by duration (approximate) and if rest
        if (ev.pitch < 0) {
            // rests: place near staff center
            uint256 y = treble ? 60 : 150;
            string memory restId = _restId(ev.duration);
            return string(
                abi.encodePacked(
                    '<g fill="', fg, '" transform="translate(', x.toString(), ',', y.toString(), ') scale(', _restScale(), ')">',
                        '<use href="#', restId, '"/>',
                    '</g>'
                )
            );
        } else {
            // notes: compute y from MIDI
            uint16 midi = uint16(uint256(int256(ev.pitch)));
            uint256 y = treble ? _yForMidiTreble(midi) : _yForMidiBass(midi);
            (string memory noteId, bool dotted) = _noteId(ev.duration);
            string memory g = string(
                abi.encodePacked(
                    '<g fill="', fg, '" transform="translate(', x.toString(), ',', y.toString(), ') scale(', _noteScale(), ')">',
                        '<use href="#', noteId, '"/>',
                    '</g>'
                )
            );
            if (dotted) {
                // add dot to the right of notehead
                string memory dot = string(
                    abi.encodePacked(
                        '<g fill="', fg, '" transform="translate(', (x+10).toString(), ',', (y-4).toString(), ') scale(0.2)">',
                            '<use href="#dot"/>',
                        '</g>'
                    )
                );
                g = string(abi.encodePacked(g, dot));
            }
            return g;
        }
    }

    function _noteId(uint16 dur) private pure returns (string memory id, bool dotted) {
        if (dur >= WHOLE) return ("half", false); // fallback (no whole glyph head with stem here)
        if (dur >= HALF_NOTE) return ("half", false);
        if (dur >= DOTTED_QUART) return ("quarter", true);
        if (dur >= QUARTER) return ("quarter", false);
        // eighth and shorter
        return ("eighth", false);
    }

    function _restId(uint16 dur) private pure returns (string memory id) {
        if (dur >= WHOLE) return "rest-whole";
        if (dur >= HALF_NOTE) return "rest-half";
        if (dur >= DOTTED_QUART) return "rest-quarter";
        if (dur >= QUARTER) return "rest-quarter";
        return "rest-eighth";
    }

    // Simple linear mapping from MIDI to SVG y-coord.
    // Calibrations:
    //  - Treble: E4 (64) at y=80 (bottom line), up 3px per semitone
    //  - Bass:   G2 (43) at y=170 (bottom line), up 3px per semitone
    function _yForMidiTreble(uint16 midi) private pure returns (uint256) {
        int256 dy = int256(uint256(midi)) - 64; // semitones above E4
        int256 y = 80 - (dy * 3);
        if (y < 20) y = 20; if (y > 110) y = 110;
        return uint256(y);
    }

    function _yForMidiBass(uint16 midi) private pure returns (uint256) {
        int256 dy = int256(uint256(midi)) - 43; // semitones above G2
        int256 y = 170 - (dy * 3);
        if (y < 110) y = 110; if (y > 210) y = 210;
        return uint256(y);
    }

    function _noteScale() private pure returns (string memory) {
        // Quarter glyph viewBox height ~83; target visual height ~22 -> ~0.26
        return "0.26";
    }

    function _restScale() private pure returns (string memory) {
        return "0.26";
    }
}
