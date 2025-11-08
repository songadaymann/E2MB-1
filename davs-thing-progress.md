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
*Working doc. Update as we iterate on per-token lens selection and integrate with the renderer hub.*
