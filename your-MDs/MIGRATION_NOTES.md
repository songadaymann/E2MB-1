# MusicLib → SongAlgorithm Migration

**Date:** October 2, 2025  
**Status:** ✅ Complete

## Summary

Successfully migrated from `MusicLib.sol` to `SongAlgorithm.sol` (imported from MusicLibV3).

## Changes Made

### 1. Library Replacement
- **Old:** `/src/core/MusicLib.sol` (C major, tonnetz harmony, 3-tone bass)
- **New:** `/src/core/SongAlgorithm.sol` (Eb major, diatonic harmony, 8-tone bass)
- **Deprecated:** Old MusicLib moved to `/src/deprecated/MusicLib.sol` for reference

### 2. Key Improvements in SongAlgorithm

#### Musical Features:
- **Key signature:** Eb major (vs C major)
- **Harmony system:** Diatonic (I, ii, iii, IV, V, vi, vii°) vs neo-Riemannian tonnetz
- **Bass implementation:** 8 chord tones with 75% repetition logic + prescribed duration pattern
- **Structural features:** 50-beat resets to tonic, 365-beat cycle system ("eras")
- **Lead rhythm:** Oracle-approved improvements (50% quarters, 33% eighths, 17% dotted in phrase A)
- **Chord tone selection:** Improved position-specific logic to avoid repetition

#### Technical Features:
- **State management:** `BassState` includes `previousPitch` for repetition tracking
- **ABC notation:** Proper Eb major with flats (`_D`, `_E`, `_A`, `_B`)
- **Metadata:** Era and day display in ABC title

### 3. Files Updated

#### Core Contracts (4 files):
- `/src/core/SongAlgorithm.sol` - New library (renamed from MusicLibV3)
- `/src/core/MillenniumSong.sol` - Updated imports and references
- `/src/render/post/NotePreview.sol` - Updated imports and references
- `/src/deprecated/MusicLib.sol` - Old version for reference

#### Tests (2 files):
- `/test/AbcToSvg.t.sol` - Updated to use SongAlgorithm
- `/test/MusicPipelineIntegration.t.sol` - Updated to use SongAlgorithm

#### Documentation (3 files):
- `agent.md` - All MusicLib references → SongAlgorithm
- `REPO_STRUCTURE.md` - Updated library name and description
- `README.md` - Updated references

#### Archive Scripts (28 files):
- All scripts in `/script/archive/` updated for compatibility

## API Compatibility

The public API remains identical:

```solidity
// Event structure (unchanged)
struct Event {
    int16 pitch;      // MIDI pitch, -1 for rest
    uint16 duration;  // ticks (e.g., 480 = quarter)
}

// Public functions (unchanged signatures)
function generateBeat(uint32 beat, uint32 tokenSeed) 
    external pure returns (Event memory lead, Event memory bass)

function generateAbcBeat(uint32 beat, uint32 tokenSeed)
    external pure returns (string memory abc)
```

## Build Status

✅ **Build:** Successful (with warnings from archived scripts)  
✅ **Tests:** 22 passing, 8 failing (same as before migration - these are from in-progress staff positioning work)

## Migration Command Reference

```bash
# Old usage
import "./MusicLib.sol";
MusicLib.generateBeat(beat, seed);
MusicLib.Event memory ev;

# New usage  
import "./SongAlgorithm.sol";
SongAlgorithm.generateBeat(beat, seed);
SongAlgorithm.Event memory ev;
```

## Known Issues / Notes

1. **Test failures:** 8 tests failing related to MidiToStaff positioning (pre-existing, not caused by migration)
2. **Eb major key:** All generated music is now in Eb major with proper flat notation
3. **365-beat cycles:** Music now resets every 365 beats for "era" system
4. **Bass behavior:** Significantly different from old version due to 8-tone system and repetition logic

## Next Steps

1. Continue with staff positioning work using new SongAlgorithm output
2. Verify MIDI mappings work correctly with Eb major notes
3. Test ABC notation rendering with flat symbols
4. Generate sample beats to compare old vs new musical output

## Rollback Plan

If needed, the old MusicLib can be restored from `/src/deprecated/MusicLib.sol`:

```bash
cp src/deprecated/MusicLib.sol src/core/
# Then update all references from SongAlgorithm back to MusicLib
```

## References

- **Original source:** `/Users/jonathanmann/SongADAO Dropbox/Jonathan Mann/projects/THE-LONG-SONG/1000yearsong/contracts/contracts/MusicLibV3.sol`
- **Deprecated backup:** `/src/deprecated/MusicLib.sol`
- **Migration PR:** (TBD if using git)
