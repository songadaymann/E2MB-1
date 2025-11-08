# Fast Reveal on Sepolia - The Clean Way

## What We Created

A **testnet-only variant** of the production contract that reveals every 5 minutes instead of yearly:

```
EveryTwoMillionBlocks.sol          ← Production (PRISTINE, never modified)
    ↓
EveryTwoMillionBlocks_test.sol     ← Test copy with virtual functions
    ↓
FastRevealTest.sol                 ← Overrides timing (5-min reveals)
```

**Key Point**: Production contract (`EveryTwoMillionBlocks.sol`) stays **100% untouched**.

---

## Architecture

### Production Contract (Mainnet Ready)
- **File**: `src/core/EveryTwoMillionBlocks.sol`
- **Status**: PRISTINE - no `virtual` keywords
- **Purpose**: Deploy to mainnet as-is

### Test Variant (Testnet Only)
- **File**: `src/testnet/EveryTwoMillionBlocks_test.sol`
- **Status**: Carbon copy with 2 changes:
  1. `getCurrentRank()` is `virtual`
  2. `_jan1Timestamp()` is `internal view virtual` (was `private pure`)
- **Purpose**: Base for testing variants

### Fast Reveal (Testnet Deployment)
- **File**: `src/testnet/FastRevealTest.sol`
- **Inherits from**: `EveryTwoMillionBlocks_test`
- **Overrides**: Only timing - everything else is production code
- **Reveals**: Every 5 minutes (Token #1 at T+0, Token #2 at T+5min, etc.)

---

## Deployment Options

### Option 1: Deploy Fresh Renderers (Clean Start)

```bash
source .env

forge script script/testnet/DeployFastReveal.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

This deploys:
- ✅ All 7 rendering contracts (new)
- ✅ MusicRendererOrchestrator (new)
- ✅ FastRevealTest NFT
- Saves addresses to `deployed-fast-reveal.env`

### Option 2: Reuse Existing Renderers (Save Gas)

If you already deployed renderers for another contract:

```bash
# First, set addresses in .env:
export SVG_GLYPHS=0x...
export STAFF_UTILS=0x...
export MIDI_TO_STAFF=0x...
export NOTE_POSITIONING=0x...
export AUDIO_RENDERER=0x...
export SONG_ALGORITHM=0x...
export REUSE_RENDERERS=true

# Then deploy (only deploys new NFT + orchestrator)
forge script script/testnet/DeployFastReveal.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify
```

**Why this works**: Rendering contracts are stateless - any NFT contract can call them!

---

## Usage

### 1. Mint Tokens

```bash
source deployed-fast-reveal.env

# Mint 20 tokens for testing
cast send $FAST_REVEAL "batchMint(address,uint256)" \
  <YOUR_ADDRESS> 20 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

### 2. Check Status

```bash
# Watch reveals happen
forge script script/testnet/WatchReveals.s.sol --rpc-url $SEPOLIA_RPC_URL

# Or check individual token
cast call $FAST_REVEAL "isTokenRevealed(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
cast call $FAST_REVEAL "getTimeUntilReveal(uint256)" 5 --rpc-url $SEPOLIA_RPC_URL
```

### 3. Test Reveal Transition

**Token #1 reveals immediately** (rank 0):
```bash
# Should already be past reveal time
cast send $FAST_REVEAL "prepareReveal(uint256)" 1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

cast send $FAST_REVEAL "finalizeReveal(uint256)" 1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

**Token #2 reveals after 5 minutes**:
```bash
# Wait 5 minutes, then:
cast send $FAST_REVEAL "prepareReveal(uint256)" 2 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

cast send $FAST_REVEAL "finalizeReveal(uint256)" 2 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### 4. View Metadata

```bash
# Get full metadata
cast call $FAST_REVEAL "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL | \
  xxd -r -p | \
  sed 's/^.*data:application\/json;base64,//' | \
  base64 -d | \
  jq '.'
```

### 5. View on Marketplace

```bash
# Get address
echo "https://testnet.rarible.com/token/sepolia/$FAST_REVEAL:1"
echo "https://testnets.opensea.io/assets/sepolia/$FAST_REVEAL/1"
```

---

## Reveal Timeline

With 20 tokens minted:

| Time | Revealed | Next Up |
|------|----------|---------|
| 0:00 | Token #1 | #2 in 5 min |
| 0:05 | Tokens #1-2 | #3 in 5 min |
| 0:10 | Tokens #1-3 | #4 in 5 min |
| 0:30 | Tokens #1-7 | #8 in 5 min |
| 1:00 | Tokens #1-13 | #14 in 5 min |
| 1:35 | All 20! | Done |

---

## What Gets Tested

### ✅ Pre-Reveal Countdown
- 12-digit odometer
- Time-synced animation
- Closeness calculation
- Metadata structure

### ✅ Two-Step Reveal
- `prepareReveal()` snapshots rank
- `finalizeReveal()` generates music
- State transitions
- Error handling

### ✅ Post-Reveal Music
- Staff notation rendering
- Clef positioning
- Note placement
- Ledger lines
- White-on-black theme

### ✅ Audio Player
- Organ synthesis
- Continuous playback
- HTML generation
- "Ringing since" timestamp

### ✅ Marketplace Integration
- Rarible rendering
- OpenSea rendering
- Metadata refresh
- Image/animation display

---

## Renderer Reuse Example

Say you already deployed EveryTwoMillionBlocks to Sepolia at these addresses:

```bash
# From previous deployment
export SVG_GLYPHS=0xd6DF883c23337B0925012Da2646a6E7bA5D9083f
export STAFF_UTILS=0xF0ac54C0D3Fe7FCd911776F9B83C99d440cEe2F1
export MIDI_TO_STAFF=0xd3bada9A75268fa43dd6F6F6891d8cfAA5DD8Ff0
export NOTE_POSITIONING=0x64935B6349bfbEc5fB960EAc1e34c19539AA70C2
export AUDIO_RENDERER=0xF68310926327B76b102ddc5e25500A42F83DE7af
export SONG_ALGORITHM=0xc0Da9A18f16807725dc0C6bEd7E49A2725D912A3
export REUSE_RENDERERS=true

# Deploy FastRevealTest that reuses all of those
forge script script/testnet/DeployFastReveal.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

**Result**: Only deploys:
- New MusicRendererOrchestrator (points to existing renderers)
- New FastRevealTest NFT

Saves ~7 contract deployments!

---

## Files Created

| File | Purpose |
|------|---------|
| `src/testnet/EveryTwoMillionBlocks_test.sol` | Test variant with virtual functions |
| `src/testnet/FastRevealTest.sol` | 5-minute reveal version |
| `script/testnet/DeployFastReveal.s.sol` | Deployment (fresh OR reuse) |
| `script/testnet/WatchReveals.s.sol` | Monitor reveals |
| `script/testnet/TestTransition.s.sol` | Capture transition |

---

## Production Contract Status

**EveryTwoMillionBlocks.sol remains:**
- ✅ Unchanged
- ✅ No virtual keywords
- ✅ Ready for mainnet deployment
- ✅ Not dependent on test variant

The test variant is a **separate branch** - production never touched!

---

## Cleanup

After testing, you can:
1. Keep test contracts on Sepolia (they don't interfere with anything)
2. Or deploy new ones for each test round
3. Production deployment will be completely separate

The test variant won't be deployed to mainnet, so no confusion.

---

## Next Steps

1. **Deploy to Sepolia**: Run the deployment script
2. **Mint 10-20 tokens**: Test batch minting
3. **Watch first reveals**: Monitor the 5-minute intervals
4. **Test transitions**: Capture countdown → revealed metadata
5. **Verify marketplaces**: Check Rarible/OpenSea rendering
6. **Document findings**: Note any issues for production deployment

Then when ready for mainnet:
- Deploy `EveryTwoMillionBlocks.sol` (the pristine version)
- No test artifacts, no virtual keywords
- Production ready!
