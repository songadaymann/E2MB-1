# EveryTwoMillionBlocks Upgrade Plan

Working notes for refreshing the core NFT contract and aligning the points stack.

## Context Snapshot (Nov 2025)

- `EveryTwoMillionBlocks` now zero-indexes `basePermutation` on mint and includes VRF request plumbing; ingestion pipeline + storage optimizations still TBD.
- `PointsManager` rank logic is O(10k) and ignores permutations/revealed flags.
- Reveal flow sets `revealed[tokenId] = true` inside E2MB only; Points stack is unaware.
- Deployment scripts cover points stack redeploys, but there is no modern E2MB deployment harness.
- Address exports live in `.env`, `deployed.env`, `ADDRESSES.md`; retired values go to `OLD-ADDRESSES.md`.

## Scope Overview

1. **Permutation Pipeline**
   - ✅ Wire VRF request/fulfillment (Chainlink v2.5) and manual override hook.
   - Add chunked permutation ingest + SSTORE2 storage; expose on-chain getters.
   - Gate ingestion behind pre-finalize checks; add `finalizePermutation()` guard.
2. **Reveal → Points Hooks**
   - Emit token reveal event (already present) and call aggregator hook to mark tokens revealed.
   - Extend PointsAggregator/PointsManager with `handleReveal(tokenId)` plumbing and active-set removal.
   - Ensure idempotency and security (only E2MB can call).
3. **Ranking Scalability**
   - Introduce sparse `activeTokens` array + index map in PointsManager.
   - Update rank computation to use active set + permutation tie-breakers.
   - Provide helper views for indexers and unit tests covering add/remove/reveal/reset flows.
4. **Deployment & Ops**
   - New Forge script to deploy E2MB + renderers + countdown + points wiring.
   - Companion maintenance scripts: VRF request, permutation ingest, reveal hook wiring.
   - Update env/address docs; archive legacy entries.

## High-Level Workstream Breakdown

### A) Contract Changes — E2MB

- [x] Define VRF seed acceptance (VRF request + manual fallback).
- [ ] Implement permutation ingestion:
  - `ingestPermutationChunk(uint256 startIndex, bytes calldata packedIndices)`
  - Store packed `uint24` per token via SSTORE2; track total written.
  - `finalizePermutation()` flips immutable flag.
- [ ] Add `getBaseQueueIndex(uint256 tokenId)` view.
- [ ] Wire reveal hook:
  - Add `pointsAggregator` address + setter (pre-finalize).
  - On reveal/finalize path, call `pointsAggregator.onTokenRevealed(tokenId)` (reentrancy-safe).
  - Emit dedicated event if helpful for off-chain sync.
- [ ] Guard reveals if permutation not finalized (optional but recommended).

### B) Contract Changes — Points Stack

- [ ] Update interfaces (`IPointsManager`, new `IPointsAggregator`).
- [ ] PointsManager:
  - Add `activeTokens`, `activeIndex`, `revealed[tokenId]`.
  - Provide `handleReveal(uint256 tokenId)` callable only by aggregator.
  - Adjust `addPoints` to register tokens that move 0→>0; handle removal on reset or reveal.
  - Revise `currentRankOf` to: iterate active tokens, apply permutation tie-breakers, append zero-point unrevealed tokens via permutation order.
  - Add helper getters + events (`TokenActivated`, `TokenDeactivated`).
- [ ] PointsAggregator:
  - Store `nftContract` address; restrict `onTokenRevealed` to that caller.
  - Forward to PointsManager and maybe emit `TokenRevealed`.
  - Ensure existing checkpoint logic remains intact.

### C) Testing & Tooling

- [ ] Expand Foundry tests:
  - Permutation ingest chunking, finalization guard, and reveal ordering.
  - PointsManager active set operations and reveal handling.
  - Integration test: simulate burn, reveal, rank queries.
- [ ] Update scripts in `script/`:
  - `DeployEveryTwoMillionBlocks.s.sol`
  - `ConfigureEveryTwoMillionBlocks.s.sol` (set renderers, points manager, countdown, aggregator)
  - `IngestPermutation.s.sol` (chunks)
- [ ] Document runbooks in `COMMANDS` or new checklist.

### D) Migration Plan

- [ ] Decide whether to redeploy E2MB or upgrade in-place (likely new deploy).
- [ ] Map out data transfer requirements (e.g., reseeding points, copying metadata).
- [ ] Update `deployed.env`, `ADDRESSES.md`, archive old addresses.
- [ ] Communicate downtime/sequence (pause burns, deploy new stack, ingest permutation, resume).

## Decisions (Nov 2025)

- VRF provider: **Chainlink**. Coordinator/keyHash for Sepolia captured below; need subscription ID + funding path when ready.
- Supply agnostic: permutation ingest must operate without advance cap — chunked writes keyed by batch length.
- Reveals may execute before permutation finalization; user messaging will warn that metadata/rank can shift once permutation locks.
- Revealed tokens **retain points** for history, but ranking skips them.
- Manual point reset helpers were test-only; plan to remove or gate them behind test builds.

## Open Questions / Decisions Needed

1. Create Chainlink VRF v2.5 subscription (Sepolia coordinator `0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B`, keyHash `0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae`); decide which wallet/key will own it.
2. Decide funding mechanism (native Sepolia ETH via `fundSubscriptionWithNative` vs testnet LINK); plan assumes native ETH per current preference.
3. Target chunk size for permutation ingest (bytes per tx) to balance gas vs calldata limits.
4. Should we pause new reveals between permutation ingestion start and finalize to avoid mid-shuffle inconsistencies?
5. Need aggregator upgrade path (existing addresses vs redeploy with new interface).

### VRF Notes (Sepolia)
- LINK token: `0x779877A7B0D9E8603169DdbD7836e478b4624789`.
- Coordinator: `0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B`.
- Key hash (500 gwei lane): `0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae`.
- Min confirmations: 3; max gas limit 2,500,000; premium 24% when paying in native Sepolia ETH.
- Action items: run `createSubscription()` (cast/forge script), fund via `fundSubscriptionWithNative{subId}(value)` using Sepolia ETH, add E2MB contract as consumer once deployed.

## Next Steps

1. Prototype `PointsManager` active set + reveal handling in tests (now that contract refactor is in place).
2. Implement E2MB permutation storage (SSTORE2 chunking) & document ingestion workflow.
3. Refresh deployment scripts (VRF-aware `04_ConfigureE2MB.s.sol` added; still need permutation ingest helper).
4. Update address docs/deployments once new contracts go live.
