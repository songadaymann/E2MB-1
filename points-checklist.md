# Points Stack Wiring Checklist (Sepolia)

Use this before/after any redeploy so burns actually move ranks.

## 1. Environment Values (source `deployed.env`)
- `MSONG_ADDRESS`
- `POINTS_MANAGER_ADDRESS`
- `POINTS_AGGREGATOR_ADDRESS`
- `L1_BURN_COLLECTOR_ADDRESS`
- `L1_LAYERZERO_ENDPOINT` (Ethereum Sepolia endpoint v2)
- `L1_LAYERZERO_EID` (Sepolia endpoint id = 40161)
- `BASE_L1_LAYERZERO_RECEIVER_ADDRESS`
- `OP_L1_LAYERZERO_RECEIVER_ADDRESS`
- `ARB_L1_LAYERZERO_RECEIVER_ADDRESS`
- `ZORA_L1_LAYERZERO_RECEIVER_ADDRESS`
- `DUMMY_ONE_OF_ONE_ADDRESS`
- `DUMMY_EDITION1155_ADDRESS`
- `DUMMY_ERC20_ADDRESS`
- `SONG_A_DAY_COLLECTION_ADDRESS`
- `BASE_LAYERZERO_ENDPOINT` (Base Sepolia endpoint v2)
- `BASE_LAYERZERO_EID` (Base Sepolia endpoint id = 40245)
- `BASE_BURN_COLLECTOR_ADDRESS`
- `BASE_DUMMY_ONE_OF_ONE_ADDRESS`
- `BASE_DUMMY_EDITION1155_ADDRESS`
- `BASE_DUMMY_ERC20_ADDRESS`
- `BASE_CHECKPOINT_OPTIONS` (optional custom gas/options payload)
- `SEPOLIA_VRF_SUBSCRIPTION_ID`
- `SEPOLIA_VRF_COORDINATOR_ADDRESS`
- `SEPOLIA_VRF_KEY_HASH`
- `SEPOLIA_VRF_MIN_CONFIRMATIONS`
- `SEPOLIA_VRF_CALLBACK_GAS_LIMIT`
- `SEPOLIA_VRF_NUM_WORDS`

## 2. Contract Wiring
1. **PointsManager → Aggregator**  
   `PointsManager.aggregator()` MUST equal `POINTS_AGGREGATOR_ADDRESS`.
2. **Aggregator ↔ PointsManager**  
   `PointsAggregator.pointsManager()` MUST equal `POINTS_MANAGER_ADDRESS`.
3. **Aggregator → Direct L1 collector**  
   `PointsAggregator.l1BurnCollector()` MUST equal `L1_BURN_COLLECTOR_ADDRESS`.
4. **Aggregator authorized collectors**  
   `PointsAggregator.authorizedCollectors(<addr>)` MUST be `true` for each active endpoint (direct L1 collector plus any LayerZero receivers: Base, OP, ARB, Zora, etc.).
5. **LayerZero Receiver → Aggregator**  
   `LayerZeroBaseReceiver.aggregator()` MUST equal `POINTS_AGGREGATOR_ADDRESS`.
6. **LayerZero Receiver peer**  
   `LayerZeroBaseReceiver.trustedPeers(BASE_LAYERZERO_EID)` MUST equal `bytes32(uint256(uint160(BASE_BURN_COLLECTOR_ADDRESS)))`.
7. **Collector → Aggregator (direct L1)**  
   `L1BurnCollector.aggregator()` MUST equal `POINTS_AGGREGATOR_ADDRESS`.
8. **Base Collector → Receiver**  
   `BaseBurnCollector.l1Aggregator()` MUST equal `BASE_L1_LAYERZERO_RECEIVER_ADDRESS`.
9. **Base Collector peer bytes**  
   `BaseBurnCollector.l1AggregatorPeer()` MUST equal `bytes32(uint256(uint160(BASE_L1_LAYERZERO_RECEIVER_ADDRESS)))`.
10. **Collector Song-A-Day Config**  
   `L1BurnCollector.songADayCollection()` MUST equal `SONG_A_DAY_COLLECTION_ADDRESS` (or zero if intentionally disabled on testnets).
11. **EveryTwoMillionBlocks → PointsManager**  
    `EveryTwoMillionBlocks.pointsManager()` MUST equal `POINTS_MANAGER_ADDRESS`.
12. **EveryTwoMillionBlocks → PointsAggregator**  
    `EveryTwoMillionBlocks.pointsAggregator()` MUST equal `POINTS_AGGREGATOR_ADDRESS`.
13. **PointsManager → Reveal Queue**  
    `PointsManager.revealQueue()` MUST equal `MSONG_ADDRESS`.
14. **PointsManager permutation indexing**  
    `PointsManager.permutationZeroIndexed()` should match how permutation data was ingested (true if zero-indexed).
15. **Permutation status**  
    `EveryTwoMillionBlocks.permutationFinalized()` reflects whether base permutation ingest is complete.
16. **VRF config**  
    - `EveryTwoMillionBlocks.vrfCoordinator()` equals `SEPOLIA_VRF_COORDINATOR_ADDRESS`.  
    - `EveryTwoMillionBlocks.vrfSubscriptionId()` equals `SEPOLIA_VRF_SUBSCRIPTION_ID`.  
    - `EveryTwoMillionBlocks.vrfKeyHash()` equals `SEPOLIA_VRF_KEY_HASH`.

> Quick commands (after `source deployed.env && source .env`):
> ```bash
> cast call $POINTS_MANAGER_ADDRESS 'aggregator()(address)'
> cast call $POINTS_AGGREGATOR_ADDRESS 'pointsManager()(address)'
> cast call $POINTS_AGGREGATOR_ADDRESS 'l1BurnCollector()(address)'
> cast call $POINTS_AGGREGATOR_ADDRESS 'authorizedCollectors(address)(bool)' $L1_BURN_COLLECTOR_ADDRESS
> cast call $POINTS_AGGREGATOR_ADDRESS 'authorizedCollectors(address)(bool)' $BASE_L1_LAYERZERO_RECEIVER_ADDRESS
> cast call $POINTS_AGGREGATOR_ADDRESS 'authorizedCollectors(address)(bool)' $OP_L1_LAYERZERO_RECEIVER_ADDRESS
> cast call $POINTS_AGGREGATOR_ADDRESS 'authorizedCollectors(address)(bool)' $ARB_L1_LAYERZERO_RECEIVER_ADDRESS
> cast call $POINTS_AGGREGATOR_ADDRESS 'authorizedCollectors(address)(bool)' $ZORA_L1_LAYERZERO_RECEIVER_ADDRESS
> cast call $L1_BURN_COLLECTOR_ADDRESS 'aggregator()(address)'
> cast call $L1_BURN_COLLECTOR_ADDRESS 'songADayCollection()(address)'
> cast call $MSONG_ADDRESS 'pointsManager()(address)'
> cast call $MSONG_ADDRESS 'pointsAggregator()(address)'
> cast call $POINTS_MANAGER_ADDRESS 'revealQueue()(address)'
> cast call $POINTS_MANAGER_ADDRESS 'permutationZeroIndexed()(bool)'
> cast call $MSONG_ADDRESS 'permutationFinalized()(bool)'
> cast call $MSONG_ADDRESS 'vrfCoordinator()(address)'
> cast call $MSONG_ADDRESS 'vrfSubscriptionId()(uint256)'
> cast call $BASE_L1_LAYERZERO_RECEIVER_ADDRESS 'aggregator()(address)'
> cast call $BASE_L1_LAYERZERO_RECEIVER_ADDRESS 'trustedPeers(uint32)(bytes32)' $BASE_LAYERZERO_EID
> cast call $BASE_BURN_COLLECTOR_ADDRESS 'l1Aggregator()(address)' --rpc-url $BASE_SEPOLIA_RPC_URL
> cast call $BASE_BURN_COLLECTOR_ADDRESS 'l1AggregatorPeer()(bytes32)' --rpc-url $BASE_SEPOLIA_RPC_URL
> ```

## 3. Dummy Asset Eligibility
- `eligibleAssets(DUMMY_ONE_OF_ONE_ADDRESS) == 100_000`
- `eligibleAssets(DUMMY_EDITION1155_ADDRESS) == 10_000`
- `eligibleAssets(DUMMY_ERC20_ADDRESS) == 1` (plus decimals hint via `assetDecimals` if needed)
- `SONG_A_DAY_COLLECTION` (on collector) points to the correct ERC-721 and is updated if it ever changes.

Command template:  
`cast call $L1_BURN_COLLECTOR_ADDRESS 'eligibleAssets(address)(uint256)' <dummyAddress>`

## 4. Approvals / Allowance (burner wallet `0xAd9f…`)
- `DummyOneOfOne.isApprovedForAll(owner, L1_BURN_COLLECTOR_ADDRESS) == true`
- `DummyEdition1155.isApprovedForAll(owner, L1_BURN_COLLECTOR_ADDRESS) == true`
- `DummyERC20.allowance(owner, L1_BURN_COLLECTOR_ADDRESS) == 2^256 - 1`

Command template:  
`cast call <dummy> 'isApprovedForAll(address,address)(bool)' $OWNER $L1_BURN_COLLECTOR_ADDRESS`

## 5. Sanity Burn (optional)
1. Mint a dummy asset to the burner wallet (if needed).
2. Call the collector helper (`burnERC721`, `burnERC1155`, or `burnERC20`).
3. Verify `PointsManager.pointsOf(tokenId)` increments and `EveryTwoMillionBlocks.getPoints(tokenId)` matches.

---
Keep this file updated whenever addresses rotate. Remove legacy addresses from env once archived in `OLD-ADDRESSES.md`.

---

## EveryTwoMillionBlocks Wiring Addendum

Run through this after deploying or re-configuring the core NFT contract.

### Contract Addresses
- `MSONG_ADDRESS` — primary EveryTwoMillionBlocks contract.
- `SONG_ALGO_ADDRESS`, `MUSIC_RENDERER_ADDRESS`, `AUDIO_RENDERER_ADDRESS`.
- `COUNTDOWN_RENDERER_ADDRESS`, `COUNTDOWN_HTML_RENDERER_ADDRESS` (optional).

### Setup Steps (pre-finalize)
1. **Set renderers**  
   `setRenderers(songAlgorithm, musicRenderer, audioRenderer)`.
2. **Set countdown renderers**  
   `setCountdownRenderer(countdownRenderer)` and `setCountdownHtmlRenderer(countdownHtmlRenderer)` if used.
3. **Points wiring**  
   - `setPointsManager(POINTS_MANAGER_ADDRESS)`
   - `setPointsAggregator(POINTS_AGGREGATOR_ADDRESS)`
4. **Permutation ingest (if VRF complete)**  
   - Call `ingestPermutationChunk(tokenIds[], permutationIndices[])` until all entries are loaded.
   - When done, `finalizePermutation()`.
5. **Finalize renderers**  
   `finalizeRenderers()` only after every external address is correct.

### Post-Deploy Checks
- `pointsManager()` returns `POINTS_MANAGER_ADDRESS`.
- `pointsAggregator()` returns `POINTS_AGGREGATOR_ADDRESS`.
- `renderersFinalized()` false until ready to lock.
- `permutationEntryCount()` matches number of ingested indices; `permutationFinalized()` true once locked.
- `tokenURI` smoke test (pre- and post-reveal) to confirm renderers respond.
- VRF ready: `hasPermutationSeed()` reflects whether randomness landed; if false, call `requestPermutationSeed()` then wait for fulfillment.

### Reveal Flow Validation
- Prepare/force reveal a token; ensure `PointsAggregator.onTokenRevealed` is hit and `PointsManager.revealed(tokenId)` flips true.
- Confirm `getCurrentRank` no longer includes revealed token in active rankings.
- Optional: Trigger VRF request once consumer is added.  
  - `cast send $MSONG_ADDRESS 'requestPermutationSeed()' --private-key $PRIVATE_KEY --rpc-url $SEPOLIA_RPC_URL`  
  - Watch for `PermutationSeedFulfilled` event and confirm `hasPermutationSeed()` returns true.
