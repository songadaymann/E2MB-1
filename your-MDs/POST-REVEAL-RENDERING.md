# Post-Reveal Music Rendering System

**Location**: `src/render/post/`  
**Purpose**: Complete on-chain SVG rendering of musical notation from MIDI pitch/duration data  
**Status**: Production-ready (Oct 2025)

---

## Architecture Overview

This directory contains a modular, calibrated system for rendering musical notation entirely on-chain. The system converts MIDI note data into pixel-perfect SVG staff notation.

### Component Stack (Bottom to Top)

```
MusicRenderer.sol (orchestrates everything)
    ├── StaffUtils.sol (grand staff geometry)
    ├── SvgMusicGlyphs.sol (symbol definitions)
    ├── MidiToStaff.sol (MIDI → staff position)
    └── NotePositioning.sol (symbol → SVG coordinates)
```

---

## File Descriptions

### 1. `MusicRenderer.sol` — Main Orchestrator

**What it does**: Complete post-reveal SVG renderer. Takes MIDI pitch/duration data and returns a 600×600 SVG with grand staff, notes, rests, dots, and metadata.

**Key function**:
```solidity
function render(BeatData memory data) internal pure returns (string memory)
```

**Input struct**:
```solidity
struct BeatData {
    uint256 tokenId;
    uint256 beat;
    uint256 year;
    int16 leadPitch;      // MIDI pitch, -1 for rest
    uint16 leadDuration;  // Duration in ticks
    int16 bassPitch;      // MIDI pitch, -1 for rest
    uint16 bassDuration;  // Duration in ticks
}
```

**Hardcoded styling**:
- Canvas: 600×600px
- Background: `#fff` (white)
- Foreground: `#000` (black)
- Note center X: 300px

**How it works**:
1. Generates grand staff (treble + bass + clefs)
2. For each voice (lead, bass):
   - Converts MIDI → staff position via `MidiToStaff`
   - Positions note/rest via `NotePositioning`
   - Adds dot if duration is dotted (720, 360, 1440, 180)
3. Renders metadata text overlays

**Critical alignment values**:
- Rest X offset: `noteX + 38` (aligns with note heads)
- Dot X offset: `96px` (38px spacing + 58px positioning compensation)

---

### 2. `NotePositioning.sol` — Symbol Positioning Library

**What it does**: Converts target staff coordinates into SVG `x/y/width/height` attributes for rendering notes, rests, and dots.

**Why it's complex**: Musical note glyphs have their head center at different positions within the viewBox depending on stem direction. This library encapsulates all calibrated offsets.

**Key functions**:
```solidity
getUpNotePosition(noteX, noteY, noteType) → PositionResult
getDownNotePosition(noteX, noteY, noteType) → PositionResult
getWholeNotePosition(noteX, noteY) → PositionResult
getRestPosition(restX, restY, restType) → PositionResult
getDotPosition(noteX, noteY, noteOnLine) → PositionResult
```

**PositionResult struct**:
```solidity
struct PositionResult {
    int256 offsetX;   // SVG x coordinate
    int256 offsetY;   // SVG y coordinate
    uint256 width;    // Display width
    uint256 height;   // Display height
}
```

**Calibrated constants**:
- **Note size**: 60px
- **Note scale**: 2.5× (150px display height for stemmed notes)
- **Whole note scale**: 0.675× (40.5px display height)
- **Rest scales**: 
  - Quarter/Eighth: 2.0×
  - Half/Whole: 0.35×

**Critical positioning formulas**:

**Up-stemmed notes**:
```solidity
offsetX = noteX - (headCenterX × scaleFactor / 10000) + 20
offsetY = noteY - (headCenterY × scaleFactor / 10000) - 130
```

**Down-stemmed notes**:
```solidity
offsetX = noteX - (headCenterX × scaleFactor / 10000) + 20
offsetY = noteY - (headCenterY × scaleFactor / 10000) - 20  // Different Y!
```

**Dots**:
```solidity
dotX = noteX + 96  // 38px spacing + 58px positioning compensation
dotY = noteOnLine ? noteY - 20 : noteY  // Space above if on line
```

**Head center lookup tables**: Each note type has calibrated (x, y) coordinates in viewBox space (×100 for precision). See internal functions `_getUpNoteHeadCenter`, `_getDownNoteHeadCenter`.

---

### 3. `MidiToStaff.sol` — MIDI to Staff Converter

**What it does**: Converts MIDI note number + duration → staff clef, staff step, note type, and line/space flag.

**Key function**:
```solidity
function midiToStaffPosition(uint8 midiNote, uint16 duration) 
    → StaffPosition
```

**Output struct**:
```solidity
struct StaffPosition {
    Clef clef;           // TREBLE or BASS
    uint8 staffStep;     // 0=top line, 2/4/6/8=lines, 1/3/5/7=spaces
    NoteType noteType;   // QUARTER_UP, HALF_DOWN, REST, etc.
    bool onLine;         // true if on a staff line
}
```

**Clef assignment**:
- MIDI ≥ 55 (G3 and above) → Treble clef
- MIDI ≤ 54 (F#3 and below) → Bass clef

**Staff step calculation** (diatonic):
- Treble: C4 is step 10 (reference)
- Bass: C4 is step -2 (below staff)
- Formula: `staffStep = referenceStep + diatonicSteps`

**Stem direction logic**:
- Steps 0-4 (top half): down stems
- Steps 5+ (bottom half): up stems

**Duration mapping**:
- 1920 → Whole
- 960 → Half
- 480 → Quarter
- 240 → Eighth
- 120 → Sixteenth

**Octave handling**:
- **Treble**: Raw MIDI values (48-70 = C3-Bb4)
- **Bass**: +12 shift for visual clarity (24-46 displayed as C2-Bb3)

---

### 4. `StaffUtils.sol` — Grand Staff Geometry

**What it does**: Provides standardized staff geometry and generates SVG markup for grand staff (treble + bass with clefs).

**Key function**:
```solidity
function largeGeometry() → StaffGeometry
```

**Geometry struct**:
```solidity
struct StaffGeometry {
    uint16 canvasWidth;   // 600
    uint16 canvasHeight;  // 600
    uint16 staffLeft;     // 100
    uint16 staffRight;    // 500
    uint16 staffSpace;    // 40 (line spacing)
    uint16 trebleTop;     // 80 (top line of treble staff)
    uint16 bassTop;       // 320 (top line of bass staff)
}
```

**Staff line Y coordinates**:
- **Treble**: 80, 120, 160, 200, 240 (5 lines, 40px apart)
- **Bass**: 320, 360, 400, 440, 480 (5 lines, 40px apart)

**Staff step to Y mapping**:
```solidity
Y = staffTop + (step × 20)  // 20px per half-space
```

**Generation functions**:
```solidity
generateStaffLines(geom, color) → SVG string
generateClefs(geom, color) → SVG string
generateGrandStaff(geom, strokeColor, fillColor) → SVG string
```

**Clef positioning** (calibrated):
- **Treble**: `translate(-128, -75) scale(0.52)`, viewBox expanded to `0 0 250 320`
- **Bass**: `translate(127, 320) scale(0.23)`, viewBox `0 0 42.42 41.3`

---

### 5. `SvgMusicGlyphs.sol` — Symbol Definitions

**What it does**: Contains all musical symbol definitions as SVG `<symbol>` elements.

**Key function**:
```solidity
function defsMinimal() → string  // Returns all symbols (no <defs> wrapper)
```

**Symbol inventory**:
- **Notes**: `quarter-up`, `quarter-down`, `half-up`, `half-down`, `eighth-up`, `eighth-down`, `sixteenth-up`, `sixteenth-down`, `whole`
- **Rests**: `rest-quarter`, `rest-eighth`, `rest-half`, `rest-whole`
- **Clefs**: `treble`, `bass`
- **Dot**: `dot`

**All symbols use**: `fill="currentColor"` for easy color control.

**ViewBox sizes** (calibrated to match Python reference):
- Stemmed notes: ~27-53 × 83-84 units
- Whole note: 33.34 × 24.03
- Treble clef: 250 × 320 (expanded for detail)
- Bass clef: 42.42 × 41.3
- Dot: 7.62 × 7.62

---

## Usage Guide

### Basic Rendering

```solidity
import "./MusicRenderer.sol";

MusicRenderer.BeatData memory data = MusicRenderer.BeatData({
    tokenId: 1,
    beat: 0,
    year: 2026,
    leadPitch: 67,        // G4
    leadDuration: 720,    // Dotted quarter
    bassPitch: 36,        // C2
    bassDuration: 960     // Half note
});

string memory svg = MusicRenderer.render(data);
```

### Coordinate System

**Staff coordinate origin**: Top-left of canvas (0, 0)

**Note positioning inputs**: Pass **target staff position** (where you want the note head center):
```solidity
uint256 targetX = 300;  // Center of staff
uint256 targetY = 160;  // Middle line of treble staff
```

**The positioning library handles all offsets internally** — you never calculate SVG x/y directly.

---

## Testing & Calibration History

### Test Scripts

**Primary test script**: `script/dev/TestMusicRendererFromJson.s.sol`
- Reads JSON data from external MIDI output
- Generates 10 SVG files for visual verification
- Run with: `forge script script/dev/TestMusicRendererFromJson.s.sol --ffi -vv`

**Component test scripts** (in `script/archive/`):
- `TestSingleNote.s.sol` — Single note placement tester
- `TestQuarterRest.s.sol` — Rest rendering validation
- `TestStaffOnly.s.sol` — Staff + clef positioning
- `TestNotePositioningLib.s.sol` — Unit test for positioning formulas

### Key Calibration Values Discovered

**October 2025 calibration sessions**:

1. **Note head positioning** (see progress.md §24):
   - Up-stemmed: Y offset -130 (head near bottom of glyph)
   - Down-stemmed: Y offset -20 (head near top of glyph)
   - Whole: Y offset -20 (centered)

2. **Dot positioning** (§35.5-35.9):
   - Initial attempt: 38px right (too close)
   - Final calibration: 96px right (38 + 58 compensation)
   - Vertical: +20px space above if note on line

3. **Rest alignment** (§35.9):
   - Rests use center-based positioning
   - Need +38px X offset to align with note heads
   - Positioned at staff center Y (staffTop + 80)

4. **Clef positioning** (§23.4-23.5):
   - Treble: Multiple iterations to eliminate "blob" effect
   - Final: Complex outline path from Python reference
   - Bass: Scale reduced from 0.9 → 0.23

---

## Design Decisions

### Why separate positioning from rendering?

**NotePositioning** encapsulates all the messy math (viewBox scaling, head center offsets, aspect ratios) while **MusicRenderer** handles the musical logic (stem direction, dotted notes, rests).

### Why hardcoded styling in MusicRenderer?

These are the **on-chain canonical colors** — no parameters needed since the blockchain output is immutable and must be consistent.

### Why +38 for rests but +96 for dots?

- **Rests** use simple center-based positioning (just need to shift to note head X)
- **Dots** are positioned *relative to note head center*, but note positioning adds complex offsets, so dots need the full 96px (38 musical spacing + 58 positioning compensation)

### Why different Y offsets for up vs down stems?

The note head is at different positions within the glyph:
- **Up-stemmed**: Head near bottom (y ~68 in viewBox) → large negative Y offset (-130)
- **Down-stemmed**: Head near top (y ~15 in viewBox) → small negative Y offset (-20)

---

## Integration with Core System

**Called by**: `src/core/MillenniumSong.sol` → `tokenURI()` function

**Input data source**: `SongAlgorithm.generateBeat(beat, tokenSeed)` provides MIDI pitch/duration

**Output**: Complete SVG embedded in `data:image/svg+xml;base64,<base64>` URI

**Gas considerations**: 
- All functions are `pure` or `view` (no storage writes)
- Target: ≤150k gas for `tokenURI()` call
- Heavy use of string concatenation — monitor gas in production

---

## Known Limitations & Future Work

### Current Limitations

1. **Ledger lines**: Not yet implemented for notes outside staff range
2. **Rest types**: All rests use `rest-quarter` symbol regardless of duration
3. **Accidentals**: Not needed (Eb major diatonic scale only)
4. **Multiple notes per staff**: System renders one note per voice

### Future Enhancements (v1.1+)

- [ ] Add ledger lines for out-of-range notes
- [ ] Duration-aware rest symbols (eighth, half, whole)
- [ ] Optional seasonal color palettes (time-based themes)
- [ ] Beam rendering for eighth/sixteenth note groups
- [ ] Staff position optimization (reduce gas further)

---

## Troubleshooting

### "Dots in wrong position"

Check that you're passing the **staff target position** to `getDotPosition`, not the rendered SVG offset. The positioning library handles all transformations internally.

### "Rests offset to the left"

Ensure `noteX + 38` is passed to `getRestPosition` (see MusicRenderer lines 104, 170).

### "Notes look blurry or misaligned"

Check that `NotePositioning` constants haven't been modified:
- `NOTE_SIZE = 60`
- `NOTE_SCALE = 2500` (for 2.5× scaling)

### "Treble clef looks like a blob"

The complex outline path in `SvgMusicGlyphs.sol` must be preserved exactly as copied from Python reference (§23.5).

---

## Reference Materials

**Python comparison script**: `python-scripts/original-scripts/abc_to_svg.py`  
Used for initial calibration — Solidity output must match Python pixel-for-pixel.

**JSON test data**: External MIDI output from `NewContracts-modular-in-HARDHAT/outputs/*/combined-midi-info.json`

**Progress log**: See `../../progress.md` sections 22-35 for complete calibration history.

---

## For AI Assistants

**When modifying this system**:

1. ✅ **DO**: Run `TestMusicRendererFromJson.s.sol` after any changes
2. ✅ **DO**: Check visual output in generated SVG files (open in browser)
3. ✅ **DO**: Preserve calibrated constants (they were hard-won!)
4. ❌ **DON'T**: Change positioning formulas without visual verification
5. ❌ **DON'T**: Remove or modify symbol viewBox dimensions
6. ❌ **DON'T**: Assume "center-based" positioning for notes (it's offset-based!)

**Critical values to never change** (unless you're recalibrating everything):
- Dot X: 96px
- Rest X: +38px  
- Up note Y offset: -130
- Down note Y offset: -20
- Staff geometry (StaffUtils.largeGeometry)

**If something looks wrong**:
1. Check the generated SVG visually (don't just trust coordinates)
2. Compare against JSON test data MIDI values
3. Verify `MidiToStaff` is assigning correct clef/stem direction
4. Confirm `onLine` flag is correct (affects dot position)

---

*Last updated: October 5, 2025*  
*Status: Production-ready with dots, rests, and all note types calibrated*
