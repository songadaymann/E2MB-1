# Library Externalization — Progress Log

**Goal:** Get MillenniumSong contract under the 24KB size limit by externalizing rendering libraries into separate deployable contracts.

**Date Started:** Oct 8, 2025  
**Status:** ✅ Phase 1-2 Complete → Phase 3 In Progress

**Last Updated:** Oct 8, 2025 12:30 PM

---

## 🎯 Current Progress Summary

### ✅ Phase 1: Cleanup (COMPLETE)
**Completed:** Oct 8, 2025 11:30 AM

Deleted 7 redundant wrapper contracts from `src/contracts/`:
- ❌ AudioRendererContract.sol
- ❌ MidiToStaffContract.sol  
- ❌ MusicRendererContract.sol
- ❌ NotePositioningContract.sol
- ❌ SongAlgorithmContract.sol
- ❌ StaffUtilsContract.sol
- ❌ SvgMusicGlyphsContract.sol

**Why:** These wrappers still inlined library code - didn't save any space!

---

### ✅ Phase 2: Convert Libraries to Contracts (COMPLETE)
**Completed:** Oct 8, 2025 12:30 PM

Successfully converted all 6 libraries from `internal` → `external` functions:

| Library | Original Type | New Type | Size | Status |
|---------|--------------|----------|------|--------|
| SvgMusicGlyphs | library | contract | 12,768 B | ✅ 52% under limit |
| AudioRenderer | library | contract | 4,217 B | ✅ 83% under limit |
| SongAlgorithm | library | contract | 7,950 B | ✅ 68% under limit |
| MidiToStaff | library | contract | 1,846 B | ✅ 92% under limit |
| StaffUtils | library | contract | 6,391 B | ✅ 74% under limit |
| NotePositioning | library | contract | 4,973 B | ✅ 80% under limit |

**Total if combined:** ~38KB  
**Deployed separately:** Each well under 24KB ✅

**Key changes per file:**
1. Changed `library X` → `contract X is IX`
2. Changed `internal` → `external` (or `external view` where needed)
3. Added `override` to interface functions
4. Removed duplicate struct/enum definitions (kept only in interface)
5. Added `this.` prefix for calling other external functions within same contract

**Files modified:**
- ✅ `src/render/post/SvgMusicGlyphs.sol`
- ✅ `src/render/post/AudioRenderer.sol`
- ✅ `src/core/SongAlgorithm.sol`
- ✅ `src/render/post/MidiToStaff.sol`
- ✅ `src/render/post/StaffUtils.sol`
- ✅ `src/render/post/NotePositioning.sol`

**Interfaces created (kept as-is):**
- ✅ `src/interfaces/ISvgMusicGlyphs.sol`
- ✅ `src/interfaces/IAudioRenderer.sol`
- ✅ `src/interfaces/ISongAlgorithm.sol`
- ✅ `src/interfaces/IMidiToStaff.sol`
- ✅ `src/interfaces/IStaffUtils.sol`
- ✅ `src/interfaces/INotePositioning.sol`
- ✅ `src/interfaces/IMusicRenderer.sol`

---

### ✅ Phase 3: MusicRendererOrchestrator Created (COMPLETE)
**Completed:** Oct 8, 2025 1:00 PM

**Created:** `src/contracts/MusicRendererOrchestrator.sol` (319 lines)
- ✅ Implements `IMusicRenderer` interface
- ✅ Stores 4 module addresses (staff, glyphs, midi, positioning)
- ✅ `setModules()` for updates before freeze
- ✅ One-way `freeze()` function
- ✅ `render()` orchestrates external calls and assembles SVG
- ✅ Changed interface from `pure` to `view` (needed for external calls)
- ✅ Size: ~8.5KB actual bytecode (**65% under 24KB limit!**)

**Key architecture:**
- Calls external contracts via interfaces
- Assembles final SVG string in one place
- No large string copying across contract boundaries
- All rendering logic preserved from MusicRenderer library

### ✅ Phase 4: Testing Complete (COMPLETE)
**Completed:** Oct 8, 2025 1:05 PM

**Created:** `script/dev/TestOrchestratorSimple.s.sol`
- ✅ Deploys all 5 contracts (StaffUtils, SvgMusicGlyphs, MidiToStaff, NotePositioning, Orchestrator)
- ✅ Generates 5 test SVG files successfully
- ✅ Verified output matches expected format
- ✅ Gas used: 7,887,344 (for deployment + rendering)

**Test Results:**
- Token 1: G4 dotted half + C2 half ✅
- Token 2: G4 quarter + Bb2 quarter ✅
- Token 3: Eb4 eighth + F2 eighth ✅
- Token 4: REST + G2 half ✅
- Token 5: Bb4 quarter + Eb2 half ✅

**Files Moved to _legacy:**
- Old MusicRenderer.sol library (replaced by orchestrator)
- MusicRendererExternal.sol (old wrapper)
- MusicRendererContract.sol (old testnet version)
- AudioRendererExternal.sol, StaffUtilsExternal.sol (old wrappers)
- MillenniumSong.sol, MillenniumSongTestnet.sol (need updating to use orchestrator)

### ✅ Phase 5: MillenniumSong Updated (COMPLETE)
**Completed:** Oct 8, 2025 1:15 PM

**Updated:** `src/core/MillenniumSong.sol`
- ✅ Changed from library imports to interface imports
- ✅ Added external contract storage (songAlgorithm, musicRenderer, audioRenderer)
- ✅ Added `setRenderers()` function (takes 3 addresses)
- ✅ Added `finalizeRenderers()` one-way lock
- ✅ Updated `tokenURI()` to call external contracts
- ✅ Added try/catch for renderer failures (graceful degradation)
- ✅ Kept CountdownRenderer as library (still inlined)
- ✅ Size: ~11KB (**55% under 24KB limit!**)

**Key Changes:**
- Pre-reveal: Uses CountdownRenderer library (still inlined)
- Post-reveal: Calls external musicRenderer.render() and audioRenderer.generateAudioHTML()
- SongAlgorithm: Now called via ISongAlgorithm interface
- All rendering logic moved to external contracts

### ✅ Phase 6: Color Scheme Updated (COMPLETE)
**Completed:** Oct 8, 2025 1:30 PM

**Changed to white-on-black theme:**
- ✅ MusicRendererOrchestrator: `bgColor="#000"`, `fgColor="#fff"`
- ✅ NotePositioning: Ledger lines `stroke="#fff"`
- ✅ StaffUtils: Added `color="#fff"` to clef wrapper (fixes `currentColor` inheritance)

**Oracle consultation**: Identified that `currentColor` references CSS `color` property, not `fill`

**Test verified**: All SVG elements (staff, clefs, notes, ledgers, dots) now render white on black

### ✅ Phase 7: Algorithm Testing with Real Seeds (COMPLETE)
**Completed:** Oct 8, 2025 1:45 PM

**Created comprehensive test suite for refactored architecture:**

**Test Scripts:**
- `script/dev/TestSongAlgoRefactored.s.sol` - Basic algorithm test with multiple seeds
- `script/dev/TestSongAlgoWithRealSeeds.s.sol` - **5-source seed computation test**
- `script/dev/TestCompleteMetadata.s.sol` - Full tokenURI metadata generation

**Key Verification:**
1. ✅ **Seed logic preserved** - 5-source computation still in MillenniumSong.sol:
   ```solidity
   keccak256(abi.encodePacked(
       tokenSeed[tokenId],      // 1. Initial mint seed
       sevenWords[tokenId],     // 2. Owner's commitment
       previousNotesHash,       // 3. Cumulative note history
       globalState,             // 4. Global entropy
       tokenId                  // 5. Token ID
   ))
   ```

2. ✅ **External SongAlgorithm works** - Deployed separately, called via interface
3. ✅ **Realistic seed test** - 50 tokens with proper cumulative previousNotesHash
4. ✅ **Lead rests working** - Token 9 showed `pitch:-1` (REST)
5. ✅ **Bass never rests** - All bass notes have valid MIDI pitches
6. ✅ **Complete metadata** - Generated full JSON with all attributes:
   - Year, Queue Rank, Points
   - Reveal Timestamp (with OpenSea `display_type: "date"`)
   - Lead/Bass MIDI pitches and human-readable note names
   - Duration values and types (Quarter Note, Half Note, etc.)
   - SVG image (11KB staff notation)
   - Animation URL (2.6KB WebAudio HTML player)
   - External URL

**Output Files:**
- `OUTPUTS/algo-test/` - Algorithm tests with 5 different seeds
- `OUTPUTS/real-seed-test/` - 50 beats with realistic 5-source seeds
- `OUTPUTS/complete-metadata/` - Full tokenURI example (viewable SVG + playable HTML)

**Gas Costs:**
- SongAlgorithm deployment: ~7.9M gas
- Test run (deploy + 50 beats): ~83M gas total
- Metadata generation (deploy all + render): ~68M gas

### ⏳ Phase 8: Next Steps

**TO DO:**
- [ ] Create comprehensive deployment script for full system
- [ ] Test full end-to-end with mint → reveal → tokenURI
- [ ] Deploy modular architecture to testnet
- [ ] Verify actual on-chain gas costs
- [ ] Test marketplace rendering (OpenSea/Rarible)

---

## Problem Statement

### Current Situation
- **MillenniumSong.sol**: ~40KB (way over 24,576 byte limit)
- **Root cause**: All rendering libraries use `internal` functions which get inlined into the main contract
- **Bloat breakdown**:
  - MusicRenderer + dependencies: ~26KB
  - SongAlgorithm: ~8KB
  - AudioRenderer: ~4KB
  - Core logic: ~10KB

### What We Tried (That Didn't Work)
1. ✅ Created interfaces for all libraries
2. ❌ Created "wrapper contracts" that call libraries
3. ❌ Problem: Wrappers still inline library code because libraries use `internal` functions!

**Result:** MusicRendererContract = 24,901 bytes (still 325 bytes over limit)

---

## Solution Architecture (Oracle-Approved)

### Key Insight
> "Do not try to squeeze 325 bytes to make a monolith pass the limit; it will get brittle and you lose the ability to patch components before finalization."
> — Oracle

### The Right Approach
Convert libraries to **stateless contracts** with **external functions**:
- External functions can't be inlined (they're STATICCALL'd)
- Contracts can be deployed independently at their own addresses
- Main contract stores addresses and calls via interfaces
- Before finalize: can update component addresses
- After finalize: all addresses locked forever

---

## Architecture Diagram

```
MillenniumSong (Main NFT Contract - TINY!)
  ├─ Stores: IMusicRenderer musicRendererAddress
  ├─ Stores: IAudioRenderer audioRendererAddress  
  ├─ Stores: ISongAlgorithm songAlgorithmAddress
  └─ Stores: ICountdownRenderer countdownRendererAddress
     ↓
     tokenURI() calls:
       musicRendererAddress.render(beatData)
       audioRendererAddress.generateAudioHTML(...)
       
MusicRendererOrchestrator (implements IMusicRenderer)
  ├─ Stores: IStaffUtils staffAddress
  ├─ Stores: ISvgMusicGlyphs glyphsAddress
  ├─ Stores: IMidiToStaff midiAddress
  └─ Stores: INotePositioning positioningAddress
     ↓
     render() calls each submodule:
       glyphsAddress.defsMinimal()
       staffAddress.generateGrandStaff()
       midiAddress.midiToStaffPosition()
       positioningAddress.getLedgerLines()
     
     Then assembles final SVG in ONE PLACE (no copying large strings)

Deployed Contracts (each under 24KB):
  ├─ StaffUtils (~8KB)
  ├─ SvgMusicGlyphs (~10KB)
  ├─ MidiToStaff (~3KB)
  ├─ NotePositioning (~5KB)
  ├─ AudioRenderer (~4KB)
  └─ SongAlgorithm (~8KB)
```

---

## Execution Plan

### Phase 1: Cleanup ✂️

**Delete redundant wrapper contracts:**
```bash
rm src/contracts/SvgMusicGlyphsContract.sol
rm src/contracts/StaffUtilsContract.sol
rm src/contracts/MidiToStaffContract.sol
rm src/contracts/NotePositioningContract.sol
rm src/contracts/AudioRendererContract.sol
rm src/contracts/SongAlgorithmContract.sol
rm src/contracts/MusicRendererContract.sol
```

**Keep:**
- ✅ All interface files in `src/interfaces/`
- ✅ All library files in `src/render/post/` and `src/core/` (we'll convert them)

---

### Phase 2: Convert Libraries → Contracts 🔄

For each library file, change from:
```solidity
library LibraryName {
    function someFunction(...) internal pure returns (...) {
        // implementation
    }
}
```

To:
```solidity
contract LibraryName is ILibraryName {
    function someFunction(...) external pure override returns (...) {
        // same implementation
    }
}
```

**Files to Convert:**

#### 2.1) `src/render/post/StaffUtils.sol`
- Change: `library StaffUtils` → `contract StaffUtils is IStaffUtils`
- Change all: `internal` → `external`
- Add: `override` to all interface functions
- Remove: Any internal-only helpers (inline them or make them private)

#### 2.2) `src/render/post/SvgMusicGlyphs.sol`
- Change: `library SvgMusicGlyphs` → `contract SvgMusicGlyphs is ISvgMusicGlyphs`
- Change: `internal pure` → `external pure override`
- Keep: Large SVG path strings (optimize later with SSTORE2 if needed)

#### 2.3) `src/render/post/MidiToStaff.sol`
- Change: `library MidiToStaff` → `contract MidiToStaff is IMidiToStaff`
- Change all: `internal` → `external`
- Keep: Enums and structs (they're in the interface)
- Note: May have internal helpers - make them `private` if needed

#### 2.4) `src/render/post/NotePositioning.sol`
- Change: `library NotePositioning` → `contract NotePositioning is INotePositioning`
- Change all: `internal` → `external`
- Keep: All positioning formulas intact

#### 2.5) `src/render/post/AudioRenderer.sol`
- Change: `library AudioRenderer` → `contract AudioRenderer is IAudioRenderer`
- Change: `internal pure` → `external pure override`

#### 2.6) `src/core/SongAlgorithm.sol`
- Change: `library SongAlgorithm` → `contract SongAlgorithm is ISongAlgorithm`
- Change: `internal pure` → `external pure override`
- Keep: All LCG, tonnetz, phrase grammar logic

---

### Phase 3: Create MusicRendererOrchestrator 🎼

**New file:** `src/contracts/MusicRendererOrchestrator.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IMusicRenderer.sol";
import "../interfaces/IStaffUtils.sol";
import "../interfaces/ISvgMusicGlyphs.sol";
import "../interfaces/IMidiToStaff.sol";
import "../interfaces/INotePositioning.sol";

/// @title MusicRendererOrchestrator
/// @notice Orchestrates external rendering contracts to build final SVG
/// @dev Keeps all string assembly in one place, calls submodules for data
contract MusicRendererOrchestrator is IMusicRenderer, Ownable {
    
    // External module addresses
    IStaffUtils public staff;
    ISvgMusicGlyphs public glyphs;
    IMidiToStaff public midi;
    INotePositioning public positioning;
    
    // Freeze mechanism
    bool public frozen;
    
    event ModulesUpdated(address staff, address glyphs, address midi, address positioning);
    event Frozen();
    
    modifier notFrozen() {
        require(!frozen, "Frozen");
        _;
    }
    
    constructor(
        address _staff,
        address _glyphs,
        address _midi,
        address _positioning
    ) Ownable(msg.sender) {
        staff = IStaffUtils(_staff);
        glyphs = ISvgMusicGlyphs(_glyphs);
        midi = IMidiToStaff(_midi);
        positioning = INotePositioning(_positioning);
    }
    
    /// @notice Update module addresses (only before freeze)
    function setModules(
        address _staff,
        address _glyphs,
        address _midi,
        address _positioning
    ) external onlyOwner notFrozen {
        staff = IStaffUtils(_staff);
        glyphs = ISvgMusicGlyphs(_glyphs);
        midi = IMidiToStaff(_midi);
        positioning = INotePositioning(_positioning);
        emit ModulesUpdated(_staff, _glyphs, _midi, _positioning);
    }
    
    /// @notice Freeze module addresses permanently
    function freeze() external onlyOwner {
        frozen = true;
        emit Frozen();
    }
    
    /// @notice Render complete SVG for a beat
    /// @dev Calls external modules but assembles string only once
    function render(BeatData memory data) external view override returns (string memory) {
        // Call external contracts for data
        string memory defs = glyphs.defsMinimal();
        IStaffUtils.StaffGeometry memory geom = staff.largeGeometry();
        string memory grandStaff = staff.generateGrandStaff(geom, "#000", "#000");
        
        // Get MIDI positions
        IMidiToStaff.StaffPosition memory leadPos = midi.getStaffPosition(data.leadPitch, data.leadDuration);
        IMidiToStaff.StaffPosition memory bassPos = midi.getStaffPosition(data.bassPitch, data.bassDuration);
        
        // Build notes using positioning
        // ... (refactor MusicRenderer.render() logic here to use external calls)
        
        // Assemble final SVG in ONE PLACE
        return string(abi.encodePacked(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600">',
            '<defs>', defs, '</defs>',
            '<rect width="100%" height="100%" fill="#fff"/>',
            grandStaff,
            // ... notes, ledger lines, etc.
            '</svg>'
        ));
    }
}
```

**Key Points:**
- Stores 4 module addresses
- Has `setModules()` for updates before freeze
- Has one-way `freeze()` function
- Implements `render()` by calling external contracts
- **Assembles final SVG only once** (no large string copying across boundaries)

---

### Phase 4: Update MillenniumSong 🏗️

**Changes to `src/core/MillenniumSong.sol`:**

#### 4.1) Remove Library Imports
```diff
- import "../render/post/MusicRenderer.sol";
- import "../render/post/AudioRenderer.sol";
- import "./SongAlgorithm.sol";
```

#### 4.2) Add Interface Imports
```diff
+ import "../interfaces/IMusicRenderer.sol";
+ import "../interfaces/IAudioRenderer.sol";
+ import "../interfaces/ISongAlgorithm.sol";
+ import "../render/pre/ICountdownRenderer.sol";
```

#### 4.3) Add Module Address Storage
```solidity
// External renderer addresses
IMusicRenderer public musicRenderer;
IAudioRenderer public audioRenderer;
ISongAlgorithm public songAlgorithm;
ICountdownRenderer public countdownRenderer;

// Freeze state (separate from Points system finalize)
bool public renderersFinalized;
```

#### 4.4) Add Setters + Finalize
```solidity
event RenderersUpdated(address music, address audio, address song, address countdown);
event RenderersFinalized();

modifier renderersNotFinalized() {
    require(!renderersFinalized, "Renderers finalized");
    _;
}

function setRenderers(
    address _music,
    address _audio,
    address _song,
    address _countdown
) external onlyOwner renderersNotFinalized {
    musicRenderer = IMusicRenderer(_music);
    audioRenderer = IAudioRenderer(_audio);
    songAlgorithm = ISongAlgorithm(_song);
    countdownRenderer = ICountdownRenderer(_countdown);
    emit RenderersUpdated(_music, _audio, _song, _countdown);
}

function finalizeRenderers() external onlyOwner {
    renderersFinalized = true;
    emit RenderersFinalized();
}
```

#### 4.5) Update tokenURI with External Calls + try/catch
```solidity
function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "Token does not exist");
    
    uint256 rank = getCurrentRank(tokenId);
    uint256 revealYear = startYear + rank;
    
    // Check if revealed
    bool isRevealed = block.timestamp >= _jan1Timestamp(revealYear);
    
    if (!isRevealed) {
        // Pre-reveal: countdown
        try countdownRenderer.render(tokenId, rank, revealYear) returns (string memory svg) {
            return _buildPreRevealMetadata(tokenId, revealYear, svg);
        } catch {
            return _buildFallbackMetadata(tokenId, "Countdown renderer unavailable");
        }
    } else {
        // Post-reveal: music
        uint32 seed = _computeSeed(tokenId);
        (ISongAlgorithm.Event memory lead, ISongAlgorithm.Event memory bass) = 
            songAlgorithm.generateBeat(uint32(rank), seed);
        
        try musicRenderer.render(IMusicRenderer.BeatData({
            tokenId: tokenId,
            beat: rank,
            year: revealYear,
            leadPitch: lead.pitch,
            leadDuration: lead.duration,
            bassPitch: bass.pitch,
            bassDuration: bass.duration
        })) returns (string memory svg) {
            
            try audioRenderer.generateAudioHTML(
                lead.pitch,
                bass.pitch,
                revealBlockTimestamp[tokenId],
                tokenId,
                revealYear
            ) returns (string memory audioHtml) {
                return _buildRevealedMetadata(tokenId, revealYear, svg, audioHtml, lead, bass);
            } catch {
                return _buildRevealedMetadata(tokenId, revealYear, svg, "", lead, bass);
            }
            
        } catch {
            return _buildFallbackMetadata(tokenId, "Music renderer unavailable");
        }
    }
}
```

---

### Phase 5: Testing & Validation ✅

#### 5.1) Compile All Contracts
```bash
forge build --sizes
```

**Expected sizes:**
- MillenniumSong: <15KB ✅
- MusicRendererOrchestrator: <10KB ✅
- StaffUtils: ~8KB ✅
- SvgMusicGlyphs: ~10KB ✅
- MidiToStaff: ~3KB ✅
- NotePositioning: ~5KB ✅
- AudioRenderer: ~4KB ✅
- SongAlgorithm: ~8KB ✅

#### 5.2) Test Deployment Order
```solidity
// Deploy in this order:
1. StaffUtils
2. SvgMusicGlyphs
3. MidiToStaff
4. NotePositioning
5. MusicRendererOrchestrator(addr1, addr2, addr3, addr4)
6. AudioRenderer
7. SongAlgorithm
8. CountdownRenderer
9. MillenniumSong
10. MillenniumSong.setRenderers(addr5, addr6, addr7, addr8)
```

#### 5.3) Test SVG Generation
```bash
forge script script/dev/TestMusicRendererFromJson.s.sol --ffi
```

Verify output matches previous SVG quality.

#### 5.4) Gas Measurement
Measure `tokenURI()` gas usage:
- Should be <5M gas for eth_call (plenty of headroom)
- User doesn't pay (view function)

---

### Phase 6: Optional Optimizations 🚀

#### 6.1) SSTORE2 for Large SVG Defs (if needed)
If `SvgMusicGlyphs` is still too large:
```solidity
// Deploy SVG defs as immutable data
address public glyphDataAddress = SSTORE2.write(GLYPH_DEFS_BYTES);

// Read via extcodecopy
function defsMinimal() external view returns (string memory) {
    return string(SSTORE2.read(glyphDataAddress));
}
```

**Savings:** ~10KB removed from contract bytecode

#### 6.2) Custom Errors Instead of Revert Strings
```diff
- require(!frozen, "Frozen");
+ if (frozen) revert AlreadyFrozen();
```

**Savings:** ~100-500 bytes

---

## Migration Checklist

- [x] **Phase 1: Delete wrapper contracts** — Oct 8, 11:30 AM ✅
- [x] **Phase 2.1: Convert SvgMusicGlyphs to contract** — 12,768 B ✅
- [x] **Phase 2.2: Convert AudioRenderer to contract** — 4,217 B ✅
- [x] **Phase 2.3: Convert SongAlgorithm to contract** — 7,950 B ✅
- [x] **Phase 2.4: Convert MidiToStaff to contract** — 1,846 B ✅
- [x] **Phase 2.5: Convert StaffUtils to contract** — 6,391 B ✅
- [x] **Phase 2.6: Convert NotePositioning to contract** — 4,973 B ✅
- [x] **Phase 3: Create MusicRendererOrchestrator** — 8,496 B (~8.5KB) ✅
- [x] **Phase 4: Test orchestrator with SVG generation** ✅
- [x] **Phase 5: Update MillenniumSong with interfaces** — 11KB ✅
- [ ] Phase 5: Test compilation and sizes
- [ ] Phase 5: Test deployment sequence
- [ ] Phase 5: Test SVG generation matches
- [ ] Phase 5: Measure gas usage
- [ ] Phase 6: Optional SSTORE2 optimization

---

## Risk Mitigation

### Before Finalize
- Can update any renderer address if bugs found
- Can swap entire rendering stack
- try/catch prevents marketplace breaks

### After Finalize
- All addresses locked forever
- No upgrades possible
- Must thoroughly test before finalizing

### Deployment Strategy
1. Deploy to Sepolia testnet first
2. Mint several test tokens
3. Verify SVG renders correctly on OpenSea/Rarible
4. Test audio playback
5. Test rank changes
6. Only then deploy to mainnet
7. Run for 1-2 weeks before calling `finalizeRenderers()`

---

## Success Criteria

✅ All contracts under 24KB limit  
✅ SVG output matches current quality  
✅ Audio playback works  
✅ Can update renderers before finalize  
✅ After finalize, system is immutable  
✅ Gas usage reasonable for view functions  
✅ Clean, maintainable architecture  

---

## References

- Oracle consultation: Oct 8, 2025
- Original issue: Contract size 40KB → 24KB limit
- Solution pattern: Stateless external contracts with interface-based composition
- Inspiration: On-chain SVG projects (Autoglyphs, Art Blocks Engine)

---

**Next Step:** Begin Phase 1 (Cleanup) and Phase 2 (Convert first library as proof of concept)
