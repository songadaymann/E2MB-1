// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {NotePreview} from "../src/render/post/NotePreview.sol";

contract NotePreviewTest is Test {
    NotePreview preview;

    function setUp() public {
        preview = new NotePreview();
    }

    function test_preview_svg_log() public {
        // Render 8 beats for a sample seed
        string memory svg = preview.previewSVG(12345, 8);
        emit log_string(svg);
    }

    // Extra SVG preview cases for dumping to files
    function test_preview_svg_seed_1_8() public {
        emit log_string(preview.previewSVG(1, 8));
    }

    function test_preview_svg_seed_42_16() public {
        emit log_string(preview.previewSVG(42, 16));
    }

    function test_preview_svg_seed_999_12() public {
        emit log_string(preview.previewSVG(999, 12));
    }

    // ABC previews for a few beats
    function test_preview_abc_seed_12345_beat_0() public {
        emit log_string(preview.previewABC(0, 12345));
    }

    function test_preview_abc_seed_12345_beat_1() public {
        emit log_string(preview.previewABC(1, 12345));
    }

    function test_preview_abc_seed_12345_beat_2() public {
        emit log_string(preview.previewABC(2, 12345));
    }

    function test_preview_abc_seed_12345_beat_3() public {
        emit log_string(preview.previewABC(3, 12345));
    }
}
