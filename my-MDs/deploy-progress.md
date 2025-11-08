# Deployment Progress — Oct 20, 2025

**Latest Update (Oct 20, 2025)**  
- Fresh Sepolia rollout of the full renderer stack, including the new square-safe HTML countdown.  
- `EveryTwoMillionBlocks` rewired to the latest SVG + HTML countdown renderers and verified via live mint (#1).  
- Legacy one-shot deploy scripts moved to `script/deploy/deprecated/` to avoid accidental reuse.  
- Added `deployments/sepolia.json` as the single source of truth for current addresses; all scripts should read from this file going forward.
- Redeployed 5-minute fast-reveal test stack (`FastRevealTest`) after `forge clean`; new NFT `0xc740…` wired to Oct 20 renderer stack and end-to-end `prepareReveal → finalizeReveal` flow verified on token #1 (manual gas cap no longer required once wiring corrected).
- Deployed fresh `PointsManager` (`0xE747…`) against the current NFT, wired via `setPointsManager` (`tx 0xed53…` earlier) and confirmed `addPoints`/`currentRankOf` still propagate through `EveryTwoMillionBlocks.getCurrentRank`.
- Added `PointsAggregator` (`0xb694…`) as the owner of `PointsManager`; messenger addresses temporarily point to the deployer for Sepolia checkpoint testing (`tx 0xfa8b…`). Dummy 721/1155/erc20 collections registered with base values for manual burn trials.

| Contract | Address | Notes |
|----------|---------|-------|
| SvgMusicGlyphs | `0x7131B5faB75062012d1e7316Bc30F5F368d9b105` | Current deployment (Oct 20) |
| StaffUtils | `0x22BFD478ED0399dAc14fed10c27377448fc692b6` | — |
| MidiToStaff | `0xf6Fc33a93b1F25c6c6a08D73c8Acc1a0aF363024` | — |
| NotePositioning | `0xf9d625338069EfbE4b505089139358087603D69b` | — |
| MusicRendererOrchestrator | `0xC6f402B392c540Afa40E403ce1e19cd8d4494556` | — |
| AudioRenderer | `0xAcF2747100B63e25e8B006B1d6b36a68BF488E9E` | — |
| SongAlgorithm | `0xB5B25d077E93E4B7b80f3DA66d5b74d328240459` | — |
| CountdownRendererV2 (SVG) | `0x2c55fFaf0fB3a9ea7675524c3548e8D140b2DDfa` | Circle layout renderer |
| CountdownHtmlRenderer | `0xdB222CF577cF69675f537263c1e374F5CA52BBd9` | Square/centered HTML countdown |
| PointsAggregator | `0xb6945f815741b5713f9E9C2eF59472f3A10b1069` | Owns PointsManager; messengers = deployer for testing |
| DummyOneOfOne | `0x614FE9079021688115A8Ec29b065344C033f9740` | Base value 1000 (test) |
| DummyEdition1155 | `0x7Ef7dF0F64A2591fd5bE9c1E88728e59CB5D362B` | Base value 200 (test) |
| DummyERC20 | `0xD2DcB326F003DC8db194C74Db2749F8C653Df6aC` | Base value 50 (test) |

**Fast-Reveal Test Deployment (Sepolia)**
- NFT (5-min cadence): `0xc7407ECC4dC3b73a4A70572B8E949FA07048C747`
- Orchestrator: `0x39a36A9f3feCb6d4946E1F5a338B136af40bCAdB`
- Countdown renderers wired to production stack (`0x2c55…`, `0xdB22…`)
- Status: `configure` ✓, `mint` (direct `mint`) ✓, `prepareReveal(1)` ✓, `finalizeReveal(1)` ✓ → stored lead/bass events confirmed in state (`NoteRevealed` at block `0x9041f3`). `DeployFastReveal.s.sol` patched to pass song algorithm ahead of orchestrator when wiring.

**Main Contracts / Wiring**
- EveryTwoMillionBlocks: `0x674307b5d8340fa5d6a659d252d6b816bc85997a`
- PointsManager: `0xE747263e5e7db4Dd17cb4502bC037B0B18d7aBd0`
- Renderer wiring txs: see `broadcast/03_WireRenderers.s.sol/11155111/run-latest.json`
- Countdown renderer swaps: 
  - SVG: `0xb4d1b985583b727d8cc12e3999b9f28477248809a59aea9ee1f7c1e0b8cf338a`
  - HTML: `0x0a4a37318717f145f79184c030fd6e9a5635229712e64e466cb0db4db4bb31f7`

**Verification Checklist**
- ✅ Minted token #1 (tx `0xdb67fe60ec008fcda9c137b36263f93efe4cda7986b53dfa6f36fc1bc4e2f110`) for prereveal smoke test  
- ✅ Confirmed `tokenURI(1)` returns new SVG + HTML payloads  
- ✅ PointsManager wired and live-ranked (tx `0xed53b005a2e92b4bfd17f565ea04bde8ecb230dc7fe6a97bc49496b02bf4372f`); token #2 minted for test (tx `0x0534c5a741c2eda01bcfb2f3327d83b00f5832f14917ee6c1ecd6f0dde191d0b`) and `addPoints` verified via txs `0x0595d450…` & `0x73a8bf66…`  
- ✅ PointsAggregator deployed (tx `0x3154fe2c5303e032077ba00afbc3fd7309701a149753e107f74dfe0a749994f8`) and now owns PointsManager (`tx 0x6b98c382abf557dc08f431894aa656d8960404d84c4afff3e24d8ff2b37c1197`); messenger addresses set to deployer for Sepolia checkpoint calls (`tx 0xfa8b673cc70826bf13cf9bfca26c7b6a394012ccc7f794e90e579bd9e8915a4a`). Dummy ERC-721/1155/20 contracts deployed and registered for testing (`txs 0x57f30df5…`, `0x93d2c68b…`, `0x283632a9…`).
- 🔄 Rarible metadata refreshed manually after each renderer swap  
- 🔲 Pending: finalizeRenderers() (deferred)

**Next Actions**
1. Update wiring scripts to read from `deployments/sepolia.json` automatically.  
2. When ready, call `finalizeRenderers()` (after any additional PointsManager/Aggregator QA).  
3. Backfill a quick canary (script or test) to ensure `DeployFastReveal` wiring order stays aligned with `setRenderers` signature.
4. Consider adding an automated canary test that checks `countdownRenderer()` and `countdownHtmlRenderer()` match the JSON file before minting.

---

# Deployment Progress — Oct 14, 2025

**Update (Oct 14, 2025)**  
- Redeployed the full renderer stack (7 post-reveal + 2 pre-reveal) to Sepolia with the new countdown split.  
- Countdown SVG now comes from the lightweight `CountdownSvgRenderer` wrapper (library hosted externally).  
- HTML countdown (`CountdownHtmlRenderer`) verified; ready to wire into `animation_url`.  
- Broadcast log: `broadcast/01_DeployRenderers.s.sol/11155111/run-latest.json`.

| Contract | Address | Notes |
|----------|---------|-------|
| SvgMusicGlyphs | `0x9E32494f20870AaB3Eb7e2590bE33e6e806aeB87` | Verified |
| StaffUtils | `0xf1dcdA4E21424A1E9E599feC22ea06aD3c8DFACB` | Verified |
| MidiToStaff | `0xf5A631d5a19C264a87019Fa137e46Dd54eCa8Fbb` | Verified |
| NotePositioning | `0xB126D4bEF6e4b10D9199191C01Cd8C810046b049` | Verified |
| MusicRendererOrchestrator | `0x00b969940fdeC95d7E31Cf889Bc7D231F1Eebe56` | Verified |
| AudioRenderer | `0x9Df1794481B53e5Ae79034f5cEfbA7f3aE1085b0` | Verified |
| SongAlgorithm | `0xe7f5028cfDaeAFf997DfDfd1c9B8B14a39097Ac5` | Verified |
| CountdownSvgRenderer | `0x7Ca3eCD26368D4233B0A96E708172c070d9e9F0e` | New SVG wrapper |
| CountdownHtmlRenderer | `0xA488d9068B58070DC56ab3b30984ea96567DA04F` | Supplies `animation_url` |

**Next Actions**  
1. Point `EveryTwoMillionBlocks` at the new renderer addresses (`setRenderers`, `setCountdownRenderer`, `setCountdownHtmlRenderer`).  
2. Finalize renderers after validation.  
3. Retire/update legacy scripts (`DeployCountdownV2.s.sol`) to avoid redeploying the old SMIL renderer.

---

# Deployment Progress — Oct 9, 2025

**Goal**: Deploy basic revealed NFT to Sepolia testnet to test look/sound

**Status**: ✅ SUCCESS - All issues fixed, two-step reveal working on Sepolia!

---

## Summary

Attempted first real deployment of the modular Millennium Song architecture to test the revealed NFT (staff notation + audio). Hit several bugs, fixed most, but reveal function still out of gas.

---

## What Worked ✅

### 1. Rendering Stack Deployment
Successfully deployed all 7 external rendering contracts to Sepolia:

| Contract | Address | Size | Status |
|----------|---------|------|--------|
| SvgMusicGlyphs | `0xc8Fa763D85679A138F5F68098c7ed278bf28B53B` | 12.7 KB | ✅ Deployed |
| StaffUtils | `0x3B9F8dCaf9A05BcDA50509B64cC1CeB5e7FB713d` | 6.4 KB | ✅ Deployed |
| MidiToStaff | `0x85f933595f706964bD9c1047df8DD1762861Ab84` | 1.8 KB | ✅ Deployed |
| NotePositioning | `0x3C6E6960Bd3eeA397556dd33Cf7FF135023Da34e` | 5.0 KB | ✅ Deployed |
| MusicRendererOrchestrator | `0xDfC8e8Fb509F8C520853E9Bd92b815FAcfd19F1b` | 8.5 KB | ✅ Deployed |
| AudioRenderer | `0xaE74c1BE1B65880083a07161d87b964301816c48` | 4.2 KB | ✅ Deployed |
| SongAlgorithm | `0xBfaAD2Fd28692F1F4E41d8DC8Ff4fA8f020006C6` | 7.9 KB | ✅ Deployed |

**Total**: All 7 contracts under 24KB limit ✅

### 2. Main Contract Deployment
**MillenniumSong**: `0x2c4A66Eb9a12678cDc2f537378abced0ba80AF2c`
- Size: ~21 KB (under 24KB limit!) ✅
- Owner functions working ✅
- Mint working ✅
- SetRenderers working ✅

### 3. Pre-Reveal (Countdown) Working
- Token #1 minted successfully
- Countdown SVG generated (12 KB)
- Animated odometer showing time to year 2026
- 4×3 grid layout (12 digits) rendering

**Output**: `OUTPUTS/token-1-countdown.svg`

---

## Bugs Fixed 🐛

### Bug 1: Missing Functions
**Problem**: Contract deployed but most functions reverted
```
Error: execution reverted
```

**Root Cause**: ERC-721 doesn't have `totalSupply()` by default, and autogenerated getters for interface types were causing ABI mismatches

**Fix**: Added explicit getter functions (Oracle suggestion)
```solidity
function totalSupply() external view returns (uint256) { return totalMinted; }
function getSongAlgorithm() external view returns (address) { return address(songAlgorithm); }
function getMusicRenderer() external view returns (address) { return address(musicRenderer); }
function getAudioRenderer() external view returns (address) { return address(audioRenderer); }
```

**File**: `src/core/MillenniumSong.sol` lines 204-221

---

### Bug 2: Arithmetic Underflow in Countdown
**Problem**: tokenURI() reverted with panic 0x11 (arithmetic underflow)
```
Error: panic: arithmetic underflow or overflow (0x11)
```

**Root Cause**: Two underflow issues in CountdownRenderer:
1. `10000 - ctx.closenessBps` when closenessBps > 10000
2. `block.timestamp - _jan1Timestamp(START_YEAR)` when current time < START_YEAR (2026)

**Fix 1 - CountdownRenderer saturation**:
```solidity
// Before:
string memory bg = _grayCss(uint16(10000 - ctx.closenessBps));

// After:
uint256 closenessCapped = ctx.closenessBps > 10000 ? 10000 : ctx.closenessBps;
uint256 bgBrightness = closenessCapped >= 10000 ? 0 : (10000 - closenessCapped);
string memory bg = _grayCss(uint16(bgBrightness));
```

**Fix 2 - MillenniumSong time check**:
```solidity
// Before:
uint256 elapsed = block.timestamp - _jan1Timestamp(START_YEAR);

// After:
uint256 startTime = _jan1Timestamp(START_YEAR);
if (revealTime > block.timestamp && block.timestamp >= startTime) {
    uint256 elapsed = block.timestamp - startTime;
    // ... calculate closenessBps
} else if (block.timestamp < startTime) {
    closenessBps = 0; // Before START_YEAR
}
```

**Files Modified**:
- `src/render/pre/CountdownRenderer.sol` lines 11-21
- `src/core/MillenniumSong.sol` lines 285-296

---

### Bug 3: AudioRenderer Interface Mismatch
**Problem**: Compilation error - wrong number of arguments
```
Error: Wrong argument count for function call: 5 arguments given but expected 4
```

**Root Cause**: Updated AudioRenderer to take `svgContent` instead of `tokenId` and `year`, but MillenniumSong still calling with old signature

**Fix**: Updated call site to pass SVG content
```solidity
// Before:
audioRenderer.generateAudioHTML(
    lead.pitch, bass.pitch, revealTimestamp, tokenId, revealYear
)

// After:
audioRenderer.generateAudioHTML(
    lead.pitch, bass.pitch, revealTimestamp, svgContent
)
```

**File**: `src/core/MillenniumSong.sol` lines 312-319

---

## Known Issues ❌

### Issue 1: Force Reveal Out of Gas
**Problem**: `forceReveal(uint256)` transaction fails silently
```bash
status: 0 (failed)
```

**Likely Cause**: SongAlgorithm.generateBeat() + MusicRenderer.render() too expensive for single transaction

**Evidence**:
- Transaction accepts but fails with status 0
- No revert reason (silent failure = out of gas)
- Tried with --gas-limit 3000000, still fails

**Impact**: Cannot test post-reveal (staff notation + audio) on-chain yet

**Next Steps**:
- Profile gas usage of generateBeat() 
- Check if external contract calls are too expensive
- May need to optimize music generation or split into multiple transactions
- Consider caching generated notes in storage instead of regenerating each call

---

### Issue 2: Malformed JSON Metadata
**Problem**: JSON parsing fails, SVG not properly encoded
```
jq: parse error: Invalid numeric literal at line 1, column 139
```

**Root Cause**: SVG is embedded as raw string instead of data URI
```json
{
  "image": "<svg xmlns=...>...</svg>"  // ❌ Wrong
}
```

**Should Be**:
```json
{
  "image": "data:image/svg+xml;base64,PHN2ZyB4bWxucz0..."  // ✅ Correct
}
```

**Impact**: Marketplaces may not render properly, can't extract with standard tools

**File**: Likely `src/core/MillenniumSong.sol` tokenURI() function around line 273

---

### Issue 3: SVG XML Error  
**Problem**: Browser reports "Extra content at the end of the document"
```
error on line 1 at column 11959: Extra content at the end of the document
```

**Likely Cause**: 
- Unclosed tag
- Extra characters after `</svg>`
- Encoding issue in string concatenation

**Impact**: SVG renders partially but may have missing elements

**Next Steps**: Validate SVG output with XML parser

---

## Deployment Artifacts

### Scripts Created
- `script/deploy/01_DeployRenderers.s.sol` - Deploys 7 rendering contracts
- `script/deploy/02_DeployMain.s.sol` - Deploys MillenniumSong NFT  
- `script/deploy/03_WireRenderers.s.sol` - Connects renderers to main contract
- `script/test/MintAndReveal.s.sol` - Test script for minting + revealing
- `script/test/DecodeMetadata.s.sol` - Extract metadata to files
- `DEPLOY.sh` - One-click deployment script (has fs permission issues)

### Environment Files
- `deployed-renderers.env` - Addresses of 7 rendering contracts
- `deployed-main.env` - Address of MillenniumSong (not created due to fs permissions)

### Output Files
- `OUTPUTS/token-1-metadata.json` - Full metadata (12 KB, malformed)
- `OUTPUTS/token-1-countdown.svg` - Extracted countdown SVG (12 KB)
- `OUTPUTS/token-1-animation.html` - Empty (0 bytes - reveal failed)
- `OUTPUTS/token-1-image.svg` - Empty (0 bytes - reveal failed)

---

## Contract Size Analysis

### Initial Assumption
From error message: "MillenniumSong is above contract size limit (39905 > 24576)"

**This was misleading!** The 39KB was from a different/cached build.

### Actual Sizes
**Measured with deployed bytecode**:
- MillenniumSong: **~21 KB** ✅ Under limit
- CountdownRenderer (inlined): ~10 KB
- Core logic: ~11 KB

**Why it fits**:
- All post-reveal rendering moved to external contracts
- Only CountdownRenderer is inlined (library)
- Modular architecture works!

---

## Deployment Process (Actual)

### Step 1: Deploy Renderers
```bash
forge script script/deploy/01_DeployRenderers.s.sol \
  --rpc-url $SEPOLIA_RPC_URL --broadcast
```
✅ All 7 contracts deployed

**Issue**: `vm.writeFile()` permission denied - had to manually save addresses

---

### Step 2: Deploy Main Contract  
```bash
forge create src/core/MillenniumSong.sol:MillenniumSong \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```
✅ Deployed to `0x2c4A66Eb9a12678cDc2f537378abced0ba80AF2c`

**Issue**: Script kept reusing same address (nonce collision)

---

### Step 3: Wire Renderers
```bash
cast send $MSONG "setRenderers(address,address,address)" \
  $MUSIC_RENDERER $AUDIO_RENDERER $SONG_ALGORITHM \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```
✅ Renderers connected

**Issue**: Initially used wrong address for SongAlgorithm (address collision), had to redeploy

---

### Step 4: Mint Token
```bash
cast send $MSONG "mint(address,uint32)" $YOUR_ADDRESS 12345 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```
✅ Token #1 minted

---

### Step 5: Get Metadata
```bash
cast call $MSONG "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```
✅ Countdown metadata returned (pre-reveal)

---

### Step 6: Force Reveal (Failed)
```bash
cast send $MSONG "forceReveal(uint256)" 1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```
❌ Transaction failed with status 0 (out of gas)

---

## Testing Results

### Pre-Reveal ✅
- [x] Token mints
- [x] Countdown SVG generates  
- [x] Odometer animation renders
- [x] Time calculation works (closeness = 0 when before START_YEAR)
- [x] No arithmetic underflows

### Post-Reveal ❌
- [ ] forceReveal completes
- [ ] Music generation works
- [ ] Staff notation SVG renders
- [ ] Audio HTML generates
- [ ] Click-to-play audio works

---

## Next Steps (Priority Order)

### Immediate (Blocking Reveal)
1. **Debug forceReveal gas issue**
   - Add gas profiling to SongAlgorithm.generateBeat()
   - Check MusicRendererOrchestrator.render() gas usage
   - Consider optimizations or reveal in multiple steps

2. **Fix JSON metadata encoding**
   - Change `image` to data URI format  
   - Ensure proper Base64 encoding
   - Test with jq/marketplaces

3. **Fix SVG XML error**
   - Validate generated SVG
   - Check for unclosed tags or extra content
   - Test in multiple browsers

### Short Term
4. **Create simpler reveal test**
   - Deploy version without heavy rendering
   - Just store basic note data
   - Prove reveal logic works

5. **Optimize gas usage**
   - Profile all external contract calls
   - Consider caching strategy
   - May need to simplify music generation

### Before Mainnet
6. **Full integration test**  
   - Get revealed token working on testnet
   - Test on Rarible/OpenSea testnet
   - Verify audio plays in marketplace iframe
   - Test full mint → reveal flow

7. **Security audit**
   - Review all arithmetic (underflow/overflow)
   - Check access controls
   - Verify renderer finalization

---

## Oracle Insights

### Consultation 1: Contract Reverts
**Question**: Why do most functions revert even though contract deployed?

**Answer**: 
- Missing `totalSupply()` function (ERC-721 doesn't have it by default)
- Autogenerated getters for interface types cause ABI mismatches  
- Solution: Add explicit getter functions

**Impact**: Fixed immediately, unblocked testing

---

### Consultation 2: Arithmetic Underflow
**Question**: What's causing panic 0x11 in tokenURI?

**Answer**:
- `10000 - ctx.closenessBps` underflows when closenessBps > 10000
- `block.timestamp - startTime` underflows when current time < START_YEAR
- Solution: Saturating subtraction with guards

**Impact**: Countdown now works for all time ranges

---

## Lessons Learned

### 1. Contract Size is Manageable
**Myth**: Need proxy pattern or extreme optimization
**Reality**: Modular external contracts + inlined countdown = 21KB total ✅

### 2. Oracle is Excellent for Debugging
Used Oracle twice, both times got precise diagnosis + fix in <5 minutes

### 3. Arithmetic Needs Guards
Solidity 0.8 checked arithmetic is great but need explicit guards for:
- Timestamp comparisons across epoch boundaries
- Percentage/basis point calculations
- Any user-influenced math

### 4. Gas Profiling Critical
Should have profiled gas BEFORE deploying. Now blocked on expensive reveal.

### 5. Test Incrementally
Should have tested:
1. Deploy ✅
2. Mint ✅  
3. Pre-reveal metadata ✅
4. **Force reveal with simple data** ← Skipped this
5. Full rendering

---

## Open Questions

1. **Why is forceReveal out of gas?**
   - Is it generateBeat()? 
   - Is it the external contract calls?
   - Is it the SVG/HTML generation?
   - **Answer (Oracle)**: `getCurrentRank()` is O(n) loop + music generation too expensive in one tx

2. **Why is JSON malformed?**
   - Where is the data URI encoding supposed to happen?
   - Is Base64.encode() being called?

3. **What's the SVG XML error?**
   - Extra content after `</svg>`?
   - Encoding issue?
   - Unclosed tag?

---

## Commands Reference

### Deploy Full Stack
```bash
source .env
forge script script/deploy/01_DeployRenderers.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast
# (Save addresses to deployed-renderers.env)
forge create src/core/MillenniumSong.sol:MillenniumSong --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast
```

### Wire & Test
```bash
export MSONG=0x2c4A66Eb9a12678cDc2f537378abced0ba80AF2c
source deployed-renderers.env
cast send $MSONG "setRenderers(address,address,address)" $MUSIC_RENDERER_ADDRESS $AUDIO_RENDERER_ADDRESS $SONG_ALGORITHM_ADDRESS --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $MSONG "mint(address,uint32)" $YOUR_ADDRESS 12345 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast call $MSONG "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

### Extract Metadata
```bash
cast call $MSONG "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL | \
  xxd -r -p | \
  sed 's/^.*data:application\/json;base64,//' | \
  base64 -d > OUTPUTS/token-1-metadata.json
```

---

## File Changes This Session

### Modified
- `src/core/MillenniumSong.sol` - Added getters, fixed underflow, fixed AudioRenderer call
- `src/render/pre/CountdownRenderer.sol` - Fixed arithmetic underflow
- `src/render/post/AudioRenderer.sol` - Changed interface to accept svgContent
- `src/interfaces/IAudioRenderer.sol` - Updated interface signature

### Created  
- `script/deploy/01_DeployRenderers.s.sol`
- `script/deploy/02_DeployMain.s.sol`
- `script/deploy/03_WireRenderers.s.sol`
- `script/test/MintAndReveal.s.sol`
- `script/test/DecodeMetadata.s.sol`
- `DEPLOY.sh`
- `DEPLOYMENT_PLAN.md`
- `ADDRESSES.md`
- `deployed-renderers.env`
- `deploy-progress.md` (this file)

---

## Solution: Two-Step Reveal (Oracle Recommendation)

### Problem
Current `forceReveal()` does too much in one transaction:
1. `getCurrentRank()` - O(n) loop through all tokens
2. `SongAlgorithm.generateBeat()` - Complex music generation
3. External contract calls
4. Note storage + hash updates

**Total gas**: Exceeds transaction limit, causes silent failure (status 0)

### Solution Architecture

**Split into 2 transactions:**

#### Transaction 1: `prepareReveal(tokenId)` (Cheap)
```solidity
// What it does:
- Validates token exists, not revealed, not pending
- Computes rank = getCurrentRank(tokenId) ONCE
- Snapshots rank → pendingBeat[tokenId]
- Snapshots sevenWords[tokenId] → pendingWords[tokenId] (locks inputs)
- Sets revealPending[tokenId] = true
- Emits RevealPrepared event

// Gas: ~50-100k (just the rank loop + storage writes)
```

#### Transaction 2: `finalizeReveal(tokenId)` (Medium)  
```solidity
// What it does:
- Validates pending reveal exists
- Validates sevenWords unchanged (prevents manipulation)
- Computes seed using pendingWords and current previousNotesHash
- Calls SongAlgorithm.generateBeat(pendingBeat, seed)
- Stores revealedLeadNote/revealedBassNote
- Updates previousNotesHash (cumulative)
- Marks revealed[tokenId] = true
- Clears pending state
- Emits NoteRevealed event

// Gas: ~200-400k (music gen + external calls + storage)
```

### New Storage Required

```solidity
mapping(uint256 => bool) public revealPending;
mapping(uint256 => uint32) public pendingBeat;
mapping(uint256 => bytes32) public pendingWords;

event RevealPrepared(uint256 indexed tokenId, uint32 beat, bytes32 words);
```

### Access Control
```solidity
modifier onlyOwnerOrTokenOwner(uint256 tokenId) {
    require(msg.sender == owner() || msg.sender == _ownerOf(tokenId), "Not authorized");
    _;
}
```

### Safety Features
1. **Input locking**: sevenWords snapshotted at prepare, validated at finalize
2. **Race prevention**: revealPending flag prevents double-prepare
3. **Cancellation**: Optional `cancelReveal()` to clear pending state
4. **Determinism preserved**: Uses same seed computation as original single-tx version

### Usage Flow

**Testnet** (forceReveal replacement):
```bash
# Step 1: Prepare
cast send $MSONG "prepareReveal(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PK

# Step 2: Finalize (can be immediate or later)
cast send $MSONG "finalizeReveal(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL --private-key $PK
```

**Mainnet** (automatic reveals):
```bash
# Anyone can trigger when time arrives:
cast send $MSONG "prepareReveal(uint256)" 42 --rpc-url $MAINNET_RPC_URL --private-key $PK
# (Wait for confirmation)
cast send $MSONG "finalizeReveal(uint256)" 42 --rpc-url $MAINNET_RPC_URL --private-key $PK
```

### Benefits
- ✅ Each transaction fits in gas limit
- ✅ No optimization/caching required
- ✅ Maintains all original functionality
- ✅ Safe against race conditions
- ✅ User or owner can trigger
- ✅ Can cancel if needed

### Trade-offs
- Requires 2 transactions instead of 1
- Adds ~3 storage slots per token (cleared after finalize)
- Slightly more complex user flow

### Implementation Effort
**Estimated**: 1 hour (Oracle assessment)
- Add new storage mappings
- Implement prepareReveal()
- Implement finalizeReveal()
- Update tests
- Optional: Add cancelReveal()

### Testing Strategy
1. Deploy updated contract to Sepolia
2. Call prepareReveal(1) → verify pending state set
3. Call finalizeReveal(1) → verify notes generated and stored
4. Call tokenURI(1) → verify staff notation + audio renders
5. Test on marketplace (Rarible/OpenSea testnet)

---

**Session Duration**: ~2 hours
**Contracts Deployed**: 8 (7 renderers + 1 main)
**Bugs Fixed**: 3 critical
**Bugs Remaining**: 3 blocking
**Test Status**: Countdown works, reveal blocked (solution identified)

---

## Session 2: All Issues Fixed (Oct 9, 2025 - Afternoon)

### Issues Resolved ✅

#### Issue 1: Malformed JSON Metadata - FIXED
**Root Cause**: Music renderer was returning raw SVG string instead of data URI in post-reveal path

**Fix Applied**: [MillenniumSong.sol](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts-where-NOTE-RENDER-and-COUNTDOWN-were-made/src/core/MillenniumSong.sol#L415-L418) lines 415-418
```solidity
// Now wraps SVG in data URI format
image = string(abi.encodePacked(
    "data:image/svg+xml;base64,",
    Base64.encode(bytes(svg))
));
```

**Test Result**: ✅ JSON parses correctly with `jq`, proper data URIs for both image and animation_url

---

#### Issue 2: SVG XML Error - RESOLVED
**Diagnosis**: Old deployment artifact, not an actual code issue

**Verification**: Generated SVG from `MusicRendererOrchestrator` is clean:
- Starts with `<svg xmlns=...>`
- Ends with `</svg>` (no extra content)
- 11,470 bytes, valid XML

**Test Result**: ✅ Renders perfectly in browsers and on Rarible testnet

---

#### Issue 3: Force Reveal Out of Gas - FIXED with Two-Step Mechanism

**Problem**: Single-transaction reveal exceeded gas limit due to:
1. `getCurrentRank()` - O(n) loop through all tokens
2. `SongAlgorithm.generateBeat()` - Complex music generation
3. External contract calls + storage writes

**Solution Implemented**: Two-step reveal mechanism

**New Functions Added**:
1. `prepareReveal(tokenId)` - Snapshot rank and inputs (~21-65k gas)
2. `finalizeReveal(tokenId)` - Generate music and store (~145-182k gas)
3. `cancelReveal(tokenId)` - Reset pending state if needed

**Storage Added**:
```solidity
mapping(uint256 => bool) public revealPending;
mapping(uint256 => uint32) public pendingBeat;
mapping(uint256 => bytes32) public pendingWords;

event RevealPrepared(uint256 indexed tokenId, uint32 beat, bytes32 words);
event RevealCancelled(uint256 indexed tokenId);
```

**Gas Comparison**:
- **Old (failed)**: Single tx exceeded limit, status 0
- **New (working)**: 
  - prepareReveal: 21,510 - 64,505 gas
  - finalizeReveal: 145,256 - 182,237 gas
  - **Total: 166,766 - 246,742 gas** ✅ Well within limits!

**Test Results**:
- ✅ Local test: All steps working, proper state transitions
- ✅ Sepolia testnet: Both transactions confirmed, music generated
- ✅ Safety: Seven words locked at prepare, validated at finalize

---

### Feature Addition ✨

#### Seven Words as Description
**Enhancement**: NFT description now displays the owner's seven words instead of generic text

**Changes**:
- Added `mapping(uint256 => string) public sevenWordsText` to store actual words
- Updated `setSevenWords()` to accept string and store both hash (for seed) and text (for display)
- Modified `tokenURI()` to use seven words as description if set

**Fallback**: If no seven words set, shows default description

**Example**:
```json
{
  "description": "eternal harmony resonance time melody transcend infinity"
}
```

---

### New Deployment (Oct 9, 2025 - Afternoon)

**Sepolia Testnet - All Contracts with Fixes**:

| Contract | Address | Status |
|----------|---------|--------|
| SongAlgorithm | `0xa699A234C0Cdc9D0212F23401f050398C6FD950f` | ✅ Deployed |
| SvgMusicGlyphs | `0x57241CD3EA36752C3F5A3f3dc8e508Ef77381FDf` | ✅ Deployed |
| StaffUtils | `0xd56c3C9c8B69A7a659Ba096C8e429957b01A763E` | ✅ Deployed |
| MidiToStaff | `0xe18C7dDe95F20D1053861004485430298Af2469B` | ✅ Deployed |
| NotePositioning | `0xcc4F4e7dAa15e44c26a733E9481C7fdf82c173F2` | ✅ Deployed |
| MusicRendererOrchestrator | `0xAebb86E973D40714528DfE4ccc0663Fe7D4C78e7` | ✅ Deployed |
| AudioRenderer | `0x8b3e9ab55af3e27F13a3481fc540C65e04E1F5Da` | ✅ Deployed |
| **MillenniumSong** | **`0xA62ADf47908fe4fdeD9B3cA84884910c5400aB32`** | ✅ Deployed & Wired |

**Test Results**:
- ✅ Token #1 minted (seed: 99999)
- ✅ Two-step reveal completed successfully
- ✅ Music generated: G4 dotted quarter + Eb2 half note
- ✅ Metadata with proper data URIs
- ✅ Renders correctly on Rarible testnet
- ✅ Audio player works (click to play organ tones)

**View on Rarible**: 
`https://testnet.rarible.com/token/sepolia/0xA62ADf47908fe4fdeD9B3cA84884910c5400aB32:1`

---

### Test Scripts Created

1. **`script/dev/TestTwoStepReveal.s.sol`** - Complete two-step reveal flow test
2. **`script/dev/TestSevenWordsDescription.s.sol`** - Verify seven words as description
3. Updated **`script/dev/TestCompleteMetadata.s.sol`** - Fixed AudioRenderer signature

**All test scripts passing** ✅

---

### Files Modified This Session (Session 2)

**Core Contracts**:
- `src/core/MillenniumSong.sol` - Added two-step reveal, fixed JSON encoding, added seven words text storage

**Test Scripts**:
- `script/dev/TestCompleteMetadata.s.sol` - Updated AudioRenderer call signature
- `script/deploy/03_WireRenderers.s.sol` - Fixed parameter order for setRenderers()

**New Scripts**:
- `script/dev/TestTwoStepReveal.s.sol` - Test two-step reveal mechanism
- `script/dev/TestSevenWordsDescription.s.sol` - Test seven words feature

**Deployment Artifacts**:
- `deployed.env` - Current Sepolia addresses (all 8 contracts)
- `deployed-renderers.env` - Rendering stack addresses
- `deployed-main.env` - Main NFT address

**Cleanup**:
- Moved 20+ broken legacy scripts to `script/archive/`
- Moved 3 old test files to `_deprecated/`

---

### Next Steps (Priority Order)

#### Immediate (Ready Now)
1. ✅ **Test on Rarible/OpenSea testnet** - DONE, works perfectly
2. **Mint multiple tokens** - Test ranking system with different points
3. **Test seven words flow** - Set words, verify description updates
4. **Extended soak test** - Leave on testnet for 1-2 weeks

#### Short Term (Before Mainnet)
5. **Gas optimization review**
   - Current: 246k gas total for two-step reveal
   - Target: Under 200k if possible (already acceptable)
   
6. **Security audit prep**
   - Focus areas: Two-step reveal state machine, seven words locking
   - Document all state transitions
   - Test edge cases (cancel reveal, race conditions)

7. **Marketplace testing**
   - OpenSea testnet rendering
   - Verify metadata refresh after reveal
   - Test audio player in marketplace iframes

#### Before Mainnet Launch
8. **Points system integration** (Phase 4-5 from DEPLOYMENT_PLAN.md)
   - L1 burn collectors
   - L2 cross-chain messaging
   - Ranking updates

9. **VRF integration** - Permutation for basePermutation mapping

10. **Finalization testing** - Test `finalizeRenderers()` lock

11. **Comprehensive test suite**
    - Unit tests for all new functions
    - Integration tests for full flows
    - Gas profiling for all paths

---

### Commands Reference (Updated)

#### View Current Deployment
```bash
source deployed.env
echo "MillenniumSong: $MSONG_ADDRESS"
cast call $MSONG_ADDRESS "totalSupply()" --rpc-url $SEPOLIA_RPC_URL
```

#### Two-Step Reveal Flow
```bash
# Step 1: Prepare (snapshots rank)
cast send $MSONG_ADDRESS "prepareReveal(uint256)" <TOKEN_ID> \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy

# Step 2: Finalize (generates music)
cast send $MSONG_ADDRESS "finalizeReveal(uint256)" <TOKEN_ID> \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy --gas-limit 300000
```

#### Set Seven Words
```bash
cast send $MSONG_ADDRESS 'setSevenWords(uint256,string)' <TOKEN_ID> "your seven words here" \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --legacy
```

#### View Metadata
```bash
cast call $MSONG_ADDRESS "tokenURI(uint256)" <TOKEN_ID> --rpc-url $SEPOLIA_RPC_URL | \
  xxd -r -p | sed 's/^.*data:application\/json;base64,//' | base64 -d | jq '.'
```

---

**Session 2 Duration**: ~1.5 hours  
**Issues Fixed**: 3 critical (JSON, SVG, gas limit)  
**Features Added**: 2 (two-step reveal, seven words description)  
**Test Status**: ✅ All working on Sepolia testnet  
**Contracts Deployed**: 8 (fresh deployment with all fixes)  
**Test Scripts Created**: 2 new, 1 updated  
**Legacy Cleanup**: 24 broken scripts archived  

---

## Session 3: Contract Renamed - EveryTwoMillionBlocks (Oct 9, 2025 - Afternoon)

### Rename Complete ✅

**Contract renamed from MillenniumSong → EveryTwoMillionBlocks**

**New Identity:**
- Name: "Every Two Million Blocks"
- Symbol: "E2MB"
- Contract: [EveryTwoMillionBlocks.sol](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts-where-NOTE-RENDER-and-COUNTDOWN-were-made/src/core/EveryTwoMillionBlocks.sol)

**Changes Made:**
1. Renamed core contract file
2. Updated deployment scripts
3. Fixed setRenderers parameter order bug (was reversed)
4. All test scripts updated

---

### New Feature: Note-Based Names ✨

**Enhancement**: Revealed tokens now show musical notation in their name instead of generic numbering

**Name Format:**
- **Pre-reveal:** "Every Two Million Blocks #1 - Year 2026"
- **Post-reveal:** "G4+Bb2 [67+46]" (note names + MIDI pitches)

**Example Names:**
- Token #1: "G4+Bb2 [67+46]"
- Token #2: "Bb4+F2 [70+41]"

**Implementation:**
- Added `_midiToNoteName()` helper function
- Converts MIDI to note name (60 → "C4", 67 → "G4", etc.)
- Handles flats (Db, Eb, Gb, Ab, Bb)
- Shows REST for lead rests

**Code:** Lines 542-555 in [EveryTwoMillionBlocks.sol](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts-where-NOTE-RENDER-and-COUNTDOWN-were-made/src/core/EveryTwoMillionBlocks.sol#L542-L555)

---

### Seven Words Feature Verified ✅

**Testing Results:**

**Token #1 (without seven words):**
- Name: "G4+Bb2 [67+46]" ✅
- Description: "Every Two Million Blocks token #1 - Year 2026. Continuous organ tones ring since reveal." (fallback)

**Token #2 (with seven words):**
- Name: "Bb4+F2 [70+41]" ✅
- Description: "eternal harmony resonance time melody transcend infinity" ✅

**Flow Confirmed:**
1. Mint token
2. Set seven words BEFORE reveal
3. Reveal token
4. Seven words become the description

**Critical:** Seven words must be set before reveal (reverts if already revealed)

---

### Latest Deployment (Sepolia)

**Deployed:** Oct 9, 2025 - Afternoon

| Contract | Address | Status |
|----------|---------|--------|
| **EveryTwoMillionBlocks** | **`0xdCEC22d76590bCd0E8935c8Aaf537F7E750a1740`** | ✅ Working |
| SvgMusicGlyphs | `0xd6DF883c23337B0925012Da2646a6E7bA5D9083f` | ✅ Deployed |
| StaffUtils | `0xF0ac54C0D3Fe7FCd911776F9B83C99d440cEe2F1` | ✅ Deployed |
| MidiToStaff | `0xd3bada9A75268fa43dd6F6F6891d8cfAA5DD8Ff0` | ✅ Deployed |
| NotePositioning | `0x64935B6349bfbEc5fB960EAc1e34c19539AA70C2` | ✅ Deployed |
| MusicRendererOrchestrator | `0x9EB5f4DA5Eb104dd34AAf9397B9b178AdFA2DC81` | ✅ Deployed |
| AudioRenderer | `0xF68310926327B76b102ddc5e25500A42F83DE7af` | ✅ Deployed |
| SongAlgorithm | `0xc0Da9A18f16807725dc0C6bEd7E49A2725D912A3` | ✅ Deployed |

**Test Tokens:**
- Token #1: G4+Bb2 (no seven words, default description)
- Token #2: Bb4+F2 (with seven words description) ✅

**View on Rarible:**
- Token #1: https://testnet.rarible.com/token/sepolia/0xdCEC22d76590bCd0E8935c8Aaf537F7E750a1740:1
- Token #2: https://testnet.rarible.com/token/sepolia/0xdCEC22d76590bCd0E8935c8Aaf537F7E750a1740:2

---

### Files Modified This Session

**Core Contract:**
- Renamed: `src/core/MillenniumSong.sol` → `src/core/EveryTwoMillionBlocks.sol`
- Added `_midiToNoteName()` function (lines 542-555)
- Updated name generation logic (lines 455-475)
- Changed constructor: `ERC721("Every Two Million Blocks", "E2MB")`

**Deployment Scripts:**
- Renamed: `script/deploy/DeployMillenniumSong.s.sol` → `DeployEveryTwoMillionBlocks.s.sol`
- Updated: `script/deploy/02_DeployMain.s.sol`
- Updated: `script/deploy/03_WireRenderers.s.sol`
- Fixed: `script/deploy/DeploySimple.s.sol` (parameter order in setRenderers)

**Documentation:**
- Updated: `ADDRESSES.md` (new deployment addresses)

---

### Key Improvements This Session

1. ✅ **Meaningful Names** - Musicians can see what notes they own at a glance
2. ✅ **Seven Words Integration** - Personal messages become NFT descriptions
3. ✅ **Clean Branding** - "Every Two Million Blocks" reflects the actual mechanism
4. ✅ **Bug Fix** - setRenderers parameter order corrected

---

### Next Steps

**Immediate:**
- [ ] Monitor Rarible indexing for both tokens
- [ ] Test audio player on token #2
- [ ] Verify marketplace refresh updates metadata

**Short Term:**
- [ ] Mint more tokens with different seven words
- [ ] Test note name format with RESTful notes (e.g., "REST+Eb2 [-1+39]")
- [ ] Document seven words best practices for users

**Before Mainnet:**
- [ ] Deploy production version with all features
- [ ] Extended testnet period (1-2 weeks)
- [ ] Community testing of seven words feature
- [ ] Verify marketplace compatibility across platforms

---

**Session 3 Duration**: ~15 minutes  
**Contracts Deployed**: 8 (full stack with renamed contract)  
**Features Added**: 2 (note-based names, verified seven words)  
**Test Status**: ✅ Both features working perfectly  
**Bugs Fixed**: 1 (setRenderers parameter order)

---

*Last updated: Oct 9, 2025 - Afternoon (Session 3)*

---

## Session 4: Fast Reveal Testing Architecture (Oct 10, 2025)

### Goal
Test the reveal mechanism (countdown → staff notation transition) with accelerated timing instead of waiting years.

### Approaches Explored

#### Approach 1: Standalone Fast Reveal Contract
**What we tried**: Create `FastReveal.sol` - a simplified standalone contract with 5-minute reveals
**Result**: ❌ Rejected - too simplified, not testing actual production code
**Files created then deleted**: 
- `src/testnet/FastReveal.sol`
- `FAST_REVEAL_GUIDE.md`  
- `FAST_REVEAL_SUMMARY.md`

#### Approach 2: Time Manipulation (Foundry/Anvil) ✅
**What we tried**: Use Foundry's `vm.warp()` and Anvil's `evm_increaseTime` to fast-forward blockchain time
**Result**: ✅ **RECOMMENDED** - Tests actual production contract with zero modifications

**Files created**:
- `test/RevealTransition.t.sol` - Foundry tests with time warping
- `script/testnet/TestRevealWithTimeWarp.s.sol` - Anvil deployment script
- `TESTING_WITH_TIMEWARP.md` - Complete guide

**Key insight**: Your friend was right - you can manipulate time on local blockchain!

**Foundry Tests:**
```bash
forge test --match-contract RevealTransition -vvv
```
- Instant (runs in seconds)
- Tests 100% production code
- Uses `vm.warp()` to jump through years

**Anvil Local Node:**
```bash
anvil  # Terminal 1: Start local blockchain
# Terminal 2: Deploy and manipulate time
cast rpc evm_increaseTime 31536000  # +1 year
cast rpc anvil_mine 1               # Apply it
```
- More realistic (actual blockchain)
- Interactive testing
- Free testnet ETH

#### Approach 3: Test Variant with Virtual Functions (Sepolia Deployment)
**What we tried**: Create test variant of production contract with `virtual` keywords for fast reveals on real Sepolia testnet

**Your brilliant idea**: Keep production pristine, create test-only variant!

**The Plan**:
1. Keep `EveryTwoMillionBlocks.sol` PRISTINE (production ready)
2. Create `EveryTwoMillionBlocks_test.sol` (carbon copy + `virtual` keywords)
3. Create `FastRevealTest.sol` (inherits from test, overrides timing to 5 minutes)
4. Deploy to Sepolia, reuse existing rendering contracts

**Files created**:
- ✅ `src/testnet/EveryTwoMillionBlocks_test.sol` - Test variant (carbon copy with virtual)
- ✅ `src/testnet/FastRevealTest.sol` - 5-minute reveal version
- ✅ `script/testnet/DeployFastReveal.s.sol` - Deployment with renderer reuse option
- ✅ `script/testnet/WatchReveals.s.sol` - Monitor reveals in real-time
- ✅ `script/testnet/TestTransition.s.sol` - Capture metadata before/after
- ✅ `FAST_REVEAL_SEPOLIA_GUIDE.md` - Complete deployment guide

**Changes to test variant**:
1. Contract name: `EveryTwoMillionBlocks` → `EveryTwoMillionBlocks_test`
2. Token name: "Every Two Million Blocks" → "Every Two Million Blocks TEST"
3. `getCurrentRank()` - already had `virtual` keyword ✅
4. `_jan1Timestamp()` - changed from `private pure` to `internal view virtual`

**FastRevealTest overrides**:
```solidity
// Simple tokenID-based ranking (no points)
function getCurrentRank(uint256 tokenId) public view override returns (uint256) {
    return tokenId - 1;  // Token #1 → rank 0, #2 → rank 1, etc.
}

// 5-minute intervals instead of yearly
function _jan1Timestamp(uint256 year) internal view override returns (uint256) {
    uint256 rank = year - START_YEAR;
    return deployTimestamp + (rank * 5 minutes);
}
```

**Deployment attempt**:
```bash
forge script script/testnet/DeployFastReveal.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --legacy
```

**Result**: ❌ **CONTRACT SIZE LIMIT EXCEEDED**
- FastRevealTest: 24,704 bytes
- Limit: 24,576 bytes
- **Over by 128 bytes** (0.5%)

**Root cause**: FastRevealTest inherits ALL code from EveryTwoMillionBlocks_test including:
- Points storage system (~8-10KB)
- L1/L2 bridge endpoints (~3KB)  
- Cross-chain checkpoint handlers (~2KB)
- Ranking algorithm with points sorting (~2KB)
- Month weighting logic (~1KB)

**For testing reveals, we don't need any of this!**

---

### 🎯 THE SOLUTION: Extract Points into Separate Contract

**User insight**: "The NFT contract should really just have core NFT related logic - supply, minting, etc."

**Proposed refactor**:

```
EveryTwoMillionBlocks (~14KB - FITS!)
  ├─ ERC-721 core (supply, minting, ownerOf)
  ├─ Reveal logic (two-step reveal, seed computation)
  ├─ Rendering integration (external renderer calls)
  ├─ address pointsManager
  └─ getCurrentRank() → pointsManager.getCurrentRank(tokenId)

PointsManager (~12KB - FITS!)
  ├─ Points storage (per-token)
  ├─ Base permutation storage (VRF)
  ├─ Ranking algorithm (points DESC → permutation → tokenId)
  ├─ L1 burn endpoints
  ├─ L2 checkpoint receivers (Base, OP, Arb, Zora)
  ├─ Month weighting logic
  └─ Configuration (messengers, weights, etc.)

FastRevealTest (~14KB - FITS!)
  ├─ Inherits from EveryTwoMillionBlocks
  ├─ Override getCurrentRank() → return tokenId - 1
  ├─ Override _jan1Timestamp() → 5-minute intervals
  └─ No points code inherited at all!
```

#### Benefits

**Size & Deployment**:
- ✅ Main NFT: ~14KB (42% margin under 24KB)
- ✅ PointsManager: ~12KB (51% margin)
- ✅ FastRevealTest: ~14KB (42% margin)
- ✅ All contracts deploy easily

**Architecture**:
- ✅ NFT focused on NFT things (supply, reveals, metadata)
- ✅ Points focused on game mechanics (burns, ranking)
- ✅ Clean separation of concerns
- ✅ Each contract does one thing well

**Testing**:
- ✅ FastRevealTest doesn't inherit points bloat
- ✅ Can test NFT logic independently
- ✅ Can test points logic independently
- ✅ Can mock points manager for NFT tests

**Flexibility**:
- ✅ Could make PointsManager upgradeable (fix bugs)
- ✅ Could swap points algorithm without redeploying NFT
- ✅ NFT contract stays immutable after finalize
- ✅ Points logic can evolve

**Upgradeability Strategy**:
```
EveryTwoMillionBlocks
  ├─ Immutable after finalize (trust-minimized)
  ├─ Stores: pointsManager address
  └─ Owner can update pointsManager address before finalize

PointsManager  
  ├─ Could be upgradeable proxy
  ├─ Fix bugs in ranking algorithm
  ├─ Adjust month weights if needed
  └─ Owner can renounce after testing period
```

#### What Moves to PointsManager

**From EveryTwoMillionBlocks.sol, REMOVE**:
```solidity
// Storage (~200 lines)
mapping(uint256 => uint256) public points;
mapping(uint256 => uint256) public basePermutation;
address public baseMessenger;
address public optimismMessenger;
address public arbitrumInbox;
address public zoraMessenger;
mapping(address => uint256) public eligibleL1Assets;
uint256[12] public monthWeights;

// Functions (~300 lines)
function getCurrentRank(uint256 tokenId) {...}  // Complex points sorting
function applyCheckpointFromBase(bytes calldata payload) {...}
function applyCheckpointFromOptimism(bytes calldata payload) {...}
function applyCheckpointFromArbitrum(bytes calldata payload) {...}
function applyCheckpointFromZora(bytes calldata payload) {...}
function burnOnL1(address nft, uint256 nftTokenId, uint256 msongTokenId) {...}
function addEligibleL1Asset(address nft, uint256 baseValue) {...}
function setMessengers(...) {...}
function setMonthWeights(uint256[12] calldata weights) {...}
function _getCurrentMonth() {...}
function _applyPoints(uint256 tokenId, uint256 delta) {...}

// Events
event PointsApplied(...);
event CheckpointReceived(...);
```

**Total removed**: ~500 lines, ~15KB bytecode

**What stays in EveryTwoMillionBlocks.sol**:
```solidity
// Minimal interface to points
IPointsManager public pointsManager;

function setPointsManager(address _pointsManager) external onlyOwner {
    require(!renderersFinalized, "Already finalized");
    pointsManager = IPointsManager(_pointsManager);
}

function getCurrentRank(uint256 tokenId) public view returns (uint256) {
    if (address(pointsManager) == address(0)) {
        return tokenId - 1;  // Fallback: simple tokenID order
    }
    return pointsManager.getCurrentRank(tokenId);
}

// For convenience
function getPoints(uint256 tokenId) public view returns (uint256) {
    if (address(pointsManager) == address(0)) return 0;
    return pointsManager.getPoints(tokenId);
}
```

**Total added**: ~30 lines, ~1KB bytecode

**Net savings**: ~14KB! 🎉

#### Migration Path for Existing Deployments

For EveryTwoMillionBlocks already on Sepolia (0xdCEC22d76590bCd0E8935c8Aaf537F7E750a1740):
1. That contract has points baked in (can't change)
2. Leave it as-is (frozen in time)
3. New deployments use modular architecture
4. Or redeploy if still testing

### Open Questions for Next Session

1. **PointsManager ownership**: Same owner as NFT? Or separate?
2. **Finalization coordination**: Should NFT.finalize() also freeze PointsManager?
3. **Fallback ranking**: If pointsManager not set, use tokenID? Or revert?
4. **VRF integration**: Where does basePermutation get set? (PointsManager or NFT?)
5. **Cross-contract calls**: NFT needs to validate token ownership for burns - how to coordinate?

### Estimated Contract Sizes After Refactor

| Contract | Current | After Refactor | Margin |
|----------|---------|----------------|--------|
| EveryTwoMillionBlocks | ~24KB+ (too big) | ~14KB | 43% margin ✅ |
| PointsManager | N/A | ~12KB | 51% margin ✅ |
| FastRevealTest | 24.7KB (too big) | ~14KB | 43% margin ✅ |

All under limit with comfortable margins!

---

**Session 4 Duration**: ~2 hours  
**Approaches Tried**: 3  
**Key Breakthrough**: Modular points architecture  
**Status**: Documentation complete, ready for refactor next session  
**Recommendation**: Start next session with 30-min refactor, then deploy & test

---

*Last updated: Oct 10, 2025 - Session 4*
