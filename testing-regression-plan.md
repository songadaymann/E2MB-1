# Regression & Security Test Checklist

A living checklist of the suites, scripts, and manual inspections we must run (or add) whenever touching the registry split, renderers, or the cross-chain points stack. Commands assume repo root and Foundry tooling.

---

## Prereqs

- ✅ **Deployed + wired (Nov 14/15):** `EveryTwoMillionBlocks`, `PreRevealRegistry`, countdown default slot, and Life lens adapters are already on Sepolia per `my-MDs/nov-14-redeploy.md`. Treat that snapshot as the baseline when running the scripts below.
- **Mint seed supply:** For tests that inspect ranks/reveals/points, mint at least 5–10 tokens (either via `forge script`/`cast send mintOpenEdition` or `node script/tools/mint-seed-supply.js`) so `totalMinted`, ranks, and renderer selection paths have real data.
- **Env setup:** Ensure `deployed.env` is sourced before running any command, including `PRE_REVEAL_REGISTRY_ADDRESS`, `E2MB_ADDRESS`, `BEGINNING_JS_ADDRESS`, and RPC URLs used by scripts/tests.
- **Foundry cache flag:** Append `--no-storage-caching` to every `forge test` invocation (v1.4 caching bug) so storage snapshots don’t leak between suites.
- **Points mocks:** `PointsAggregator`/collector tests expect `MockRevealQueue` or a seeded `PointsManager` to know the minted count. Keep mock inputs in sync with whatever minting script you ran.
- **OUTPUTS dir:** Keep `OUTPUTS/` writable (already whitelisted in `foundry.toml`) so countdown/Life renderer tests can emit artifacts for manual review.

---

## 0. Baseline Smoke
- `forge build --sizes` – Confirm `EveryTwoMillionBlocks` runtime stays below the 24 KB cap before/after changes.
- `forge test --no-storage-caching` – Full suite without env flags (default). Verifies the Nov‑14 registry split and renderer wiring still compile and pass.

---

## 1. Core NFT & Pre-Reveal Registry

| Target | Command | Why / Coverage |
| --- | --- | --- |
| `test/PreRevealRegistry.t.sol` | `forge test --match-contract PreRevealRegistryTest --no-storage-caching` | Seven-word gating, curator auth, controller lock, renderer fallbacks, and default slot behaviour introduced in the Nov‑14 refactor. |
| `test/RevealTransition.t.sol` | `forge test --match-contract RevealTransitionTest --no-storage-caching` | End-to-end reveal flow with the real registry + countdown renderer (Jan‑1 cadence, prepare/finalize sequencing). |
| `test/CountdownTest.t.sol` | `forge test --match-contract CountdownTest --no-storage-caching` | Guards the default renderer math/timing so slot `0` stays deterministic. |
| **[Add]** `test/EveryTwoMillionBlocks.t.sol` | `forge test --match-contract EveryTwoMillionBlocksTest --no-storage-caching` | New tests for the `.call`-based refund/withdraw logic and one-shot `setSevenWords` + `_escapeJsonString` escape hatch (P0 0.1 & 0.2). |

---

## 2. Points Stack & Burn Collectors

| Target | Command | Why / Coverage |
| --- | --- | --- |
| `test/PointsAggregator.t.sol` | `forge test --match-contract PointsAggregatorTest --no-storage-caching` | Confirms oversized checkpoints, zero IDs, seven-word rejects, and unminted tokens are skipped instead of bricking LayerZero deliveries (P0 0.6 & 0.10). |
| **[Add]** `test/BaseBurnCollector.t.sol` | `forge test --match-contract BaseBurnCollectorTest --no-storage-caching` | Mock ERC20 returning `false`, quote-vs-send fee drift, and SafeERC20 adoption (P0 0.3 & 0.7). |
| **[Add]** `test/L1BurnCollector.t.sol` | `forge test --match-contract L1BurnCollectorTest --no-storage-caching` | Song-A-Day lock period, non-burnable NFTs/1155s, and verified asset gating (P0 0.4 & 0.8). |
| **[Add]** `test/LayerZeroBaseReceiver.t.sol` | `forge test --match-contract LayerZeroBaseReceiverTest --no-storage-caching` | Peer staging/finalization, rate-limit enforcement, and replay guards once the two-step peer change lands (P0 0.5). |

> **Integration reminder:** After points-stack changes, run `./generate-test-sequence.sh` (or the latest checkpoint script) to simulate Base burns flowing through LayerZero into the Sepolia aggregator.

---

## 3. Life Lens / Tone.js Renderers

| Target | Command | Why / Coverage |
| --- | --- | --- |
| `test/pre/LifeToneHtmlRenderer.t.sol` | `forge test --match-path test/pre/LifeToneHtmlRenderer.t.sol --no-storage-caching` | Ensures EthFS-based Tone.js blobs inline correctly via `MockToneSource` and that holder metadata still embeds the mock snippet. Set `BEGINNING_JS_ADDRESS` when running CLI previews. |
| Life lens scripts | `BEGINNING_JS_ADDRESS=0x289b5441af7510F7fDc8e08c092359175726B839 BEGINNING_JS_INSTALL_BYTECODE=1 BEGINNING_JS_BYTECODE_PATH=script/data/beginning_js_mainnet_code.hex forge script script/dev/PreviewLifeToneLens.s.sol \
    --sig "preview(uint256)" 1 --broadcast 0 --no-storage-caching --fork-url $ETH_MAINNET_RPC_URL` | CLI preview that `vm.etch`es the mainnet Tone.js bytecode before rendering. Requires `ETH_MAINNET_RPC_URL` + bytecode path; omit the extra env vars to fall back to the mock tone source. |

---

## 4. Fork / External-State Checks

| Target | Command | Why / Coverage |
| --- | --- | --- |
| `test/fast-reveal/FinalizeTrace.t.sol` | `ENABLE_FINALIZE_TRACE=1 SEPOLIA_RPC_URL=$RPC forge test --match-path test/fast-reveal/FinalizeTrace.t.sol --no-storage-caching` | Replays `finalizeReveal` against Sepolia FAST_REVEAL to ensure bridge assumptions still match production state (opt-in during CI). |
| Env snapshot | `cp deployed.env deployed.env.$(date +%Y%m%d%H%M%S)` and diff | Validate on-chain addresses match the latest deploy (Nov‑14 redeploy doc). |

---

## 5. Manual Artifacts

- Inspect `OUTPUTS/countdown_test.svg`, `OUTPUTS/test-countdown.txt`, and `OUTPUTS/test-revealed.txt` generated by the countdown/reveal tests whenever SVG logic changes.
- Archive any SVG/HTML produced by renderer scripts so design review can diff animation or Tone.js payload changes.

---

## 6. Run Order Template

1. `forge build --sizes`
2. `forge test --no-storage-caching`
3. Targeted Foundry suites (sections 1–3)
4. Points integration script(s)
5. Optional Sepolia fork trace
6. Env snapshot + artifact diff

Document outcomes + links to CI logs in the deploy tracker before promoting a new build.

---

## 7. Cross-chain Manual Burn Checklist (Base / OP / Arbitrum)

Use this when verifying LayerZero collectors after any redeploy or config change.

1. **Re-source env + wiring checks**
   - `source .env && source deployed.env`
   - Run the quick calls from `points-checklist.md`:
     ```bash
     cast call $POINTS_AGGREGATOR_ADDRESS 'authorizedCollectors(address)(bool)' $BASE_L1_LAYERZERO_RECEIVER_ADDRESS
     cast call $BASE_L1_LAYERZERO_RECEIVER_ADDRESS 'aggregator()(address)'
     cast call $BASE_BURN_COLLECTOR_ADDRESS 'l1Aggregator()(address)' --rpc-url $BASE_SEPOLIA_RPC_URL
     # Repeat for OP/ARB receivers & collectors
     ```
   - Confirm `PointsManager.pointsOf(1)` etc. are low before burns so you can see deltas.

2. **Mint + approve dummy assets**
   - For each chain run the `COMMANDS.md` block (sections 5, 5a, 5b). Example for Base:
     ```bash
     cast send $BASE_DUMMY_EDITION1155_ADDRESS 'mintEdition(address,uint256,uint256)' $OWNER 1 20 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
     cast send $BASE_DUMMY_EDITION1155_ADDRESS 'setApprovalForAll(address,bool)' $BASE_BURN_COLLECTOR_ADDRESS true --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
     ```

3. **Queue burns**
   - One ERC-1155 batch per chain (or mix in ERC-20 / ERC-721) referencing distinct Millennium Song token IDs (ensure `hasSevenWords` is `true` for each target):
     ```bash
     cast send $BASE_BURN_COLLECTOR_ADDRESS 'queueERC1155(address,uint256,uint256,uint256)' $BASE_DUMMY_EDITION1155_ADDRESS 1 10 1 --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
     cast send $OP_BURN_COLLECTOR_ADDRESS   'queueERC1155(address,uint256,uint256,uint256)' $OP_DUMMY_EDITION1155_ADDRESS   1 10 2 --rpc-url $OP_SEPOLIA_RPC_URL   --private-key $PRIVATE_KEY
     cast send $ARB_BURN_COLLECTOR_ADDRESS  'queueERC20(address,uint256,uint256)'          $ARB_DUMMY_ERC20_ADDRESS        1000000000000000000 3 --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
     ```

4. **Quote + send checkpoints**
   - Always `quoteCheckpoint` first; pass the exact fee into `checkpoint` with matching token array:
     ```bash
     cast call $BASE_BURN_COLLECTOR_ADDRESS 'quoteCheckpoint(uint256[])((uint128,uint128))' '[1]' --rpc-url $BASE_SEPOLIA_RPC_URL
     cast send $BASE_BURN_COLLECTOR_ADDRESS 'checkpoint(uint256[])' '[1]' --value <nativeFee> --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
     ```
   - Repeat for OP (`[2]`) and ARB (`[3]`).

5. **Monitor Sepolia**
   - `cast logs --from-block <start> --address $POINTS_AGGREGATOR_ADDRESS 0xdc14a7c0eaad9fa8a893ebeff5a383b51da15652ccbbe676bfb9716f6d3d7ef2 --rpc-url $SEPOLIA_RPC_URL`
   - `cast call $POINTS_MANAGER_ADDRESS 'pointsOf(uint256)' <tokenId>` until the expected totals show up (Base ≈ 6,500 per 100 ERC-1155, OP same scaling, ARB ERC-20 = 650 for 1e18 @ current month weight).

6. **Stuck payload triage**
   - If totals do **not** move, use the payload replay recipe in `COMMANDS.md` (`retryPayload` on the Sepolia endpoint, copying the `CheckpointSent` log bytes and `nativeFee`).
   - Recheck `authorizedCollectors` and receiver `aggregator()` outputs—mismatched deploy snapshots are the usual cause.

7. **Document results**
   - Append tx hashes + final point totals to `points-progress.md` (new step entry) so everyone knows which collector was last validated.
   - Snapshot `deployed.env` if any addresses changed mid-test.

---

## 8. NFT Lifecycle Smoke (Mint → Reveal → Renderer Swap)

Use these manual checks after renderer or registry changes so the dev can prove the holder UX still works.

### 8.1 Minting a fresh E2MB token
1. Ensure `mintEnabled` is `true`:
   ```bash
   cast call $MSONG_ADDRESS 'mintEnabled()(bool)' --rpc-url $SEPOLIA_RPC_URL
   ```
2. If disabled, toggle as owner:
   ```bash
   cast send $MSONG_ADDRESS 'setMintEnabled(bool)' true --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```
3. Mint with a seed and some wei (use the sale price from `cast call $MSONG_ADDRESS 'mintPrice()(uint256)'`):
   ```bash
   cast send $MSONG_ADDRESS 'mintOpenEdition(uint32)' 123456 \
     --value $(cast call $MSONG_ADDRESS 'mintPrice()(uint256)' --rpc-url $SEPOLIA_RPC_URL) \
     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```
4. Verify `totalMinted` incremented and `ownerOf(newId)` equals your wallet.

### 8.2 Fast-reveal dry run
1. Set `ENABLE_FINALIZE_TRACE=1` and run the trace test (section 4).
2. On-chain sanity check:
   ```bash
   cast call $MSONG_ADDRESS 'isRevealed(uint256)(bool)' <tokenId> --rpc-url $SEPOLIA_RPC_URL
   cast send $MSONG_ADDRESS 'forceReveal(uint256)' <tokenId> --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   cast call $MSONG_ADDRESS 'isRevealed(uint256)(bool)' <tokenId> --rpc-url $SEPOLIA_RPC_URL
   ```
   (Use a test token with seven words set; confirm reveal flips to `true` and `tokenURI` returns the post-reveal payload.)

### 8.3 Renderer switch (Countdown ↔ Life Lens)
1. Confirm the registry entries:
   ```bash
   cast call $PRE_REVEAL_REGISTRY_ADDRESS 'getRenderer(uint256)((address,address,bool,bool,string,string))' 0 --rpc-url $SEPOLIA_RPC_URL
   cast call $PRE_REVEAL_REGISTRY_ADDRESS 'getRenderer(uint256)((address,address,bool,bool,string,string))' 1 --rpc-url $SEPOLIA_RPC_URL
   ```
2. Set token-level preference (seven words required):
   ```bash
   cast send $MSONG_ADDRESS 'setTokenPreRevealRenderer(uint256,uint256)' <tokenId> 1 \
     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```
3. Fetch `tokenURI(<tokenId>)` and load in a browser/onchain checker to verify the Life lens HTML replaces the countdown slot.
4. Revert to countdown by calling `setTokenPreRevealRenderer(<tokenId>, 0)` and re-check.

> Record each action (tx hash, observed output) in your test log so regressions can be bisected quickly.
