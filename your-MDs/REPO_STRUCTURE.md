# Repository Structure

## Overview
This repo contains the Millennium Song NFT project - an on-chain ERC-721 collection where each token represents a note event in a millennium-scale composition.

## Directory Structure

### `/src` - Source Contracts

#### `/src/core/`
Core NFT and music generation contracts:
- **MillenniumSong.sol** - Main ERC-721 NFT contract
- **SongAlgorithm.sol** - On-chain music generation library (V3 lead with rests + V2 bass)

#### `/src/auction/` (TBD)
Planned location for MATT (Market-Aware Truth-Telling) auction contracts.
See `auction/README.md` for detailed spec.

#### `/src/points/` (TBD)  
Planned location for cross-chain points system:
- L1 Aggregator (Ethereum mainnet)
- L2 Burn Collectors (Base, Optimism, Arbitrum)
See `points/README.md` for detailed spec.

#### `/src/render/`
SVG rendering libraries:
- `/render/pre/` - Pre-reveal renderers (countdown clock, etc.)
- `/render/post/` - Post-reveal music staff renderers
  - `StaffUtils.sol` - Standardized grand staff generation
  - `SvgMusicGlyphs.sol` - Music symbol definitions
  - `MidiToStaff.sol` - MIDI to staff position mapping
  - `NotePositioning.sol` - Note placement calculations
  - `AbcToSvg.sol` - ABC notation to SVG converter

#### `/src/legacy/`
Legacy/test contracts not part of main system:
- CountdownNFT.sol
- CountdownNFTLite.sol  
- Counter.sol

### `/script` - Deployment & Dev Scripts

#### `/script/deploy/`
Production deployment scripts:
- **DeployMillenniumSong.s.sol** - Main deployment script
- DeployCountdown.s.sol - Legacy countdown deploy
- DeployLiteAndSeed.s.sol - Legacy lite deploy
- DeployAndSeed.s.sol - Legacy deploy with seed

#### `/script/dev/`
Active development/testing scripts:
- GenerateIndividualBeats.s.sol - Individual beat SVG generation
- TestNotePositioningLib.s.sol - Note positioning tests
- TestMillenniumBeats.s.sol - Beat rendering tests

#### `/script/archive/`
Historical debug scripts (excluded from build).
Contains 28+ debug/test scripts from development iterations.

### `/test` - Test Contracts

Active tests for music rendering pipeline:
- **MidiToStaff.t.sol** - MIDI to staff position mapping (10 tests)
- **MusicPipelineIntegration.t.sol** - End-to-end pipeline tests
- **NotePositioning.t.sol** - Note placement calibration tests
- **NotePreview.t.sol** - Visual preview tests
- **AbcToSvg.t.sol** - ABC to SVG conversion tests

Note: Some tests currently failing due to in-progress staff positioning fine-tuning.

### `/o/old-tests/` - Archived Tests
Incompatible tests from previous iterations (not part of build).

## Build Configuration

### foundry.toml
- Optimizer enabled (200 runs, via-IR)
- Excludes: `script/archive/**`, `test/archive/**`
- File permissions for OUTPUTS folder

## Key Commands

```bash
# Build
forge build

# Test
forge test

# Deploy (Sepolia)
forge script script/deploy/DeployMillenniumSong.s.sol --fork-url $SEPOLIA_RPC_URL --broadcast

# Generate individual beat SVGs
forge script script/dev/GenerateIndividualBeats.s.sol
```

## Current Status

✅ **Completed:**
- Core NFT contract structure
- SongAlgorithm music generation (full V3/V2 system)
- SVG rendering pipeline architecture
- MIDI to staff position mapping
- Note positioning formulas (calibrated)
- Grand staff rendering utilities

🔄 **In Progress:**
- Fine-tuning note positioning accuracy
- Staff positioning edge cases

❌ **Planned:**
- MATT auction contracts (`/src/auction/`)
- Points system contracts (`/src/points/`)
- VRF permutation system
- Finalization & ownership renunciation

## References

- **agent.md** - Complete technical specification
- **progress.md** - Detailed development log
- `/src/auction/README.md` - Auction contract spec
- `/src/points/README.md` - Points system spec
