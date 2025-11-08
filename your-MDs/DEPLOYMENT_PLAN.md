# Millennium Song — Testnet Deployment & Testing Plan

**Goal**: Test all core functionality before mainnet deployment, in manageable phases.

**Strategy**: Build up complexity incrementally — start simple, add features one at a time.

---

## Overview: 6 Phases

1. **Simple Deploy** — Core NFT + reveals working on Sepolia
2. **Accelerated Reveals** — Test pre→post reveal flow (5 min intervals)
3. **Seven Words** — Test commitment and seed generation
4. **Points (L1 only)** — Test burn-to-earn on Sepolia
5. **Points (Cross-chain)** — Test L2→L1 messaging
6. **Full Integration** — Everything together, ready for mainnet

---

## Phase 1: Simple Deploy (Sepolia L1 Only)

**Goal**: Get a working NFT with countdown → music reveal flow on Sepolia testnet.

### 1.1) Deploy Order

Deploy these contracts to **Sepolia** in order:

```bash
# 1. Core rendering libraries (external contracts)
forge script script/deploy/01_DeployRenderers.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast

# Deploys (in order):
#   - SvgMusicGlyphs
#   - StaffUtils
#   - MidiToStaff
#   - NotePositioning
#   - MusicRendererOrchestrator (wired to above 4)
#   - AudioRenderer
#   - SongAlgorithm

# 2. Main NFT contract
forge script script/deploy/02_DeployMillenniumSong.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast

# Deploys:
#   - MillenniumSong (with renderer addresses from step 1)
#   - Sets startYear = 2026 (default)

# 3. Wire everything together
forge script script/deploy/03_WireRenderers.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast

# Calls:
#   - MillenniumSong.setRenderers(music, audio, song)
```

### 1.2) Simple Test: Mint + Manual Reveal

```bash
# Mint a token to yourself
cast send $MSONG_ADDRESS "mint(address)" $YOUR_ADDRESS --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check tokenURI (should show countdown)
cast call $MSONG_ADDRESS "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL | base64 -d

# Force reveal (test-only function)
cast send $MSONG_ADDRESS "forceReveal(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check tokenURI again (should show staff notation + audio)
cast call $MSONG_ADDRESS "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL | base64 -d > /tmp/metadata.json
cat /tmp/metadata.json | jq -r '.animation_url' | sed 's/data:text\/html;base64,//' | base64 -d > /tmp/reveal.html
open /tmp/reveal.html
```

**Success Criteria**:
- ✅ Countdown SVG shows before reveal (odometer ticking down)
- ✅ Staff notation SVG shows after reveal
- ✅ Click animation_url → audio plays (organ tones)
- ✅ Different seeds produce different notes

---

## Phase 2: Accelerated Reveals (5-Minute Intervals)

**Goal**: Test the full pre-reveal → post-reveal flow without waiting years.

### 2.1) Create Testnet Variant

**New contract**: `MillenniumSongFastReveal.sol`

Changes from main contract:
```solidity
// Instead of Jan 1 each year:
function _revealTimestamp(uint256 rank) internal view returns (uint256) {
    return deployTimestamp + (rank * 5 minutes);  // Reveal every 5 minutes
}
```

### 2.2) Deploy Fast Reveal Version

```bash
forge script script/deploy/DeployFastReveal.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
```

### 2.3) Test Flow

```bash
# Mint 10 tokens
for i in {1..10}; do
  cast send $FAST_MSONG "mint(address)" $YOUR_ADDRESS --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
done

# Check token 1 (should be revealed immediately)
cast call $FAST_MSONG "revealed(uint256)" 1

# Check token 2 (should reveal after 5 minutes)
cast call $FAST_MSONG "revealed(uint256)" 2
# Wait 5 minutes...
cast call $FAST_MSONG "revealed(uint256)" 2  # Now true

# Watch countdown tick down in real-time
# Open token 2 on Rarible testnet, refresh every minute, watch odometer change
```

**Success Criteria**:
- ✅ Token 1 reveals immediately (rank 0)
- ✅ Token 2 reveals 5 minutes after deploy
- ✅ Countdown shows accurate time remaining
- ✅ Odometer animation persists across refreshes (time-synced)
- ✅ Transition from countdown to music notation works
- ✅ Rarible/OpenSea testnet displays both states correctly

---

## Phase 3: Seven Words + Seed Generation

**Goal**: Test owner commitment of seven words and proper seed mixing.

### 3.1) Add Seven Words Functions

Already implemented in `MillenniumSong.sol`:
```solidity
function setSevenWords(uint256 tokenId, bytes32 wordsHash) external
function getSevenWords(uint256 tokenId) external view returns (bytes32)
```

### 3.2) Test Script

```bash
# Mint token
cast send $MSONG "mint(address)" $YOUR_ADDRESS --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Commit seven words (hash of "eternal|sound|resonance|time|memory|future|song")
WORDS_HASH=$(cast keccak "eternal|sound|resonance|time|memory|future|song")
cast send $MSONG "setSevenWords(uint256,bytes32)" 1 $WORDS_HASH --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Reveal token (happens automatically or via forceReveal)
cast send $MSONG "forceReveal(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Verify seed includes seven words hash
# (Check that different seven words produce different music for same tokenId)
```

### 3.3) Seed Entropy Test

Create test script: `script/test/VerifySeedEntropy.s.sol`

```solidity
// Test that changing ANY of the 5 seed components changes the music:
// 1. tokenSeed (set at mint)
// 2. sevenWords (owner commitment)
// 3. previousNotesHash (cumulative)
// 4. globalState (admin entropy)
// 5. tokenId

// Mint 10 tokens with different seven words
// Verify each produces unique music
```

**Success Criteria**:
- ✅ Owner can set seven words before/after mint
- ✅ Seven words are part of seed (changing them changes music)
- ✅ Cannot change seven words after reveal (locked)
- ✅ Different combinations of 5 entropy sources = different notes

---

## Phase 4: Points System (L1 Only - Sepolia)

**Goal**: Test burn-to-earn on Ethereum L1 before adding cross-chain complexity.

### 4.1) Deploy Test NFTs on Sepolia

Create simple test collections:

**Script**: `script/deploy/DeployTestAssets.s.sol`

```solidity
// Deploy:
// 1. TestNFT721 (supply = 100)
// 2. TestNFT1155 (fungible, supply = 1000)
// 3. TestERC20 (total supply = 1,000,000)

// Mint to test addresses
// Set as eligible assets in MillenniumSong
```

### 4.2) Configure Points

```bash
# Add eligible L1 assets
cast send $MSONG "addEligibleL1Asset(address,uint256)" $TEST_NFT_721 1000 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $MSONG "addEligibleL1Asset(address,uint256)" $TEST_ERC20 500 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Set month weights
cast send $MSONG "setMonthWeights(uint256[12])" "[100,95,92,88,85,82,78,75,72,68,65,60]" --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### 4.3) Test L1 Burns

```bash
# Mint test NFT
cast send $TEST_NFT_721 "mint(address)" $YOUR_ADDRESS --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Approve MillenniumSong
cast send $TEST_NFT_721 "approve(address,uint256)" $MSONG 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Burn to earn points for token #1
cast send $MSONG "burnOnL1(address,uint256,uint256)" $TEST_NFT_721 1 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Check points
cast call $MSONG "pointsOf(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

### 4.4) Test Ranking Changes

```bash
# Mint 5 tokens
# Give different point amounts
# Verify ranking changes

# Token 1: 0 points
# Token 2: 100 points
# Token 3: 500 points
# Token 4: 50 points
# Token 5: 200 points

# Expected rank order: 3, 5, 2, 4, 1
# Expected reveal order: same as rank order

# Verify getCurrentRank() matches expected
for i in {1..5}; do
  cast call $MSONG "getCurrentRank(uint256)" $i
done
```

**Success Criteria**:
- ✅ Burn L1 NFT → points credited
- ✅ Month weighting applied correctly
- ✅ Ranking updates immediately
- ✅ Higher points = earlier reveal
- ✅ Ties broken by basePermutation, then tokenId

---

## Phase 5: Points System (Cross-Chain)

**Goal**: Test L2 burns → L1 points via canonical messengers.

### 5.1) Deploy to L2 Testnets

**Chains to test**:
- Base Sepolia
- Optimism Sepolia
- (Arbitrum Sepolia — optional, slower finality)

**Deploy per chain**:
```bash
# Base Sepolia
forge script script/deploy/DeployBurnCollectorBase.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast

# Optimism Sepolia
forge script script/deploy/DeployBurnCollectorOptimism.s.sol --rpc-url $OP_SEPOLIA_RPC_URL --broadcast
```

### 5.2) Configure L2 BurnCollectors

```bash
# On Base Sepolia - add eligible assets
cast send $BURN_COLLECTOR_BASE "addEligibleAsset(address,uint256)" $TEST_NFT_BASE 1000 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Set month weights
cast send $BURN_COLLECTOR_BASE "setMonthWeights(uint256[12])" "[100,95,92,88,85,82,78,75,72,68,65,60]" --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### 5.3) Configure L1 Receivers

```bash
# On Sepolia - set messenger addresses
cast send $MSONG "setMessengers(address,address,address,address)" \
  $BASE_MESSENGER \
  $OP_MESSENGER \
  $ARB_INBOX \
  $ZORA_MESSENGER \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

### 5.4) Test Cross-Chain Flow

**On Base Sepolia**:
```bash
# 1. Mint test NFT
cast send $TEST_NFT_BASE "mint(address)" $YOUR_ADDRESS --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 2. Send to BurnCollector (triggers burn + local points)
cast send $TEST_NFT_BASE "safeTransferFrom(address,address,uint256)" $YOUR_ADDRESS $BURN_COLLECTOR_BASE 1 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# 3. Trigger checkpoint (sends message to L1)
cast send $BURN_COLLECTOR_BASE "checkpoint(address[])" "[$YOUR_ADDRESS]" --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

**Wait for finality** (~1 hour for OP Stack testnets)

**On Sepolia (L1)**:
```bash
# Check if points arrived
cast call $MSONG "pointsOf(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL

# Check rank updated
cast call $MSONG "getCurrentRank(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

**Success Criteria**:
- ✅ L2 burn recorded locally
- ✅ Checkpoint sent via canonical messenger
- ✅ L1 receives message after finality delay
- ✅ Points applied to correct token
- ✅ Ranking updates immediately on L1
- ✅ Works for multiple L2s (Base, Optimism)

---

## Phase 6: Full Integration Test

**Goal**: Everything working together — the full user journey.

### 6.1) End-to-End Flow

**Day 0 (Deploy)**:
```bash
# 1. Deploy all contracts (renderers, main NFT, L2 collectors)
# 2. Configure messengers and eligible assets
# 3. Set startYear or use fast-reveal mode
```

**Day 0 (Mint)**:
```bash
# User mints token #42
# Sets seven words: "eternal|sound|resonance|time|memory|future|song"
# Token shows countdown to reveal
```

**Day 0-5 (Earn Points)**:
```bash
# User burns NFTs on Base, Optimism
# Checkpoints triggered
# Points accumulate on L1
# Token #42 moves up in queue
```

**Day 5 (Reveal)**:
```bash
# Reveal time arrives (5 min in fast mode, Jan 1 in prod)
# User refreshes metadata
# Countdown transitions to staff notation
# Click animation_url → hears organ tones
```

**Day 10 (Next Reveal)**:
```bash
# Token #43 reveals
# New note plays
# Composition progresses
```

### 6.2) Test Matrix

| Test Case | Expected Result |
|-----------|----------------|
| Mint before reveal time | Shows countdown ✅ |
| Reveal arrives | Transitions to music ✅ |
| Click animation_url | Plays organ audio ✅ |
| Burn NFT on L2 | Points increase on L1 ✅ |
| Points update | Rank changes ✅ |
| Multiple tokens | Each has unique seed/music ✅ |
| Seven words change | Music changes ✅ |
| Seven words locked after reveal | Transaction reverts ✅ |
| Rarible display | Countdown + music both render ✅ |
| OpenSea display | Countdown + music both render ✅ |

---

## Phase 7: Mainnet Preparation

**Before deploying to mainnet**:

### 7.1) Security Checklist

- [ ] All contracts audited
- [ ] Test coverage >90%
- [ ] Gas optimization complete
- [ ] Month weight formula finalized
- [ ] Eligible assets list finalized
- [ ] BaseValue table finalized
- [ ] VRF integration tested
- [ ] Finalize/freeze mechanism tested
- [ ] No owner backdoors after finalize
- [ ] Verified on Etherscan (all chains)

### 7.2) Deployment Sequence (Mainnet)

**Week 1: L1 Deployment**
```bash
# 1. Deploy rendering libraries (Ethereum mainnet)
# 2. Deploy MillenniumSong
# 3. Run simple mint/reveal test
# 4. DO NOT finalize yet
```

**Week 2: L2 Deployment**
```bash
# 1. Deploy BurnCollectors (Base, Optimism, Arbitrum, Zora)
# 2. Configure eligible assets
# 3. Test small burns on each chain
# 4. Verify messages reach L1
```

**Week 3: Integration Testing**
```bash
# 1. Mint test tokens on mainnet (small batch)
# 2. Test full flow with real burns
# 3. Verify marketplace rendering (Rarible, OpenSea)
# 4. Monitor for issues
```

**Week 4: Freeze & Launch**
```bash
# 1. Fix any bugs found
# 2. Call finalizeRenderers() (lock rendering stack)
# 3. Public announcement
# 4. Open minting
```

---

## Scripts to Create

### Deployment Scripts
- [ ] `script/deploy/01_DeployRenderers.s.sol`
- [ ] `script/deploy/02_DeployMillenniumSong.s.sol`
- [ ] `script/deploy/03_WireRenderers.s.sol`
- [ ] `script/deploy/DeployFastReveal.s.sol`
- [ ] `script/deploy/DeployTestAssets.s.sol`
- [ ] `script/deploy/DeployBurnCollectorBase.s.sol`
- [ ] `script/deploy/DeployBurnCollectorOptimism.s.sol`

### Test Scripts
- [ ] `script/test/MintAndReveal.s.sol`
- [ ] `script/test/VerifySeedEntropy.s.sol`
- [ ] `script/test/TestL1Burns.s.sol`
- [ ] `script/test/TestCrossChainCheckpoint.s.sol`
- [ ] `script/test/TestRankingChanges.s.sol`
- [ ] `script/test/FullEndToEnd.s.sol`

### Utility Scripts
- [ ] `script/utils/DecodeMetadata.s.sol` — Decode tokenURI to files
- [ ] `script/utils/ForceRevealBatch.s.sol` — Reveal multiple tokens
- [ ] `script/utils/CheckpointAllL2.s.sol` — Trigger checkpoints on all L2s
- [ ] `script/utils/QueryRankings.s.sol` — Show current reveal order

---

## Testnet Addresses Reference

Keep a running list in `.env` and `ADDRESSES.md`:

```bash
# Sepolia (L1)
MSONG_ADDRESS=0x...
MUSIC_RENDERER_ADDRESS=0x...
AUDIO_RENDERER_ADDRESS=0x...
SONG_ALGORITHM_ADDRESS=0x...

# Base Sepolia
BURN_COLLECTOR_BASE=0x...
TEST_NFT_BASE=0x...

# Optimism Sepolia
BURN_COLLECTOR_OP=0x...
TEST_NFT_OP=0x...
```

---

## Estimated Timeline

| Phase | Duration | Complexity |
|-------|----------|------------|
| Phase 1: Simple Deploy | 1 day | ⭐ Easy |
| Phase 2: Fast Reveals | 2 days | ⭐⭐ Medium |
| Phase 3: Seven Words | 1 day | ⭐ Easy |
| Phase 4: Points L1 | 2 days | ⭐⭐ Medium |
| Phase 5: Points L2 | 3-5 days | ⭐⭐⭐ Hard |
| Phase 6: Integration | 2 days | ⭐⭐ Medium |
| **Total** | **11-15 days** | |

**Note**: Phase 5 is hardest because of cross-chain message delays and debugging.

---

## Next Immediate Step

**Start with Phase 1, Step 1.1**:

Create `script/deploy/01_DeployRenderers.s.sol` that deploys all 7 rendering contracts in order and saves addresses.

Want me to create that script now?
