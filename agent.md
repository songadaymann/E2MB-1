# Millennium Song — Concise Technical Spec (v0.9)

*Last updated: Sep 18, 2025. **Revised: Oct 22, 2025** — Crossed out outdated sections; added high-level implementation notes based on actual code in `src/`. Architecture is now highly modular with external contracts to stay under 24KB size limits. Points system includes L1 BurnCollector for symmetry.*

NOTE: I am going to use this repo to test out making very simple ethereum test contracts mainly for the purpose of seeing if we can convert the work we do in svg, python etc to solidity.

## 0) High-level Goal

An on-chain ERC-721 collection where each token represents a single “note event” in a millennium-scale composition. One token reveals per year on **Jan 1, 00:00:00 UTC**, in a queue that is:

1. **Initialized** by a one-time, provably random permutation (VRF). ~~*Not implemented yet.*~~
2. **Dynamically re-ordered** by a cross-chain **Points** system (burns on Base/Optimism/Arbitrum/Zora + L1).
3. With a tail rule: after the last token with points, **remaining zero-point tokens revert to tokenID order**.

Each token’s media and sound are generated **entirely on-chain** via a compact Markov/tonnetz algorithm (ABC + SVG + minimal audio hex). No off-chain servers.

The seed for each note is the hash of a mixture of the previous notes, the global state, the tokenID of the NFT and 7 words that the initial owner of the NFT has committed for future generations. ~~*Two-step reveal implemented in EveryTwoMillionBlocks.sol.*~~ 

---

## 1) Standards & Contracts

* **ERC-721** core (metadata via `data:` URIs).
* **ERC-165** introspection.
* **ERC-2981** royalties (5% to receiver TBD).
* **No operator filters**, no upgradeability after finalize.
* **Highly Modular Architecture**: Core NFT (`EveryTwoMillionBlocks.sol`) orchestrates external contracts to stay under 24KB limit. ~~*Original spec assumed monolithic contract; revised for modularity.*~~
* **Libraries**:

  * `SongAlgorithm` (Solidity): V3 lead (with rests) + V2 bass (no rests), phrase grammar, tonnetz neighbors, deterministic LCG RNG. Pure/view only. ~~*Implemented as external contract.*~~
  * Optional `SSTORE2` “blob” helpers for dense, immutable storage (queue permutation, large lookups). ~~*Not implemented yet.*~~
  * **External Renderers**: `MusicRenderer.sol`, `AudioRenderer.sol`, `CountdownRenderer.sol` for SVG/ABC generation. ~~*New: Modular rendering to avoid size limits.*~~

---

## 2) Roles, Lifecycle, and Finalization

* **Owner (deployer)** configures the system, wires addresses, opens/closes the open-edition sale, requests randomness, ingests permutation, and finalizes renderer wiring. Full ownership renunciation / freeze mechanics remain TBD.
* **Finalize buffer**: ~~a freeze window (e.g., \~8,000 blocks) before `finalize()` effects lock; after finalize:~~  
  *Current contract only exposes `finalizeRenderers()` (one-way). Additional freeze + ownership handoff flows are planned but not merged.*

Key flags (today):

* `mintEnabled`, `mintPrice`, `payoutAddress` (sale controls)
* `renderersFinalized`
* `permutationSeedFulfilled`, `permutationFinalized`
* `vrfRequestInFlight`, `vrfRequestId`

Events:

* `RenderersUpdated`, `RenderersFinalized`, `PermutationChunkIngested`, `PermutationFinalized`, VRF events (see §6).

---

## 3) Minting & Primary Sale (Open Edition)

* **Primary sale**: the core contract exposes an owner-gated, open-edition mint.

  * Owner toggles availability via `setMintEnabled(bool)` and sets price with `setMintPrice(uint256)`.
  * Collectors call `mintOpenEdition(uint32 seed)` (payable) while the sale is enabled. Payment above the set price is refunded; underpayment reverts. Sale duration / cap are TBD (currently manual).
  * Owner can still airdrop or reserve supply via `mint(address,uint32)` regardless of sale state.
  * Proceeds accumulate on the contract; owner withdraws to a configured payout wallet through `setPayoutAddress` + `withdraw()`.

* **Supply**: unbounded during the sale window (true open edition). Total minted count is tracked on-chain (`totalMinted`).

* **Post-sale sequencing** (same as before):

  * Request randomness (VRF) when ready.
  * **Ingest permutation** once (maps tokenId → `baseQueueIndex`). Current implementation stores permutation values directly in `basePermutation`; an SSTORE2 blob remains a future optimization (see §6 / §10).
  * Reveal order stays dynamic via the **Points overlay** in §5.

---

## 4) Reveal Schedule (Time-based)

* **Canonical time**: `block.timestamp`. No dependence on blocks/second.
* **Reveal date per rank**:
  `revealYear(rank) = startYear + rank` (rank is 0-indexed in the **current** dynamic order; `startYear = 2026`).
* **Reveal condition**:
  `isRevealed(tokenId) := (now >= Jan 1, 00:00:00 UTC of revealYear(rank(tokenId)))`.
* Utility: a tiny **UTC date helper** or a precomputed mapping `year → unix_ts_Jan1` stored once (few hundred bytes).

---

## 5) Dynamic Ordering via Points (Cross-chain Burns)

### 5.1 Intent

* **Immediate re-ranking**: if a holder’s Points increase enough to overtake others, their token(s) **move forward in the queue immediately** (subject to L2→L1 message finalization).
* **Tie / tail rule**: tokens with Points > 0 always sort ahead. Ties first compare VRF `baseQueueIndex`, then tokenId. Zero-point tokens stay in VRF order (with revealed IDs removed), effectively matching the original shuffle until they earn points.

### 5.2 Point Accrual (Shape defined, math TBD)

* **Action**: burning eligible assets on L2s (Base/Optimism/Arbitrum, extendable).

* **Monthly weighting** (within each calendar year): **earlier months earn more**; later months earn fewer Points.

  * Example shape (TBD exact values): `weight(Jan)=1.0, Feb=0.95, …, Dec=0.60`.
  * **Important**: **existing Points do not decay**; the weight affects **new Points earned** at the time of burn.

* **Scoring**:
  Points credited per burn = `baseValue(asset) * monthWeight(burnMonth) * optionalMultipliers`.
  *Song-A-Day holder bonus*: if the burner holds NFTs from `Song A Day` (`0x19b703f65aA7E1E775BD06c2aa0D0d08c80f1C45`) at the moment of burn, apply a fixed multiplier tier before division:
    * ≥1 token → ×1.1
    * ≥10 tokens → ×2.0
    * ≥50 tokens → ×3.0
    * ≥100 tokens → ×4.0
  Compute the highest applicable tier per burn. (Cap tiers once applied; we may revisit stacking/decay later.)
  When registering ERC-20 assets, record their decimals (default 18) so the collector normalizes `amount / 10^decimals` before scoring. NFTs keep decimals = 0 (raw counts).
  Month weighting is owner-configurable on L1/L2 collectors via `setMonthWeights(uint256[12])` prior to finalization; defaults to `[100,95,92,88,85,82,78,75,72,68,65,60]` (Jan → Dec).

* **Cross-chain consistency**: burn timestamps (L2) must be relayed to L1 to compute the month weight truthfully (see below).

* **Seven-word gate**: tokens must record their seven-word commitment before points accrue. `PointsManager` rejects burns for any token lacking `hasSevenWords(tokenId) == true`, ensuring the lyrical prompt is locked prior to ranking incentives.

### 5.3 Cross-chain Architecture (Trust-minimized, on-chain)

* **Per-L2 BurnCollector** contracts (Base, Optimism, Arbitrum for v1; Zora reserved for later):

  * Each chain runs the shared `BaseBurnCollector` implementation: records burns, normalizes asset amounts, applies month weights, and stores deltas per Millennium Song token.
  * When operators call `checkpoint(tokenIds[])`, the collector packages the pending deltas and relays them to Sepolia via **LayerZero v2**. Endpoint configuration is unique per chain, but the payload shape matches the L1 collector (tokenIds, deltas, sources).
  * Collectors can be extended with additional eligible assets or decimals hints without redeploying; Song-A-Day multipliers apply on every chain.

* **L1 BurnCollector** (for Ethereum L1 burns):

  * Symmetric to L2 collectors: Records L1 burns (e.g., Autoglyphs), accumulates points locally with month weighting.
  * **No bridging**: Directly checkpoints to L1 PointsAggregator (local call).
  * Allows burning Ethereum-based NFTs without transferring to main NFT contract.
  * Exposes `setMonthWeights(uint256[12])`, `getEligibleAssets()`, `monthWeightsArray()`, and `estimatePoints(asset, amount, burner)` for front-end UX.
  * Base value ratio target (normalizing ERC-20 amounts by token decimals):  
    `ERC721 base = 100,000`, `ERC1155 base = 10,000`, `ERC20 base = 1` ⇒  
    Burning **1** ERC721 ≈ **10** ERC1155 ≈ **100,000** ERC20 tokens (before month weighting & Song-A-Day multipliers).

* **Bridge to L1** (Sepolia staging / Ethereum mainnet target):

  * LayerZero receivers (one per L2) live on Sepolia alongside the core contracts. They verify source endpoint + peer bytes, then forward payloads into `PointsAggregator.applyCheckpointFromBase`.
  * `PointsAggregator` maintains an `authorizedCollectors` list covering the L1 collector plus each LayerZero receiver, so only trusted relays can credit points.
  * Finality matches LayerZero settlement for the respective rollup. Once the message lands, ranks update immediately (subject to §5.4).
  * **Fallback note (TBD)**: we may add an off-chain queue + Chainlink keeper path that batches burns in a database and submits consolidated checkpoints when bridges are unhealthy. Current production flow is 100% on-chain via LayerZero.

* **L1 Aggregator**:

  * Canonical **Points ledger** (per token or per owner → token mapping; choose one):

    * **Per-token** Points (current implementation): cleaner for queue math and resilient to transfers.
    * **Per-owner** Points that apply to the **token they choose** would require an assignment step (no longer planned for v1).
    * Aggregator also receives reveal notifications from the NFT (`onTokenRevealed`) so `PointsManager` can freeze ranks for revealed IDs.
  * **Immediate re-rank**: after each applied delta, the queue rank is recomputed (see §5.4) and `RankChanged(tokenId, oldRank, newRank)` can be emitted in batches.

### 5.4 Rank Computation

* **Inputs**:

  * `baseQueueIndex[tokenId]` (VRF permutation; tiebreaker baseline)
  * `points[tokenId]` (L1 Aggregator)
* **Ordering**:

  1. **All tokens with points > 0**, sorted by:

     * **points DESC**,
     * tie → **baseQueueIndex ASC** (VRF order),
     * tie → **tokenId ASC** (final tie).
  2. **All tokens with points == 0**, sorted by **baseQueueIndex ASC** (VRF order), tie → **tokenId ASC**.
* **Rank usage**: determines revealYear and `isRevealed()`.

> Implementation notes:
>
> * Keep live ranks as **view-computed** from on-chain arrays (avoid O(n) writes). For large N, store two ordered lists in SSTORE2 and update compactly with deltas (advanced optimization; v1 may recompute ranks in view for simplicity).
> * In `tokenURI()`, compute the **current** rank on the fly (bounded loops only; use indexed structures).

---

## 6) Randomness & Permutation

* **One-time** randomness draw (Chainlink VRF v2.5 recommended) after the primary sale closes and before renderers are finalized.
* Create a **full permutation** of `1..totalSupply` → `baseQueueIndex[tokenId]` using Fisher-Yates with the VRF seed.
* Today the permutation lives in the `basePermutation` mapping; a future upgrade will mirror the data into an **SSTORE2** blob referenced by `permutationScript` for cheaper reads and proofs.

  * Event: `RandomnessRequested(reqId)`, `RandomnessFulfilled(seed)`, `PermutationIngested(totalSupply)`, `PermutationFinalized()`.

---

## 7) Token States & Pre-reveal Modes

* Pre-reveal → holder may choose a **display mode** (enum, 2–3 bits per token):

  * **Ideas (TBD exact):**

    * **Countdown clock** to their reveal year.
    * **Game of Life** animation (pure SVG/SMIL; no JS).
    * **Minimal waveform** or **lissajous** seeded by tokenSalt.
    * **“Markov heatmap”**: small visualization of recent chord movement likelihoods.
    * etc.
* Mode is **changeable by owner until reveal**; locked after reveal.

---

## 8) On-chain Media & Rendering

* **Music generation**: `SongAlgorithm` (Solidity), V3 lead with rests + V2 bass without rests. Deterministic LCG, phrase grammar (A, A’, B, A, A’, C, A), tonnetz neighbors.

  * `generateBeat(beat, tokenSeed) → (leadEvent, bassEvent)`
  * `generateAbcBeat(beat, tokenSeed) → string`

* **SVG (primary image)**:

  * Pre-reveal: chosen mode’s SVG. Favor **SMIL** animations to show time-based progress (e.g., countdown arc).
  * Post-reveal: musical staff rendering of the generated events; optional style changes over time (`block.timestamp` or seasonal palette).

* **ABC (secondary media)**:

  * Exposed in `animation_url` as `data:text/plain;base64,<abc>`.

* **Audio (v1 minimal)**:

  * Tiny PCM/WAV hex for a short beep/chord per event (keep byte budget modest). Ship at v1 if feasible without gas spikes; otherwise make it a v1.1 toggle.

* **Metadata** (`data:application/json;base64`):

  * **Primary**: `"image"` = SVG data URI.
  * **Secondary**: `"animation_url"` = ABC data URI (and/or small audio data).
  * **Attributes** (initial set; expand later):

    * `Year` (target reveal year)
    * `Queue Rank` (current)
    * `Points` (current)
    * `PreRevealMode`
    * `LeadPitch`, `LeadDur`, `BassPitch`, `BassDur` (for current beat)
    * `Root`, `Quality` (current chord)

---

## 9) Contract Surfaces (selected)

### ERC-721 Core (EveryTwoMillionBlocks.sol)

* `mintOpenEdition(uint32 seed)` — payable open-edition mint (requires `mintEnabled` and `msg.value >= mintPrice`).
* `mint(address to, uint32 seed)` — owner-only reserve / airdrop path.
* Sale controls: `setMintEnabled(bool)`, `setMintPrice(uint256)`, `setPayoutAddress(address payable)`, `withdraw()`.
* Prompt gating: `setSevenWords(uint256,string)`, `hasSevenWords(uint256)`.
* Reveal flow: `prepareReveal(uint256)`, `finalizeReveal(uint256)`, `cancelReveal(uint256)`, `forceReveal(uint256)` (owner testing).
* Metadata / ranking: `tokenURI(uint256)`, `getCurrentRank(uint256)`, `getPoints(uint256)`.

### Configuration

* Renderers: `setRenderers(address,address,address)`, `setCountdownRenderer(address)`, `setCountdownHtmlRenderer(address)`, `finalizeRenderers()`.
* Points stack: `setPointsManager(address)`, `setPointsAggregator(address)`.
* VRF: `configureVRF(...)`, `requestPermutationSeed()`, `setPermutationSeedManual(bytes32)`.
* Permutation ingest: `ingestPermutationChunk(uint256[],uint256[])`, `finalizePermutation()`.
* Misc: `setGlobalState(bytes32)` (testing hook), `setPermutationScript(address)` (future SSTORE2 pointer).

### Points & Ranking (PointsManager.sol + PointsAggregator.sol)

* **PointsManager**: `addPoints(uint256,uint256,string)` (aggregator only), `currentRankOf(uint256)`, `pointsOf(uint256)`, `setAggregator(address)`, `setRevealQueue(address)`, `setPermutationZeroIndexed(bool)`, `handleReveal(uint256)`.
* **PointsAggregator**: `applyCheckpointFromBase(bytes)` (called by L1 + LayerZero receivers), `setL1BurnCollector(address)`, `setAuthorizedCollector(address,bool)`, `setNftContract(address)`, `directAward(uint256,uint256,string)`, `onTokenRevealed(uint256)`.
* **Collectors**: `BaseBurnCollector` (on Base/OP/ARB) exposes `queueERC721/1155/20`, `checkpoint(uint256[])`; `L1BurnCollector` mirrors burns directly on Sepolia/Ethereum.

Key events of interest:

* `MintStatusUpdated`, `MintPriceUpdated`, `PayoutAddressUpdated`
* `PermutationChunkIngested`, `PermutationFinalized`, `PermutationSeedRequested`, `PermutationSeedFulfilled`
* `RenderersUpdated`, `RenderersFinalized`
* Points stack: `PointsApplied`, `CheckpointApplied`, `TokenActivated/Deactivated/Revealed`, `DirectPointsAwarded`

---

## 10) Storage & Data Structures (gas-aware)

* Global sale / config:

  * `totalMinted`, `mintEnabled`, `mintPrice`, `payoutAddress`
  * External addresses: `songAlgorithm`, `musicRenderer`, `audioRenderer`, `countdownRenderer`, `countdownHtmlRenderer`, `pointsManager`, `pointsAggregator`, `permutationScript`
  * VRF params: `vrfCoordinator`, `vrfKeyHash`, `vrfSubscriptionId`, `vrfMinConfirmations`, `vrfCallbackGasLimit`, `vrfNumWords`, `vrfRequestInFlight`, `vrfRequestId`
  * Booleans: `renderersFinalized`, `permutationSeedFulfilled`, `permutationFinalized`
  * Counters: `permutationEntryCount`, `permutationChunkCount`
* Per-token:

  * `tokenSeed (uint32)`
  * `basePermutation[tokenId]` (uint256) — VRF order (0-indexed)
  * Reveal state: `revealed`, `revealBlockTimestamp`, `revealPending`, `pendingBeat`, `pendingWords`
  * Music cache: `revealedLeadNote`, `revealedBassNote`
  * Prompt data: `sevenWords` (hash), `sevenWordsText`
* Global reveal context:

  * `previousNotesHash`, `globalState`
* Aggregator-side (PointsManager):

  * `points[tokenId]`, active set arrays, `revealedTokens`
  * Flags: `aggregator`, `revealQueue`, `permutationZeroIndexed`

---

## 11) Security, Integrity, and Constraints

* **Admin trust**: today the owner key can toggle the sale, adjust prices, and re-point renderers/points until `finalizeRenderers()` is called. A fuller `freeze/finalize` sequence (ownership renounce, parameter lock) is still on the roadmap.
* **VRF**: randomness requested once per deployment. Manual seed setter exists for testnets; production relies on Chainlink v2.5 fulfillment.
* **Cross-chain**: LayerZero receivers enforce `(srcEid, peer)` checks before forwarding to the aggregator. `PointsAggregator` keeps an `authorizedCollectors` allowlist so only trusted collectors/receivers can add points.
* **Seven-word gate**: enforced by `PointsManager` to prevent points accrual before prompts are committed.
* `tokenURI()`:

  * Pure/view only, generates metadata entirely on-chain through external renderer contracts.
  * SVG output is deterministic and bounded; aim to stay ≤150k gas when nodes execute the call.
* **Reentrancy**: sale/reveal functions rely on standard modifiers (`nonReentrant` not required currently, but payable mint uses checks-effects-interactions + refund).
* **Time calculations**: Jan 1 00:00:00 UTC per rank; `_jan1Timestamp` iterates year-by-year (could swap to lookup table later).

---

## 12) Gas & Performance Targets (v1)

* `mintOpenEdition`: target 110–150k gas (includes seed assignment + safe mint).
* `prepareReveal` + `finalizeReveal`: split heavy ranking (view) from music generation; finalize path stores two events and updates hashes.
* `tokenURI()` view: ≤150k gas worth of computation under typical node limits.
* Points checkpoint apply (batch): O(k) for k deltas; LayerZero payload size is the practical bound. Future optimizations could Merklize payloads or compress sources.

---

## 13) Testing Plan (minimum)

* **MusicLib parity**: deterministic vectors vs. Python for 100+ beats, seeds {1,2,3,42,12345}.
* **Permutation**: Fisher-Yates reproducibility with VRF seed; distribution sanity checks; ensure `basePermutation` matches emitted seed.
* **Sale controls**: toggle `mintEnabled`, enforce price / refund logic, exercise owner airdrop + payout withdrawal.
* **Ranking**:

  * Confirm zero-point tail mirrors VRF order (with revealed IDs removed).
  * Introduce Points to a subset; verify tie-breakers (points desc → VRF order → tokenId).
  * Apply month-weighted deltas across epochs; verify monotonicity and immediate re-ordering.
  * Assert burns for tokens missing seven words revert.
* **Reveal**:

  * Boundary at Jan 1 00:00:00 UTC; off-by-one and leap-year tests.
  * `isRevealed()` flips only at/after boundary.
* **Cross-chain**:

  * Mock messengers for Base/OP/Arb; reject non-authorized senders.
  * Batched payloads with mixed months; weights applied correctly.
* **Finalize**:

  * `finalizeRenderers()` blocks further renderer/points changes; add regression tests once broader finalize flow exists.

---

## 14) Roadmap & TBDs

* **Points math**:

  * Final month weighting function & baseValue tables per burnable asset.
  * Optional multipliers (e.g., 1/1 ownership).
* **List of pre-reveal modes** and visuals (exact SVG/SMIL behaviors).
* **Audio v1** byte budget & encoding profile.
* **Royalty receiver** address; **license** text.
* **Per-token vs per-owner Points**: spec currently uses **per-token** with `assignPoints(tokenId)`; confirm UX.
* **Exact VRF provider/version** and config (subID, keyHash).
* **Permutation + rank caching** strategies if supply is large and ranking queries become heavy.

---

## 15) Developer Notes

* Keep `SongAlgorithm` bytecode small: prefer algorithmic tables over large constants, and SSTORE2 for any sizeable static blobs.
* If needed, expose a **read-only rank iterator** for off-chain indexers to mirror ordering.
* `animation_url` can later return a self-contained HTML/ABC viewer (still a `data:` URL) once byte budgets are comfortable.

---

### TL;DR Flow

1. Deploy EveryTwoMillionBlocks + PointsManager + PointsAggregator + L1/L2 BurnCollectors; wire addresses.
2. Configure price + payout, enable open-edition mint, and keep it live for the desired window (owner mints handle airdrops/reserves).
3. Draw VRF → ingest permutation (still mapped in-contract; SSTORE2 packing TBD).
4. Call `finalizeRenderers()` once all external addresses look good (full freeze/renounce flow still TBD).
5. Ongoing: L1/L2 burns → checkpoints → Points updates → queue reorders immediately.
6. Each Jan 1 UTC: next token in current order reveals; on-chain media (SVG+ABC+audio) updates via `tokenURI()`.

---

If you want this turned into a repo skeleton (contracts, mocks for Base/OP/Arb messengers, and a Hardhat test suite with Python parity vectors), I can generate it next.
