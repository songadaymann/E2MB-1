# Dav's Lens Renderer — Progress Notes

## Snapshot (Nov 3, 2025)

Friend's deployed stack exposes a modular "lens" renderer for pre-reveal NFTs. Contracts in scope:

- `beginning` (0x6B7E07cE896c7DFfDC936BAe8060A0F7fF71A3b2)
- `beginningJS` (0x289b5441af7510F7fDc8e08c092359175726B839)
- `lens_init` (0x57c8D600F80AA5334437c71848efD509C09290e9)
- Shared deps: `IT0neV1`, `IN0tesV1`, EthFS `IFileStore` (Tone.js gzip bundle + gunzip helper), `Base64`, `LibString`

### Core Concepts

1. **Renderer Hub (`beginning`)**
   - Owns the metadata entry point (`tokenURI`).
   - References external modules:
     * `ISVG` → builds the `<svg>` image using lens-supplied text/colors/layout.
     * `IJavaScript` → assembles the audio/interaction script.
     * `IFileStore` → pulls Tone.js assets from EthFS (`toneString`, `gunzipScripts-0.0.1.js`).
     * `ILensAlgorithm` (optional) → algorithmic lens selector.
   - Maintains current lens selection + optional delegation. Changing lenses triggers `tokenContract.refreshMetadata(1)`.
   - Lens slots stored in `mapping(uint => ILens) lenses` with IDs tracked in `lensIds`.

2. **Lens Contracts (`ILens`)**
   - Provide structured data: note arrays, synth parameters, effect chains, color palette, SVG layout values, and an arbitrary `text()` string.
   - Example `lens_init` fills arrays manually; `text()` returns current owner address via `LibString.toHexString`.

3. **JS / Audio Renderer (`beginningJS`)**
   - Pulls active lens via `mainRenderer.lenses(mainRenderer.currentLens())`.
   - Uses helper contracts to generate Tone.js setup:
     * `IN0tesV1` → sequences of notes.
     * `IT0neV1` → synth definitions, effect chains, LFO code, Panner/Filter/Delay helpers, etc.
   - Returns a giant `<script>` string embedded in HTML alongside the SVG.

4. **EthFS File Store**
   - Tone.js and the gunzip helper live as bytecode slices accessible via `IFileStore.getFile(name).read()`.
   - Renderer concatenates them inline (`<script type="text/javascript+gzip" …>`).

### Integration Opportunities for Millennium Song

- **Alternate Pre-Reveal Mode**: Wrap the renderer hub so `tokenURI` defers to a lens instead of the countdown. Gives holders a music-on-hover, animated SVG experience.
- **Lens Selection UX**:
  * Manual: holders set `currentLensVar` (or per-token mapping) via on-chain call.
  * Algorithmic: plug in our own `ILensAlgorithm` that rotates lenses by rank/time.
  * Delegation: adopt the existing `lensControlDelegated` pattern so holders can assign a curator.
- **Community Lens Registry**: generalize owner-only `updateLenses` into a registry contract:
  * Accept user-submitted `ILens` addresses (whitelisted or permissionless with guardrails).
  * Store metadata about lens creator, required dependencies, etc.
- **Per-token Generalization**: current code assumes token ID == 1. To integrate we must:
  * Replace single `currentLensVar` with `mapping(uint256 => uint256) currentLens`.
  * Swap `tokenContract.refreshMetadata(1)` for our own hooks (or remove and rely on frontend polling).
  * Ensure lens info is queryable per token (`tokenToTraits` should emit the active lens for that token).
- **Audio/Visual Customization**: Use lens data to surface Millennium Song state:
  * `text()` could incorporate seven words, queue rank, or reveal timestamp.
  * `colors()` could reflect points/season.
  * Note arrays could be derived from our `SongAlgorithm` seed instead of static tables.
- **Safety Considerations**:
  * Malicious lens could inject harmful HTML/JS. Add sanitization or an allowlist.
  * Gas usage: lens arrays are sizable; keep loops bounded and consider caching.
  * Tone.js bundle size: ensure EthFS files exist on chosen network (Sepolia/Mainnet) and remain stable.

### Next Steps / Questions

1. Fork `beginning` to `MillenniumLensRenderer` with per-token support and our NFT address.
2. Decide on open lens registry vs curated list. Implement guardrails for user-submitted lenses.
3. Audit helper contracts (`IT0neV1`, `IN0tesV1`, EthFS files) and redeploy under our namespace if needed.
4. Prototype a Millennium-specific lens (`lens_msong`) that pulls data from PointsManager / SongAlgorithm.
5. Design holder UX: contract calls vs. delegated signer vs. off-chain UI.
6. Define fallback behavior—if selected lens reverts, fall back to countdown renderer.

---
### Update (Nov 6, 2025)
- Ported Life lens into deployable contracts:
  * `LifeLensInit` now mirrors the true Millennium Song seed recipe (`tokenSeed`, seven-word hash, `previousNotesHash`, `globalState`) and returns the on-chain base seed, rank, total supply, and reveal timestamp along with the Life grid + SongAlgorithm clips.
  * `LifeLensRenderer` builds full JSON/SVG/HTML metadata with deterministic chaos scaling and audio script; fallback refresh hook works with E2MB.
  * Added adapters (`LifeLensSvgRenderer`, `LifeLensHtmlRenderer`) that conform to `ICountdownRenderer` so E2MB can call the Life renderers through its existing countdown hooks.
- Added a preview/decode script (`script/dev/PreviewLifeLens.s.sol`) plus lightweight base64 helpers in the tests so we can inspect the minted HTML locally.
- Deployed on Sepolia:
  * `LifeLensInit` @ `0x51F5B9d37A7D9e22b34177D8bB7Ef644C1c1583B`
  * `LifeLensRenderer` @ `0xd1A18f8799c8F05c24DA20254A94F3B478F1AFe9`
  * `LifeLensSvgRenderer` @ `0xE9E70556C0a4a67d6a20706aB56DDEF342C4Bd6d`
  * `LifeLensHtmlRenderer` @ `0xEB2E9AFE3Bd5a1711971cdd9bB31173b6CE28834`
- Wiring script (`WireLifeLens.s.sol`) reuses the adapters to update E2MB’s pre-reveal renderers, but the current production contract has `renderersFinalized = true`, so we cannot repoint the countdown without a redeploy.

---
### Next Steps

1. **Upgrade E2MB pre-reveal system**
   - Add a `PreRevealRenderer` registry (SVG + HTML pairs) with slot `0` seeded to the existing countdown.
   - Allow the owner to register additional renderer pairs while tokens remain unrevealed (`addPreRevealRenderer`, `updatePreRevealRenderer`, `setDefaultPreRevealRenderer`).
   - Surface a `setTokenPreRevealRenderer(tokenId, rendererId)` function gated to owners/approved operators so holders can pick Life vs Countdown (revert if token is revealed and when renderer inactive).
   - Maintain a `tokenPreRevealChoice` mapping plus events so frontends can subscribe.
   - Keep existing `setCountdownRenderer`/`setCountdownHtmlRenderer` as thin wrappers that mutate renderer slot `0`.

2. **Redeploy EveryTwoMillionBlocks (testnet staging first)**
   - Re-run scripts to wire SongAlgorithm, countdown slot 0, VRF config, permutation ingestion, and Points stack.
   - Register Life lens adapters in the new registry; ensure default remains countdown so current UX doesn’t regress.

3. **Expose selection UX**
   - CLI script + basic frontend snippet that lets a holder call `setTokenPreRevealRenderer`.
   - Optional: add getter endpoints (`getPreRevealRenderer(uint256)`, `getTokenPreRevealRenderer(uint256)`) for indexers.

Once the new E2MB is live with the registry, we can point tokens at the Life lens without a full contract redeploy and keep onboarding additional lenses as they’re built.

---
### Implementation Snapshot (Nov 7, 2025)
- `EveryTwoMillionBlocks` now exposes a registry-backed pre-reveal system:
  * Slot `0` is still countdown but lives inside `preRevealRenderers[0]`; the owner can add/update slots indefinitely (until optionally calling `freezePreRevealRegistry()`).
  * Holders pick renderers through `setTokenPreRevealRenderer(tokenId, slotId)` (or reset to default via `clearTokenPreRevealRenderer`). Rendering automatically falls back to slot `0` if a custom slot reverts.
  * View helpers: `getPreRevealRenderer(id)` and `getTokenPreRevealRenderer(tokenId)` plus public `tokenPreRevealChoice`/`tokenPreRevealChoiceSet`.
- Added targeted tests (`test/PreRevealRegistry.t.sol`) that cover registry writes, holder overrides, and fallback logic. Existing reveal transition tests now wire the countdown slot before exercising the state machine.
- `script/dev/WireLifeLens.s.sol` registers the Life lens adapters as a new slot instead of overwriting countdown; CLI docs list the accompanying `cast` commands for slot management and holder walkthroughs.
- `forge test` successfully runs the unit suites (`PreRevealRegistryTest`, `CountdownTest`, `RevealTransitionTest`, `LifeLensRendererTest`). Running the `FinalizeTrace` fork test still requires a funded RPC endpoint; it now no-ops when `SEPOLIA_RPC_URL` is unset.

*Next milestone: redeploy E2MB + wire slot 0 (countdown) + Life lens slot N on Sepolia, publish the renderer IDs, then hand operators an Etherscan walkthrough for holders who want to opt in.*

---
### Field Test / UX Polish (Nov 8, 2025)
- Deployed a fresh Sepolia `EveryTwoMillionBlocks` (0xAd82…) using the registry build, re-wired SongAlgorithm/countdown, registered the Life adapters as **slot 1**, and minted the first 50 staging tokens via `script/tools/MintBatch50.s.sol`.
- Verified on-chain that holders can opt into Life by calling `setTokenPreRevealRenderer(tokenId, 1)`—token 1’s metadata successfully flipped after a manual `cast` call + `tokenURI` refresh. Etherscan verification (`forge verify-contract ...`) is complete so we can lean on the write tab for future tests.
- Reworked the Life visuals/audio shell to match the countdown footprint: `LifeSVG` now renders a 72px grid of rounded rects (no glyph overlay), the HTML wrapper just centers the SVG, and the animation script only toggles opacity/scale while retaining the existing WebAudio synth.
- Added CLI instructions in `COMMANDS.md` under section **1.5** so operators and holders know how to register slots, set defaults, and opt tokens in/out. Slot 0 remains countdown; slot 1 is Life; future slots (e.g., Dav’s Tone.js renderer) can be layered on without another redeploy.
- Next steps before shipping to production:
  * **Redeploy (v2) on Sepolia:** bake the new Life renderer contract addresses into slot 1 by running `01_DeployRenderers` (only if bytecode changed), `02_DeployMain`, `03_WireRenderers`, and `WireLifeLens` in sequence. Update `deployed.env`/`ADDRESSES.md` with the slot 1 IDs and re-mint a small batch for QA.
  * **Tone.js slot (slot 2):**
    1. Upload Tone.js gzip + `gunzipScripts-0.0.1.js` into EthFS on Sepolia (or reuse Dav’s existing file IDs if available).
    2. Deploy the `beginning`, `beginningJS`, and `lens_init` contracts pointing at our E2MB + EthFS handles (mirroring Dav’s `davs-contracts` scripts).
    3. Create thin adapters that conform to `ICountdownRenderer`/`ICountdownHtmlRenderer`, register via `addPreRevealRenderer(svg, html, true)`, and publish the slot ID (expected slot 2).
  * **Holder UX:** document the exact `cast`/Etherscan steps in `COMMANDS.md` and/or ship a minimal web form that wraps `setTokenPreRevealRenderer` / `clearTokenPreRevealRenderer`.
  * **Community slot pilot:** define governance for a whitelist—e.g., owner calls `addPreRevealRenderer` only after vetting the submitted renderer. Builders must expose `render(RenderCtx)` and optionally `renderHtml(RenderCtx)`; they receive `tokenId`, `rank`, `revealYear`, `closenessBps`, etc., so they can synthesize their own visuals/audio without privileged data. Down the line we can expand this to a registry contract that tracks submitter metadata and lets holders browse approved lenses.

---
*Working doc. Update as we iterate on per-token lens selection and integrate with the renderer hub.*

---
### Update (Nov 11, 2025)
- Replaced the old monolithic `LifeLensRenderer` flow with the registry adapters only. Legacy renderer + its preview/test scripts now live in `_deprecated/` so the active stack is exclusively `LifeLensSvgRenderer`/`LifeLensHtmlRenderer` (countdown slot) and `LifeToneHtmlRenderer` (Tone.js slot).
- Added a glyph overlay system to `LifeSVG`/`LifeScript`/`LifeToneScript`: every cell now owns a `<text class="glyph">` seeded from `SongAlgorithm` output so we can surface musical symbols during the Life animation instead of blank squares.
- Began porting Dav’s synth recipes:
  * Lead voice runs a fat pulse MonoSynth through chorus + ping‑pong delay tuned to your Retro Synth / EchoBoy settings.
  * Bass voice uses a triangle/partials MonoSynth into a long chamber reverb matching the RVerb screenshot.
  * Both still read the exact SongAlgorithm note arrays (`LifeLensInit.board()`), so we can keep iterating on Tone parameters without changing the deterministic music data.
- **Known Issues (still open):**
  * Latest preview output (`OUTPUTS/life_lens_tone_token_1.html`) renders fully opaque squares and no audio—the Forge preview script failed after the legacy renderer move, so the HTML never regenerated. Need to re-run `forge script script/dev/PreviewLifeToneLens.s.sol` now that imports are fixed.
  * Even after regenerating, the glyph overlay occasionally hides behind cells; investigating whether to drop the `<rect>` layer entirely or keep it purely for JS hooks.
  * Tone stack doesn’t yet sound identical to the original Life WebAudio loop—parameters above are a first pass; continue dialing envelopes/effects until it matches expectations.

### Update (Nov 18, 2025)
- Added slot-level gating to `EveryTwoMillionBlocks`: renderer entries can now demand `hasSevenWords(tokenId) == true` before holders opt in. Life’s slot is flipped on by default, so Points + Life share the same prerequisite.
- `LifeLensInit` now returns a `wordSeeds` array (per-Markov-step salts derived from the seven-word hash), and both `LifeScript` + `LifeToneScript` advance the Game-of-Life RNG with those salts each reset. Effectively the animation/audio inherits the collector’s phrase instead of looping a single seed.
- Preview tooling grew up:
  * `script/dev/PreviewLifeToneLens.s.sol` accepts `PREVIEW_SEVEN_WORDS` (and can broadcast/log its mock addresses when `PREVIEW_BROADCAST=1`), so we can smoke-test arbitrary phrases locally without redeploying the whole NFT.
  * Balances/mix tweaks: lead dropped to −35 dB, bass shifted up an octave and boosted, delay wetness down to 0.1—brings the Tone stack closer to the in-studio reference.
  * Added `python-scripts/life_seq_to_midi.py` to dump lead/bass events straight from the generated HTML into a MIDI file for DAW inspection.
- Wrote an env-driven WireLifeLens script that automatically flags Life’s slot as “seven words required” after registration.
- **Current state:** regenerating `OUTPUTS/life_lens_tone_token_1.html` with a custom seven-word phrase now emits the new RNG logic (confirmed via `wordSalt` ordering), but the served HTML still refuses to render glyphs/audio even after a hard refresh. Tone.js loads, the click-to-start prompt fires, yet nothing animates. Next step is to isolate what’s silently failing in the inline script so we can finish the seven-word smoke test end-to-end.

### Update (Nov 24, 2025)
- Pushed the refreshed Life lens stack (sustained Eb pad, static glyph toggles, fixed wordSeeds declaration) to Sepolia:
  * Added `script/dev/DeployLifeLensInit.s.sol` for redeploying `LifeLensInit` against the latest E2MB + `SongAlgorithm`.

### Update (Nov 14, 2025)
- Replaced the CDN dependency in `LifeToneHtmlRenderer` with Dav’s EthFS-hosted Tone.js bundle:
  * Introduced `IBeginningJavascript` so the renderer can read `getTonejs()` directly from the deployed `beginningJS` contract (0x289b5441af7510F7fDc8e08c092359175726B839).
  * `LifeToneHtmlRenderer` now stores both the Life lens and the tone source; HTML output inlines the EthFS scripts returned by `beginningJS` before appending our Life-specific audio logic.
  * Preview and deploy scripts were updated—`DeployLifeLensAdapters` requires `BEGINNING_JS_ADDRESS`, while `PreviewLifeToneLens` accepts the same env var (falls back to a mock tone source for local testing).
  * Added a `MockToneSource` + unit test to ensure the renderer still emits valid HTML without hitting external hosts.
  * Deployed new `LifeLensInit`, `LifeLensSvgRenderer`, `LifeToneHtmlRenderer`, and reran `WireLifeLens` to register the slot + seven-word gate.
  * Updated `OUTPUTS/life_lens_tone_token_1.html` via `PreviewLifeToneLens`—glyphs/audio now behave locally.
- Redeployed `EveryTwoMillionBlocks` on Sepolia, rewired countdown slot 0, registered Life slot 1, and minted staging tokens. Verification via `forge verify-contract` succeeded.
- **Regression checklist from staging mint:**
  1. **Countdown assets fail to show on Rarible:** `tokenURI` returns valid countdown JSON/SVG, but marketplace previews stay blank. Need to diff the new countdown wiring (MIME headers? data URI length?) versus the previous deploy that rendered fine.
  2. **New mints inherit non-zero points (e.g., token 1 = 2,600 pts, token 2 = 1,300) and start at queue ranks 3/4 (years 2029/2030) instead of 0/1 (2026/2027).** Likely because we left `POINTS_MANAGER_ADDRESS` / `POINTS_AGGREGATOR_ADDRESS` pointing at an old instance with seeded data. Plan: deploy a fresh aggregator or rewire to a blank stub so new tokens default to zero points/ranks until burns arrive.
  3. **Default renderer stuck on Life for early mints:** even after calling `setDefaultPreRevealRenderer(0)` the first batch keeps returning the Life HTML blob because they inherited slot 1 at mint time. Need to explicitly call `setTokenPreRevealRenderer(tokenId, 0)` (or re-mint after fixing the default) and document this in the runbook.
- Next actions:
  * Reset/redeploy the Points stack for this staging deploy so queue ranks + points start from zero.
  * Investigate why Rarible no longer displays the countdown even though the data URI is correct—may need to fall back to the legacy renderer or tweak SVG headers.
  * After the above, re-run the seven-word opt-in flow (set words → `setTokenPreRevealRenderer(tokenId, lifeSlotId)`) to confirm Life renders correctly on-chain.

### Update (Nov 13, 2025 follow-up)
- **Rarible + tooling**: Spent the day proving Rarible Testnet was the culprit, not our metadata. Built `token_viewer/` (Express + ethers) so we can preview any Sepolia `tokenURI` locally; also deployed `RaribleDebugNFT` with a static IPFS URI to compare against countdown/Life renders.
- **Life lens polish**:
  * Fixed the duplicate `baseWordSalt`/`currentSeed` declaration that prevented the WebAudio loop from starting.
  * Swapped slot 1’s HTML renderer to the Tone.js version and locked its viewport to a square (`--life-size`).
  * Updated `LifeSVG` so the static `image` shows the first Life tick with ASCII glyphs (`_glyphForIndex`) instead of a blank board, and dropped the old fade/scale transitions so glyphs just snap in.
  * Documentation upgrades: refreshed `COMMANDS.md` with the slot-management commands, holder opt-in walkthrough, and the reminder to rerun `DeployLifeLensAdapters` / `updatePreRevealRenderer` whenever Life changes.
- **Status**: Countdown renders fine again (after Rarible’s crawler caught up), Life now uses the Tone stack on slot 1, and we have an internal viewer for future metadata debugging.
