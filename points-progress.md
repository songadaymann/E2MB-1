# Points System — Development Progress

Cross-chain burn-to-earn points system for Millennium Song NFT queue ranking.

---

## Sepolia Burn-to-Points Test Plan (Oct 20, 2025)

**Objective**: Exercise the full burn → points → ranking flow on Sepolia in a production-like setting, with the user manually driving burns.

1. **Prime the target NFT**
   - Mint ~10 Millennium Song tokens on Sepolia (contract `0x674307b5d8340fa5d6a659d252d6b816bc85997a`) for live token IDs.
   - Capture baseline ranks/points via `getCurrentRank` / `getPoints` before awarding any points.
2. **Deploy dummy burnable collections**
   - ERC-721 `DummyOneOfOne` (owner mint, holder burn).
   - ERC-1155 `DummyEdition` (batch mint/burn).
   - Verify both contracts on Sepolia and mint representative tokens to the testing wallet(s).
3. **Deploy the real L1 aggregator (test config)**
   - Implement the production-style aggregator that receives checkpoints via `applyCheckpointFrom{Chain}` and owns `PointsManager`.
   - For Sepolia, set each messenger address to the deployer (or a small harness) so we can call the entrypoints directly while we test.
   - Transfer `PointsManager` ownership to the aggregator after deployment.
4. **Configure scoring**
   - Call `addEligibleL1Asset` (via the adapter/owner) to define base values for each dummy collection (e.g., 1/1 vs edition).
   - Set any desired month weights if we want to test non-default curves.
5. **Manual burn runs**
   - For each scenario:
     1. Mint the dummy NFT to the test wallet.
     2. Burn the dummy asset on-chain.
     3. Credit points via `directAward` or `applyCheckpointFromBase` on the aggregator.
     4. Verify points/ranks on-chain (`PointsManager.pointsOf`, `currentRankOf`, `EveryTwoMillionBlocks.getPoints`).
6. **Reset tools**
   - Use `batchSetPoints` (or a helper) to zero out state between experiments.
   - Maintain a log of test tx hashes + outcomes in this file for future reference.

Once Sepolia coverage feels solid, flip the messenger addresses to the canonical ones and reuse the same contract for mainnet/L2 rollouts.

### Progress Log — Step 1 (Oct 20, 2025)

- Minted Millennium Song tokens `#1-#10` on Sepolia to seed the points testbed. All mints used the deployer wallet (`0xAd9f…`) and now sit at `points=0`, `rank=tokenId-1`.
- Transaction references:

| Token | Seed | Tx Hash |
|-------|------|---------|
| #1 | 12345 | `0xdb67fe60ec008fcda9c137b36263f93efe4cda7986b53dfa6f36fc1bc4e2f110` |
| #2 | 1111 | `0x0534c5a741c2eda01bcfb2f3327d83b00f5832f14917ee6c1ecd6f0dde191d0b` |
| #3 | 1113 | `0xec29d88afe3a0bcf2c9860f4b72668d163152b2e65c921125dd5bed8089be0ab` |
| #4 | 1114 | `0xbadfd671f8ab43ae2f59fa798479e6b5f2234548b341df55e314caa3a2f571b6` |
| #5 | 1115 | `0x5f21d0d6e5bb5e0e0761eaea3dd15c1a109080235006d6a0b6e56cff94bb978b` |
| #6 | 1116 | `0x6dabb57329ae72dc8dfc6cc08cf498f0803ada9b1972311f9d2e059903b9da84` |
| #7 | 1117 | `0xd77ab92666c2908aa1cb448351d0321b683e8f95f5575ab01b75691e0cbd1f20` |
| #8 | 1118 | `0x601f352d90a61328b8b46f68055947844884be39e3b350b172621dc85a14c2d3` |
| #9 | 1119 | `0x30dba8a3cd5a1d1c650020996d894bbe17dfff4b21cf68f1b498dafef0006ee0` |
| #10 | 1120 | `0x6e5fb74b0d33dfe47faf7d6e24bca6d25d0a6a8f651502f4a36ea4f43251b17e` |

Baselines (Oct 20, 2025 21:53 UTC):

| Token | Points | Rank |
|-------|--------|------|
| #1 | 0 | 0 |
| #2 | 0 | 1 |
| #3 | 0 | 2 |
| #4 | 0 | 3 |
| #5 | 0 | 4 |
| #6 | 0 | 5 |
| #7 | 0 | 6 |
| #8 | 0 | 7 |
| #9 | 0 | 8 |
| #10 | 0 | 9 |

### Progress Log — Step 2 (Oct 21, 2025)

- Deployed the final testing control plane:
  - `PointsManager` → `0xE747263e5e7db4Dd17cb4502bC037B0B18d7aBd0` (tx `0x75c19f0dc62d94c1ae784d75cbc94739aa049ab192431b8aad40ea2c0a637eb0`).
  - `PointsAggregator` → `0xb6945f815741b5713f9E9C2eF59472f3A10b1069` (tx `0x3154fe2c5303e032077ba00afbc3fd7309701a149753e107f74dfe0a749994f8`), ownership transfer confirmed in `tx 0x6b98c382abf557dc08f431894aa656d8960404d84c4afff3e24d8ff2b37c1197`.
  - Messenger addresses temporarily pointed at the deployer for manual checkpoint calls (`tx 0xfa8b673cc70826bf13cf9bfca26c7b6a394012ccc7f794e90e579bd9e8915a4a`).
- Deployed burnable mock collections and registered base values via the aggregator:
  - `DummyOneOfOne` ERC-721 → `0x614FE9079021688115A8Ec29b065344C033f9740` (1000 pts, `tx 0x57f30df5f3e8e7df36c1d9bfdb75da9fc56f6c6b6614dcd365cb7995b922b2b2`).
  - `DummyEdition1155` ERC-1155 → `0x7Ef7dF0F64A2591fd5bE9c1E88728e59CB5D362B` (200 pts, `tx 0x93d2c68b4324eca1501117ad8acdf68960d4357b0d7391881685e29d09b3a332`).
  - `DummyERC20Burnable` → `0xD2DcB326F003DC8db194C74Db2749F8C653Df6aC` (50 pts, `tx 0x283632a9eef894c27c1a9d407881b91bc76b039f095cea281232d3a2e273213a`).
- Sanity check: awarded 100 pts to token `#3` via `directAward` (`tx 0x2e020daff4b38a6e18c87d9191a0baca72fe35d85626ae46edb905233439a2fd`). Reset with `batchSetPoints([3],[0])` if you want a clean slate before testing.

### Progress Log — Step 3 (Oct 22, 2025)

- Redeployed `PointsAggregator` → `0x471a202564FD5297781B9c362a2eC2618f662624` (via script `07_RedeployFullStack.s.sol`).
- Deployed `L1BurnCollector` → `0x9962CffFEbEb0e75ea99B00d7F73979B4D9EA58B` (via same script).
- Wired L1BurnCollector to PointsAggregator and added dummy assets (OneOfOne 1000pts, Edition1155 200pts, ERC20 50pts).
- Verified both on Sepolia Etherscan.

### Progress Log — Step 4 (Oct 22, 2025)

- **ERC20 Burn Test (Successful)**: Minted 1000 ERC20 tokens, approved L1BurnCollector, burned 50 tokens → accumulated 2500 points (50 * 50 base * 1.0 month weight).
- **ERC721 Burn Test (Failed)**: Attempted burn of OneOfOne NFT (approved, eligibleAssets shows 1000), but reverted with "asset not eligible". Possible causes: eligibleAssets not set in contract state, NFT contract issues, or bug in burn logic. Suggested checking Etherscan read contract for eligibleAssets(0x614FE9079021688115A8Ec29b065344C033f9740).
- **Local Testing Attempted**: Created test file `test/L1BurnFlow.t.sol` for local simulation, but compilation failed due to missing files in `script/archive/` and other dirs (e.g., legacy contracts, deprecated renderers). Need project cleanup for reliable local testing.

#### Next Steps & Notes
- **Debug ERC721 Issue**: Confirm eligibleAssets on Etherscan; if set, investigate NFT contract or burn code.
- **Project Cleanup**: Add `"script/archive/**"` and other missing paths to `ignored_paths` in `foundry.toml` to prevent compilation errors. Remove unused/deprecated files. This is critical for local testing and maintaining a clean repo.
- **Full L1 Flow**: Once ERC721 works, test checkpointing and ranking updates.
- **Move to L2**: After L1 is solid, implement and test L2 BurnCollectors (Base, Optimism, etc.).

### Progress Log — Step 6 (Oct 23, 2025)

- **Full Points System Redeployed on Sepolia**: Redeployed with fixed script (includes setAggregator call). Final addresses:
  - **PointsManager:** `0xb890dFc6010E457C872ABAfd344df5517742D4e9` (stores points, computes ranks)
  - **PointsAggregator:** `0x5f915d1413960865E22586fB8354F7ec01b9b3A7` (owns PointsManager, handles checkpoints)
  - **L1BurnCollector:** `0xF83630bE4A5749d9a8067Fe3f3DBCd24543aCcD4` (handles ERC721/1155/20 burns, calculates points; includes ERC1155 receiver)
  - **Dummy Assets Redeployed:**
    - ERC721 (1000 pts/burn): `0x576E4ebb4eA4Ea6c2ad7760E58Eb5B745785dE01`
    - ERC20 (50 pts/unit): `0xCC0b5B80880F8d999054E03F3e13466995ABCe86`
    - ERC1155 (200 pts/unit): `0xB4264Bb1B121B4094Df2ac0Bb91ab7a4F845B635`
- **Burn Logic Updated**: ERC721/ERC1155 use receiver callbacks; ERC20 direct transfer. Try burn, fallback to hold.
- **Ownership Chain Fixed**: PointsAggregator owns PointsManager; L1BurnCollector wired to aggregator.
- **Eligible Assets Configured**: Base values set for all dummies in L1BurnCollector.
- **Testing Status**: ERC20/ERC721 burns work (points added to E2MB token #2: 2128893958). ERC1155 pending approvals/test. All contracts verified on Etherscan.

### Progress Log — Step 7 (Oct 23, 2025)

- **Fresh Points Stack (Owned by 0xAd9f…)**:
  - `PointsManager` → `0x181feC9a1eeA7Ef5767F2E330E9C4498119995F4`
  - `PointsAggregator` → `0x7408091db99f35446254aE59a6962B015fFE528E`
  - `L1BurnCollector` → `0x0410f197Cb5b0Ce09218B1BB018401AA76859A22`
  - Updated `deployments/sepolia.json` + env exports; previous contracts marked as legacy.
- **Contract Verification**: New L1BurnCollector verified on Sepolia Etherscan (compiler 0.8.30, constructor arg = aggregator).
- **Permissions & Approvals**:
  - PointsManager/Aggregator/Collector ownership all on `0xAd9f…`.
  - Dummy OneOfOne / Edition1155 `setApprovalForAll` → new collector; dummy ERC20 allowance set to max.
- **End-to-End Burn Test (Oct 23)**:
  - Burned dummy ERC-721 → Points credited to token #3 (`6 pts`, rank → 2).
  - Burned `10,000,000,000,000` dummy ERC-20 units → token #5 (`~3.4e24 pts`, rank → 0).
  - Burned 300 dummy ERC-1155 copies → token #9 (`408 pts`, rank → 1).
  - Confirms `calculatePoints` math using October weight (68) and ERC-20 18 decimal scaling.
- **Song-A-Day Multiplier Spec**: Added 1.1× → 4× bonus tiers for holders of `0x19b703f65aA7E1E775BD06c2aa0D0d08c80f1C45` (hardcoded address) to apply pre-division.
- **Month Weights Configurable**: Exposed `setMonthWeights(uint256[12])` in L1 burn collector; document default curve `[100,95,92,88,85,82,78,75,72,68,65,60]`.
- **PointsManager Interface Fix**: Added `pointsOf(uint256)` alias so EveryTwoMillionBlocks tokenURI calls stop reverting; requires redeploy with updated bytecode.
- **ERC20 Normalization & Ratios**: L1Collector now stores per-asset decimals, normalizes ERC-20 amounts (default 18), and targets base ratios `ERC721=100,000`, `ERC1155=10,000`, `ERC20=1` ⇒ burn parity (1 × 721 ≈ 10 × 1155 ≈ 100k ERC20).
- **Step 8 (Oct 24, 2025 17:29 UTC)**: Deployed normalized stack (`PointsManager 0xE45E74bd32EEcbb17BcCe61CC933e6342EfE1561`, `PointsAggregator 0x3Ba0a0EC88c1258313cDC0DE3974F6620Fb60b7c`, `L1BurnCollector 0x1E34BE9744c9eB228999997CDef1D5038e24778e`) after fixing ERC721 receiver selector; verified collector, updated env/JSON, ready to re-run burns + metadata checks.
- **Step 9 (Oct 24, 2025 17:49–17:54 UTC)**: Continued re-redeploys chasing ERC-721 burn revert (root cause still `ERC721InvalidReceiver` from DummyOneOfOne). Multiple address updates (`PointsManager → 0xa728…`, `PointsAggregator → 0x1019…`, `L1BurnCollector → 0x7991…`) recorded; issue persists pending collector inheriting a proper ERC721 receiver (next fix: use OZ `ERC721Holder`). 
- **Step 10 (Oct 27, 2025)**  
  - Redeployed stack with configurable Song-A-Day multiplier: PointsManager `0x1F22f32DbDb96ce83B94Ef68c7de114B4966Fad1`, PointsAggregator `0x2A0449d5bC53107A781CD9d22791230899072E58`, L1BurnCollector `0x61fd3513BbEf08a3b53b86597c780cBfc83D09d1`.  
  - Added BaseBurnCollector contract plus deploy scripts (`11_DeployBaseCollector.s.sol`, `12_DeployBaseDummies.s.sol`); Sepolia/Base env now track messenger/collector/dummy addresses.  
  - Created `points-checklist.md` to document wiring/eligibility/approval checks; archived legacy addresses in `OLD-ADDRESSES.md`.  
  - Restored base ratios (ERC721=100k, ERC1155=10k, ERC20=1), verified 680-point burn on token #3, fixed `PointsManager.currentRankOf` to skip phantom token 0, noted O(n) ranking risk.  
  - Base collector patched to inherit `ERC1155Holder` (needed for queued ERC1155 burns); redeploy pending. Reminded that L1 ERC1155 burns must use `safeTransferFrom` since the collector exposes no `queueERC1155` entrypoint.

#### 🚨 CRITICAL DEPLOYMENT NOTES FOR MAINNET 🚨
- **Deployment Order (Immutable - Follow Exactly):**
  1. Deploy PointsManager (no args).
  2. Deploy PointsAggregator with PointsManager address as constructor arg.
  3. Call `pointsManager.setAggregator(aggregatorAddress)` (onlyOwner, deployer owns initially).
  4. Transfer PointsManager ownership to aggregator: `pointsManager.transferOwnership(aggregatorAddress)`.
  5. Deploy L1BurnCollector with aggregator address as constructor arg.
  6. Set L1BurnCollector in aggregator: `aggregator.setL1BurnCollector(collectorAddress)`.
  7. Deploy burnable assets (ERC721/1155/20).
  8. Add eligible assets in L1BurnCollector: `collector.addEligibleAsset(assetAddress, baseValue)` for each.
  9. Wire to main NFT: `mainNFT.setPointsManager(pointsManagerAddress)`.
- **Key Functions (Call in Order):**
  - `setAggregator(address)` on PointsManager (links agg for auth).
  - `transferOwnership(address)` on PointsManager (secures to agg).
  - `setL1BurnCollector(address)` on PointsAggregator (links collector).
  - `addEligibleAsset(address, uint256)` on L1BurnCollector (config burnables).
- **Ownership Chain:** Deployer → Aggregator → PointsManager. PointsManager requires msg.sender == aggregator for mutations.
- **Verification:** Use `forge verify-contract` with `cast abi-encode` for constructor args.
- **Common Pitfalls (Avoid These):**
  - Forgetting `setAggregator` → "Only aggregator" errors.
  - Wrong ownership transfers → Unauthorized calls.
  - Not setting eligible assets → "Asset not eligible" on burns.
  - Incorrect constructor args → Contract links broken.
- **Testing:** Use `directAward` on aggregator for test points. Verify ranks update on burns.

#### Next Steps & Notes
- **Test L1 Burns**: Mint dummies, burn them, check points/ranks update in real-time.
- **L2 Burn Collectors**: Implement Base/Optimism/Arbitrum/Zora collectors for cross-chain burns.
- **Integration with E2MB**: Wire points into tokenURI for reveal ordering.
- **Gas Optimization**: Profile and optimize for mainnet deployment.

### Manual Burn Flow Reference

1. **Mint & burn dummy assets**
   - ERC-721 (`0x614F…`): `mint(address)` → `burn(tokenId)`.
   - ERC-1155 (`0x7Ef7…`): `mintEdition(address,id,amount)` → `burnSelf(id,amount)`.
   - ERC-20 (`0xD2Dc…`): `mint(address,amount)` → `burn(amount)`.
2. **Credit points through the aggregator (`0x471a…`)**
   - Simple path: `directAward(tokenId, amount, source)`  
     Example (`tokenId=5`, `amount=200`):  
     `NO_PROXY="*" cast send 0x471a… "directAward(uint256,uint256,string)" 5 200 "721 burn" ...`
   - Checkpoint simulation: encode `(uint256[],uint256[],string[])` and call `applyCheckpointFromBase(bytes)` (or the other chain variant).  
     Example payload for tokens 5 & 6 with amounts 200 / 50 and sources `["721 burn","1155 burn"]`:
     ```
     0x0000000000000000000000000000000000000000000000000000000000000060
     00000000000000000000000000000000000000000000000000000000000000c0
     0000000000000000000000000000000000000000000000000000000000000120
     0000000000000000000000000000000000000000000000000000000000000002
     0000000000000000000000000000000000000000000000000000000000000005
     0000000000000000000000000000000000000000000000000000000000000006
     0000000000000000000000000000000000000000000000000000000000000002
     00000000000000000000000000000000000000000000000000000000000000c8
     0000000000000000000000000000000000000000000000000000000000000032
     0000000000000000000000000000000000000000000000000000000000000002
     0000000000000000000000000000000000000000000000000000000000000040
     0000000000000000000000000000000000000000000000000000000000000080
     0000000000000000000000000000000000000000000000000000000000000008
     373231206275726e000000000000000000000000000000000000000000000000
     0000000000000000000000000000000000000000000000000000000000000009
     31313535206275726e0000000000000000000000000000000000000000000000
     ```
     Cast invocation:  
     `NO_PROXY="*" cast send 0xb694… "applyCheckpointFromBase(bytes)" 0x<hex_above> ...`
3. **Observe results**
- `PointsAggregator` events: `DirectPointsAwarded`, `CheckpointApplied`.
- `PointsManager` events: `PointsApplied`.
- Read functions:  
`PointsManager.pointsOf(tokenId)`, `EveryTwoMillionBlocks.getPoints(tokenId)`, `EveryTwoMillionBlocks.getCurrentRank(tokenId)`.
    - For L1 burns: Use `L1BurnCollector` at `0x9962…` for burning, then checkpoint manually.
4. **Reset between experiments**
   - `PointsManager.batchSetPoints([tokenIds],[amounts])` (call via aggregator owner).
   - Optionally remint dummy assets for fresh burns.

---

## Architecture Overview

**Goal**: Allow holders to burn eligible NFTs on L2s (Base, Optimism, Arbitrum, Zora) or L1 (Ethereum) to earn points that affect their Millennium Song token's reveal order.

**Design Pattern**: Trust-minimized cross-chain messaging
- **L2 → L1**: Use canonical chain messengers (no relayers, no multisigs)
- **Permissionless**: Anyone can trigger checkpoint batching
- **Month weighting**: Earlier months earn more points (Jan=100, Dec=60)
- **Immediate ranking**: Points update queue order as soon as L1 message finalizes

---

## 1) L2 BurnCollector Contracts (4 total)

### 1.1) BurnCollectorBase.sol

**Location**: `src/points/BurnCollectorBase.sol`

**Chain**: Base (OP Stack)

**Messenger**: `0x4200000000000000000000000000000000000007` (L2CrossDomainMessenger)

**Key Features**:
- Accepts NFT burns via `onERC721Received()` or explicit `burnToken()`
- Calculates points: `baseValue × monthWeight / 100`
- Accumulates points per address locally
- `checkpoint(addresses[])` sends batch to L1 (anyone can call)
- Owner can add/remove eligible assets, set month weights, pause

**Events**:
- `BurnRecorded(burner, nftContract, tokenId, pointsEarned, month, timestamp)`
- `CheckpointSent(addresses, pointsDeltas, totalPoints)`

### 1.2) BurnCollectorOptimism.sol

**Location**: `src/points/BurnCollectorOptimism.sol`

**Chain**: Optimism (OP Stack)

**Messenger**: `0x4200000000000000000000000000000000000007`

**Implementation**: Same pattern as Base (OP Stack chains use identical messenger interface)

### 1.3) BurnCollectorArbitrum.sol

**Location**: `src/points/BurnCollectorArbitrum.sol`

**Chain**: Arbitrum One / Nova

**Messenger**: `0x0000000000000000000000000000000000000064` (ArbSys)

**Key Difference**: Uses `ArbSys.sendTxToL1()` instead of CrossDomainMessenger (Arbitrum's unique L2→L1 pattern)

### 1.4) BurnCollectorZora.sol

**Location**: `src/points/BurnCollectorZora.sol`

**Chain**: Zora Network (OP Stack)

**Messenger**: `0x4200000000000000000000000000000000000007`

**Implementation**: Same pattern as Base/Optimism (Zora uses OP Stack)

---

## 2) L1 Integration (MillenniumSong.sol)

**Location**: `src/core/MillenniumSong.sol`

### 2.1) New State Variables

```solidity
// Cross-chain messenger addresses
address public baseMessenger;
address public optimismMessenger;
address public arbitrumInbox;
address public zoraMessenger;

// L1 burn handling
mapping(address => uint256) public eligibleL1Assets;
uint256[12] public monthWeights;
```

### 2.2) L2 Checkpoint Receivers

Four entry points (one per chain):

```solidity
function applyCheckpointFromBase(bytes calldata payload) external
function applyCheckpointFromOptimism(bytes calldata payload) external
function applyCheckpointFromArbitrum(bytes calldata payload) external
function applyCheckpointFromZora(bytes calldata payload) external
```

**Security**: Each function validates `msg.sender` is the canonical messenger for that chain.

**Payload**: `abi.encode(address[] addresses, uint256[] pointsDeltas)`

**Logic**: Decodes payload → applies points to tokens → emits events

### 2.3) L1 Direct Burns

```solidity
function burnOnL1(
    address nftContract, 
    uint256 tokenId, 
    uint256 msongTokenId
) external
```

**Flow**:
1. User transfers NFT to MillenniumSong contract
2. Contract calculates points with month weighting
3. Points credited to specified `msongTokenId`
4. Event emitted

**Use case**: Burn Ethereum-based NFTs (e.g., Autoglyphs, Chromie Squiggles) for points

### 2.4) Admin Functions

```solidity
function addEligibleL1Asset(address nft, uint256 baseValue) external onlyOwner
function setMessengers(address _base, address _optimism, address _arbitrum, address _zora) external onlyOwner
function setMonthWeights(uint256[12] calldata weights) external onlyOwner
```

---

## 3) PointsManager Contract Overview

**Location**: `src/points/PointsManager.sol`

### 3.1) Responsibilities
- Store per-token points
- Provide ranking via `_getCurrentRank`
- Gate mutations behind `onlyOwner`
- Apply month weighting and base permutation tie-breakers

### 3.2) Ranking Algorithm Walkthrough
1. Obtain `totalSupply` from NFT
2. For each token `i` (excluding target):
   - Compare points
   - If points tie, compare `basePermutation`
   - If both tie, compare token IDs
3. Count how many tokens “come before” → rank

### 3.3) Storage Considerations
- `points[tokenId]` (`uint256`)
- `monthWeights[12]`
- Messenger addresses & eligible assets mappings

---

## 4) Burn Flow Summary

1. **Burn** on L2 → BurnCollector stores points & emits event
2. **Checkpoint** generated (callable by anyone)
3. **Message** delivered via canonical messenger to L1
4. **PointsManager** applies deltas
5. **EveryTwoMillionBlocks** reflects new rank/points instantly

---

## 5) Month Weighting Details

Default array: `[100, 95, 92, 88, 85, 82, 78, 75, 72, 68, 65, 60]`

- Stored as integers scaled by 100 for simple division
- Admin can adjust prior to finalize
- Need UTC-aware month calculation helper (pending)

---

## 6) Outstanding Work (Snapshot: Oct 7, 2025)

1. Address mapping strategy (L2 burner → tokenId)
2. Checkpoint structure & replay protection
3. Real UTC calendar math for month weights
4. Final messengers for testnet deployments
5. Testing suite (Foundry + integration)
6. Base value tables per eligible collection
7. Finalize behavior (freeze vs continue accumulating)

---

## 7) Security Checklist

- [x] Messenger origin checks
- [x] Owner-only admin functions
- [ ] Reentrancy review on checkpoint handlers
- [ ] Gas-bound batching safeguards
- [ ] Replay protection (nonce/timestamp)
- [ ] Min burn value guardrails

---

## 8) Gas Estimates (Preliminary)

| Action | Gas |
|--------|-----|
| L2 burn (ERC-721) | ~120k |
| L2 checkpoint (10 addrs) | ~220k |
| L1 apply checkpoint (10 addrs) | ~190k |
| L1 direct burn | ~150k |

*Need to validate with real calldata + Foundry traces.*

---

## 9) Deployment & Script Notes

- `script/deploy/01_DeployPointsManager.s.sol` deploys PointsManager
- Remember to call `setPointsManager` before finalize
- Burn collectors live in `src/points/`

---

## 10) Future Enhancements

- Consider Merkle-based checkpoints for large batches
- Explore per-token vs per-holder point assignments
- Add on-chain view for "top N" ranks (for UI)
- Provide off-chain indexer hints (events) for rank changes

---

_Last updated: Oct 31, 2025_
- **Step 8 (Oct 24, 2025)**  
  - Deployed new stack: PointsManager `0x23194C991a73D4da78a324546556B12BF029A734`, PointsAggregator `0x0BE9540d76B0Cc775D66bfA0b025Ad223A2B8137`, L1BurnCollector `0x2c9a0733373c612f79A21161a03C80637E9Da3bB`.  
  - Collector enhancements now live on-chain: ERC-20 normalization via decimals, UX helpers, Song-A-Day multipliers, target base ratios `721=100k`, `1155=10k`, `ERC20=1`.  
  - Updated env/JSON address exports; ready for metadata check (tokenURI should no longer revert) and fresh burn tests.
- **Step 10 (Oct 27, 2025)**  
  - Redeployed full points stack with configurable Song-A-Day multiplier: PointsManager `0x1F22f32DbDb96ce83B94Ef68c7de114B4966Fad1`, PointsAggregator `0x2A0449d5bC53107A781CD9d22791230899072E58`, L1BurnCollector `0x61fd3513BbEf08a3b53b86597c780cBfc83D09d1`.  
  - Updated scripts (`FreshPointsStack`, `RewirePointsStack`, `DeployPointsSystem`) to read `SONG_A_DAY_COLLECTION_ADDRESS`; added runtime guard so missing collections default to 1.0× multiplier.  
  - Verified wiring after redeploy (PointsManager ↔ Aggregator ↔ Collector ↔ EveryTwoMillionBlocks), and disabled Song-A-Day bonus on Sepolia by setting the collection to `0x0`.  
  - Cleaned up env/docs: moved legacy addresses into `OLD-ADDRESSES.md`, refreshed `deployed.env` / `ADDRESSES.md` / `deployments/sepolia.json`, and added a wiring checklist (`points-checklist.md`).  
  - Reconfirmed dummy eligibility + approvals, corrected base values (ERC721=100k, ERC1155=10k, ERC20=1), and successfully ran ERC721 burns that credit 680 points.  
  - Adjusted `PointsManager.currentRankOf` to start iteration at token ID 1 (avoids phantom rank offset) and noted O(n) ranking as a future scalability concern.  
- **Step 11 (Oct 28, 2025)**  
  - LayerZero Base→Sepolia path online: deployed `LayerZeroBaseReceiver 0x90EA1d07c0d4C6bB73E94444554b0217A0FABF7D`, redeployed Base collector `0x39b391dF153C252e9486e7e3990B1c74289F9950`, and updated env/docs (`deployed.env`, `ADDRESSES.md`, `OLD-ADDRESSES.md`, `points-checklist.md`).  
  - Added operational scripts for repeatable wiring: `ReconfigureBaseCollector.s.sol` (sets receiver, re-registers dummies, refreshes approvals/allowance) and `ConfigureLayerZeroReceiver.s.sol` (trusted peer upkeep).  
  - Successful cross-chain burn test on Base:  
    - ERC721 token #4 → E2MB #1 (+680 pts)  
    - ERC1155 id1 × 400 → E2MB #8 (+27,200 pts)  
    - ERC20 100,000 units → E2MB #9 (+680 pts)  
    - Checkpoint relayed via LayerZero (tx `0xf7d0…`), Sepolia `pointsOf` now `0x2a8`, `0x6a40`, `0x2a8`.  
  - Checklist expanded with LayerZero wiring commands (aggregator↔receiver, peer bytes, Base eligibility) and sanity assertions for post-redeploy smoke tests.  
  - Reveal handling discussion: keep on-chain point totals but exclude revealed tokens from future ranking; plan is to have `EveryTwoMillionBlocks` notify the aggregator on reveal, PointsManager marks `revealed[tokenId]=true`, and ranking logic skips those entries while retaining the audit trail.  
  - Next chain targets: mirror the receiver/collector flow for Optimism and Arbitrum once Base scripts are baked-in.

**Step 12 (Oct 31, 2025)**  
  - Redeployed EveryTwoMillionBlocks with VRF v2.5 request plumbing, seven-word metadata naming, and a dedicated slot for the on-chain shuffle script (`setPermutationScript`).  
  - Redeployed full points stack (PointsManager `0x8086be0A8aAa0c756C3729c36fCF65850fb00Cd1`, PointsAggregator `0xb311a1e74E558093c0F9057Ba740F9677362820e`, L1BurnCollector `0x75045e5d3052Fc2B065C52a8E32650A681fC32BD`) with seven-word gating on `addPoints`.  
  - Refreshed `deployed.env` / `ADDRESSES.md` to the new contract addresses and re-added dummy eligibility + approvals.  
  - Minted test tokens, ingested a mock permutation via new Forge scripts (`IngestPermutation.s.sol`, `InspectPermutation.s.sol`), and finalized the permutation.  
  - Added shuffle helper `fisher_yates.py` and a placeholder SSTORE2 hook for the on-chain permutation script.  

**Step 13 (Nov 1, 2025)**  
  - Resolved VRF extra-args issue by importing Chainlink’s V2.5 client; `requestPermutationSeed()` now succeeds on Sepolia (seed stored in tx `0x2a57297663613d556ff4b2a70701f4d6656e747b84a949e09e739585d77d2332`).  
  - Funded subscription `0xc1db…770dd` with native Sepolia ETH and captured the canonical permutation JSON (`OUTPUTS/permutation_20251031.json`). Ingested the first 50 entries on-chain, then finalized the permutation.  
  - Confirmed seven-word gating: `setSevenWords` immediately updates token metadata (title/description) and `addPoints` rejects tokens missing words.  
  - Rewired points stack with normalized bases (ERC721 `100k`, ERC1155 `10k`, ERC20 `1 @ 18 decimals`) at addresses PointsManager `0x1D1B77b54E654b943ab5DAD3045d324Ab61492fB`, PointsAggregator `0xbFE5C4f0c0F8F64BC44f221cd8Ee8795aB58bb1f`, L1BurnCollector `0x7dE14312de1705f824290387E7102e1C28b0dC5f`. L1 burns now credit the expected totals, and Base→Sepolia LayerZero flow still checkpoints successfully.  
  - LayerZero-backed collectors/receivers deployed for Optimism (`OP_LAYERZERO_EID=40232`) and Arbitrum (`ARB_LAYERZERO_EID=40231`); dummy assets registered on both networks with normalized bases, approvals refreshed.  
  - Redeployed PointsAggregator with multi-collector authorization; direct L1 collector plus Base/OP/ARB receivers now sit in `authorizedCollectors`. End-to-end burns verified on Sepolia (direct), Base, Optimism, and Arbitrum.  
  - Outstanding: deploy SSTORE2 permutation script and wire via `setPermutationScript`, integrate Zora bridge path, and extend production-ready wiring docs/checklists for the new receivers.  

**Step 14 (Nov 2, 2025)**  
  - Fresh end-to-end redeploy to clear pointer drift: EveryTwoMillionBlocks → `0x29025680f88f8b98097AeD6fA625894f845413DC`, PointsManager retained at `0x7538Cf5d33283FfFE105A446ED85e1FA26Aa5640`, new PointsAggregator `0xC2ed19efE6400B740E588f1019cdcb87C57694dC`, L1BurnCollector `0xaf46D12550fB5D009fb0873453C64f3fFD7B00F9`. Updated `deployed.env`, `ADDRESSES.md`, `COMMANDS.md`.  
  - Ran `03_WireRenderers`, `04_ConfigureE2MB`, `10_FreshPointsStack`, plus Base/OP/ARB reconfigure scripts to re-authorize LayerZero receivers (all now point at `0xC2ed…`, trusted peers = {Base collector `0x39b3…9950`, OP/ARB collector `0x6d06…ba67`}).  
  - Minted 50 fresh E2MB tokens, re-added dummy eligibility + approvals on Sepolia and L2 collectors, and refreshed COMMANDS.md into a comprehensive operational runbook (deploy → checks → burns).  
  - VRF flow re-run start-to-finish: added consumer, requested seed, generated `OUTPUTS/permutation_20251102.json`, ingested, `finalizePermutation()`, `finalizeRenderers()`.  
  - LayerZero burn test on Base: queued ERC721 token `#13` → E2MB `#1`. Seven-word gate enforced correctly; after committing words we still need to replay the stored payload on Sepolia with the **full** message body + native fee `0x033874cbc0eb8` (approx 5.665e13 wei). Current attempts used a truncated payload, so `PointsManager.pointsOf(1)` remains `0`. Next action: run  
    ```
    cast send $L1_LAYERZERO_ENDPOINT \
      'retryPayload(uint32,bytes32,bytes)' \
      40245 \
      0x00000000000000000000000039b391df153c252e9486e7e3990b1c74289f9950 \
      0x0000000000000000000000000000000000000000000000000000000000000060...000000000000000000000000000000000000000000000000000000000000000b424153455f455243373231000000000000000000000000000000000000000000 \
      --value 56656200994488 \
      --rpc-url $SEPOLIA_RPC_URL \
      --private-key $PRIVATE_KEY
    ```  
    using the complete payload copied from the Base `CheckpointSent` log (tx `0xd9149c3147c33764cdea94d0f6c3d4ca5702a34f0324bbf4296c417d8fdc12cd`).  
  - Documentation: expanded COMMANDS.md with wiring checks, burn recipes, payload replay instructions, and emphasized “set seven words before burning” to prevent future stuck messages.  

**Step 15 (Nov 2, 2025 — Multi-asset burn validation)**  
  - Enabled seven-word commitments for E2MB tokens `#5-#10` and ran bespoke burn tests covering every supported asset type on Base, Optimism, and Arbitrum:  
    - **Base**: queued 100× `DummyEdition1155` copies to token `#5` (tx `0x9de12f14…` → checkpoint `0x9022c6c5…`) and 100k `DummyERC20` units to token `#6` (tx `0x05bcea63…` → checkpoint `0xfc99868e…`). Points landed at `#5=6,500` / `#6=650` after LayerZero finalized.  
    - **Optimism**: burned 100× ERC-1155 to token `#7` (`0x38e9eecc…` → `0x7aef19f3…`) and 100k ERC-20 to token `#8` (`0x498c592a…` → `0x9af03864…`), confirming the OP LayerZero receiver processes payloads end-to-end (`lazyInboundNonce` advanced to 2). Totals now `#7=6,500`, `#8=650`.  
    - **Arbitrum**: mirrored tests with 100× ERC-1155 to token `#9` (`0xdb08edb2…` → `0x07ad89e4…`) and 100k ERC-20 to token `#10` (`0x3bdcc1a1…` → `0xd59832a9…`). Observed the usual few-minute bridge delay before `#10` updated to `650`; `lazyInboundNonce` now reads 3 with no stuck payloads.  
  - Each burn verified the LayerZero queue mechanics: payload hashes appear under `inboundPayloadHash` until the executor delivers, then clear automatically. No manual `clear` calls required.  
  - Updated working notes in `COMMANDS.md` to include ERC-1155/20 mint + burn recipes and the expected point deltas (ERC721=100k, ERC1155=10k, ERC20=1 @ 18 decimals × month weight 68 ⇒ 6,800 baseline, 6,500 after integer division).  
  - PointsManager totals confirm cross-chain consistency: `pointsOf(5..10) = [6500, 650, 6500, 650, 6500, 650]`, demonstrating full coverage for Base/OP/ARB collectors.  
