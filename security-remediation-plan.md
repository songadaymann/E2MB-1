# Security Remediation Plan

Consolidated from `security-concerns.md`, `secruity.md`, and the latest repo review (Nov 2025).  
**Priorities reflect the desired focus:**

- **P0 – Funds / malicious payload risk:** fixes that prevent value loss, arbitrary point minting, or untrusted code injection.
- **P1 – External compromise leverage:** issues exploitable if bridge peers, collectors, or third parties are breached.
- **P2 – Owner-op discretion:** problems that require a malicious or careless owner; still worth hardening, but lowest urgency per request.

Each item lists *impact*, *affected files*, and a concrete *task list* so we can track progress.

---

## P0 — Funds & Malicious Payloads

| # | Issue | Impact | Tasks |
|---|-------|--------|-------|
| **0.1 ✅** | **Refunds/withdrawals use `.transfer`** (`EveryTwoMillionBlocks.sol:412-437`, `LayerZeroBaseReceiver.sol:78`) | Smart-contract wallets (Gnosis Safe, Argent, etc.) cannot receive refunds or withdrawals → mint DoS / trapped ETH. | - Swapped to `call{value:}` with success checks for refunds and `withdraw()`. <br>- Wrapped payout paths in `ReentrancyGuard`. <br>- ✅ Code landed; add regression tests if missing. |
| **0.2 ✅** | **Unescaped `sevenWordsText` in metadata** (`src/core/EveryTwoMillionBlocks.sol:768-857`) | Token holders can inject arbitrary JSON/HTML → marketplace exploits or poisoned metadata. | - Added `_escapeJsonString` helper and pipe all user text through it. <br>- Locked `setSevenWords` so it can be called only once per token. <br>- ✅ Additional tests pending. |
| **0.3 ✅** | **ERC20 burns ignore transfer failures** (`src/points/BaseBurnCollector.sol:133-140`, `src/points/L1BurnCollector.sol:184-195`) | Any ERC20 returning `false` lets users mint points without paying, draining real value. | - Imported `SafeERC20` and replaced raw `transferFrom`. <br>- ✅ Need to add regression test that mocks failure. |
| **0.4** | **Burn collectors don’t guarantee destruction** (`src/points/L1BurnCollector.sol:135-195`) | Eligible NFTs/1155s that lack burn methods just sit in the collector contract while still yielding points, meaning we end up custodians of “burned” assets. | - Option A: require `burn()` calls to succeed (fail otherwise). <br>- Option B: gate `addEligibleAsset` behind a `verifiedBurnableAssets` whitelist and audit the current list for problematic collections. <br>- Add monitoring to ensure any temporarily custodied assets are periodically swept/burned. |
| **0.5** | **LayerZero peer misconfig allows fake checkpoints** (`src/points/LayerZeroBaseReceiver.sol:25-84`) | Wrong `trustedPeers` address or compromised owner can inject arbitrary points and reorder reveals. | - Store peers in a two-step process (proposed + finalized after delay/multi-sig). <br>- Prevent overwriting an existing peer without clearing the old one via multi-sig vote. <br>- Add per-peer rate limits and logging. |
| **0.6 ✅** | **PointsAggregator lacks bounds checks** (`src/points/PointsAggregator.sol:57-84`) | Any authorized collector (or compromised peer) can credit unlimited points and DOS ranking. | - Added `maxTokensPerCheckpoint` (default 100) and `maxDeltaPerToken` (default 1,000,000) plus setters. <br>- Verifies token IDs via `IRevealQueue` (when wired) and logs payload hashes. <br>- ✅ Need regression tests for oversized payloads. |
| **0.7 ✅** | **Cross-chain fee equality requirement bricks checkpoints** (`src/points/BaseBurnCollector.sol:179-226`) | If gas quotes change between `quote()` and `send()`, checkpoint transactions revert. | - `checkpoint()` now accepts `msg.value >= quoted fee`, pays the exact amount to LayerZero, and refunds the excess via safe call. <br>- ✅ Consider emitting additional telemetry if needed. |
| **0.8 ✅** | **Song-a-Day multiplier flash-loanable** (`src/points/L1BurnCollector.sol:94-134`) | Borrowing Song-a-Day NFTs for one block grants 4× multiplier with no long-term ownership. | - Added `songADayLockPeriod` (defaults to 7 days) + tracking (`songADayEligibleAfter`) so multipliers only apply after holding through the lock. <br>- Provided `registerSongADayHold()` helper so holders can start the timer proactively. <br>- ✅ Docs/UI should surface the “wait period” and new state. |
| **0.9 ✅** | **Pre-reveal registry bypasses finalization** (`src/render/pre/PreRevealRegistry.sol`, `src/core/EveryTwoMillionBlocks.sol`) | Owner could reassign the registry controller post-finalization and inject arbitrary SVG/HTML despite “frozen” renderers. | - Locked `setController` after the first call and require non-zero controller addresses. <br>- Added `controllerLocked()` reporting helper for monitoring scripts. <br>- ✅ Regression tests cover the new lock semantics. |
| **0.10 ✅** | **Invalid burns brick checkpoints** (`src/points/PointsAggregator.sol`) | A single unminted token or seven-words failure would revert the entire LayerZero delivery, stranding honest burns. | - `PointsAggregator.applyCheckpointFromBase` now skips invalid rows, logs `CheckpointEntrySkipped` events, and only credits rows that `PointsManager` accepts. <br>- Added tests covering unminted tokens, missing seven words, zero token IDs, and entry-limit handling. |
| **0.11 ✅** | **Base checkpoint drops entries when Aggregator caps trigger** (`src/points/BaseBurnCollector.sol`, `src/points/PointsAggregator.sol`) | When Base bundled >100 tokens (or >1M points for a single token) the L1 Aggregator skipped the overflow rows, but the Base collector had already deleted its queue → irrecoverable loss of honest burns + easy griefing vector. | - Mirrored `maxTokensPerCheckpoint`/`maxDeltaPerToken` on Base with owner setters and bespoke errors so `checkpoint/quoteCheckpoint` revert before clearing storage. <br>- ✅ Need regression tests that prove pending entries stay queued when callers request oversized batches. |

---

## P1 — External Compromise / Availability

| # | Issue | Impact | Tasks |
|---|-------|--------|-------|
| **1.1 (Maybe)** | **Renderer failures hidden** (`src/core/EveryTwoMillionBlocks.sol:780-817`) | Errors are silently swallowed, so bugs deploying malicious SVG/HTML can go unnoticed; also hard to debug. | - Emit `RendererError` events with the revert reason. <br>- Support a `productionMode` flag so staging throws hard reverts. <br>- Add monitoring script to alert on emitted errors. |
| **1.2** | **Month calculation drift** (`BaseBurnCollector.sol:232`, `L1BurnCollector.sol:94-107`) | Monthly weights are inaccurate, enabling mild gaming and confusing rewards. | - Replace the 30.44-day approximation with BokkyPooBah’s DateTime library or an exact lookup table. <br>- Unit test each month boundary. |
| **1.3** | **Rank computation is O(n)** (`src/points/PointsManager.sol:106-185`, `_jan1Timestamp` loop at `src/core/EveryTwoMillionBlocks.sol:1047-1054`) | As supply grows, every mint/reveal/tokenURI risks out-of-gas, leading to a practical DoS. | - Ship a scalable rank data structure (sorted lists or on-chain heap). <br>- Cache Jan 1 timestamps (or use a date lib) instead of looping per call. |
| **1.4 ✅** | **`tokenURI()` reverts after reveal** (`src/core/EveryTwoMillionBlocks.sol`, `src/points/PointsManager.sol`) | Revealed tokens called back into `PointsManager.currentRankOf`, which explicitly rejects revealed IDs, so marketplaces showed broken metadata forever. | - Added `finalRank` storage that records the beat/rank the moment the reveal finalizes (both direct + 2-step flows). <br>- `tokenURI()` now reads the cached rank for revealed tokens and only calls `getCurrentRank()` for unrevealed supply. <br>- ✅ Add tests that walk through reveal + tokenURI to guard against regressions. |
| **1.5** | **Whitelisted burn assets can’t be delisted** (`src/points/BaseBurnCollector.sol`, `src/points/L1BurnCollector.sol`) | If any eligible ERC20/721/1155 later gets rugged or becomes infinitely mintable, there is no way to remove it short of redeploying the collectors, letting attackers farm points indefinitely. | - Add an owner-only `removeEligibleAsset` (e.g., allow `_setEligibleAsset` to zero-out entries and drop them from `eligibleAssetList`). <br>- Emit a `AssetDelisted` event + expose a getter so monitoring can confirm the change. <br>- Defer implementation until current redeploy finishes, but keep tracked here. |

---

## P2 — Owner-Only Centralization Risks

| # | Issue | Impact | Tasks |
|---|-------|--------|-------|
| **2.1 (Low priority)** | **Manual VRF override** (`src/core/EveryTwoMillionBlocks.sol:205-237`) | Owner can pick a permutation seed, compromising fairness if key is malicious/compromised. | - Optional hardening; current plan is to mint/deploy via main deployer → transfer to sandboxed wallet → renounce once live. |
| **2.2 (Low priority)** | **Single-key governance** (all `Ownable` contracts) | Compromised deployer wallet = full system compromise. | - Will hand off to fresh multisig post-deploy; renounce once everything is stable. |
| **2.3 (Low priority)** | **Force reveal / global state controls** (`src/core/EveryTwoMillionBlocks.sol:482-508`) | Owner can bypass reveal schedule or mutate seeds; acceptable if transparent. | - Intent is to keep controls during rollout, then call permanent finalizers/renounce once production behaviour is verified. |

---

## Execution Checklist

1. **Create Issues or Linear tickets** for each numbered item tying to this plan.
2. **Implement + test** fixes per table above.
3. **Run regression suites** (Foundry + LayerZero staging) after each P0 change.
4. **Document** owner powers and residual risks in `docs/system-overview.html`.
5. **Schedule external review** once all P0/P1 items ship; include diff of this plan showing completed rows.

### Testing Matrix (in progress)

- Foundry unit tests for:
  - `EveryTwoMillionBlocks`: refund path (overpay/`nonReentrant`), single-call `setSevenWords`, JSON escaping helper fuzzing, renderer error events once instrumented.
  - `PointsAggregator`: bounds enforcement (too many entries, delta too large, nonexistent token IDs).
  - `BaseBurnCollector`: fee overpayment refund and date helper (month boundary cases).
  - `L1BurnCollector`: SafeERC20 usage, Song-A-Day lock period logic (`registerSongADayHold`, `_ensureSongADayTracking`, multiplier gating).
- LayerZero staging tests:
  - Base/OP/ARB burn-to-checkpoint flow covering ERC721/1155/20 assets, asserting aggregator emits the new payload hash event and `pointsOf` updates.
  - Fee volatility scenario: checkpoint submission while gas is spiking, ensuring refunds return correctly.
- VRF staging test: request + fulfill permutation seed, ingest chunk, finalize, confirm events.
- Renderer integration tests: run renderer scripts in staging to verify no `RendererError` events emitted once logging exists.
- Reveal flow tests: prepare → finalize, ensuring Song-A-Day gating doesn’t block legitimate burns and seven-word hashes match.
- Optional: fuzz `tokenURI()` with random words/renderer failures to ensure metadata stays valid JSON.

Use this file to track status (add ✅ / in-progress markers) as we knock items out.
