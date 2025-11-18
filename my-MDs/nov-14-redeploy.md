# Nov 14 Redeploy — Progress Notes

## 1. Pre-Reveal Registry Refactor
- Split the slot registry out of `EveryTwoMillionBlocks` into a dedicated `PreRevealRegistry` contract, keeping slots/add/remove logic off the main NFT to stay under the 24 KB limit.
- Updated `E2MB` to hold only a registry pointer + controller guard, delegating slot writes (`addRenderer`, `updateRenderer`, `setDefault`, `freeze`) and token preferences (`setTokenRenderer`, `resolveRenderer`) to the registry.
- Added read helpers on the registry (`getRenderer`, `getTokenRenderer`, `rendererCount`, `registryFrozen`) and wired `setTokenPreRevealRenderer` to enforce seven-word gating before forwarding selections.
- Reworked the Foundry tests:
  * `test/PreRevealRegistry.t.sol` now deploys both the registry and NFT, covering slot registration, holder overrides, seven-word gating, and fallback behaviour.
  * `test/RevealTransition.t.sol` wires slot `0` through the registry before running the reveal state machine.
  * Added `MockToneSource` for HTML renderer tests so no external fetches occur during CI.
- Foundry runners must append `--no-storage-caching` (Foundry 1.4 bug) to every `forge test`/`forge script` invocation or storage snapshots bleed between suites. Documented the flag in `testing-regression-plan.md` and `COMMANDS.md`.
- CLI/docs updates:
  * `COMMANDS.md` section 1.5 now documents deploying/authorizing the registry (`BEGINNING_JS_ADDRESS` introduced), registering slots, holder instructions, and the new `cast call` endpoints.
  * `deployed.env` gained `PRE_REVEAL_REGISTRY_ADDRESS` so deploy scripts can source the registry during rewires.

## 2. Deploy/Test Tooling
- `script/deploy/03_WireRenderers.s.sol` trimmed to only set the SongAlgorithm/music/audio renderers; countdown slot management now lives in the registry scripts.
- Added a `BEGINNING_JS_ADDRESS` requirement to `script/dev/DeployLifeLensAdapters.s.sol` so Life lens HTML deployments automatically know where to fetch Tone.js.
- `script/dev/PreviewLifeToneLens.s.sol` accepts `BEGINNING_JS_ADDRESS` (falls back to the mock tone source when unset) and logs the active tone provider for sanity.
- Added a `BEGINNING_JS_INSTALL_BYTECODE` option plus `BEGINNING_JS_BYTECODE_PATH=script/data/beginning_js_mainnet_code.hex` so local previews can `vm.etch` the real mainnet `beginningJS` bytecode into a fork before rendering. Use `forge script ... --fork-url $ETH_MAINNET_RPC_URL --no-storage-caching` to exercise the real EthFS payload.
- `script/dev/WireLifeLens.s.sol` and docs now mention that the Life slot is gated on seven words—scripts call `setRendererRequiresSevenWords(rendererId, true)` immediately after registration.
- Fast-reveal fork test (`test/fast-reveal/FinalizeTrace.t.sol`) is opt-in via `ENABLE_FINALIZE_TRACE`; default `forge test` runs no Sepolia fork.

## 3. Life Lens Tone.js Integration
- Added `IBeginningJavascript` and pointed `LifeToneHtmlRenderer` at the deployed `beginningJS` contract (EthFS host). HTML output now inlines the EthFS script blob (`getTonejs()` + gunzip helper) before the Life-specific audio script.
- Removed the jsDelivr `<script src=...Tone.js>` tag, so onchainchecker now sees zero remote dependencies.
- Updated `LifeToneHtmlRenderer.t.sol` to assert the mock tone snippet is present; introduced `MockToneSource` as a drop-in for local testing and script previews.
- `COMMANDS.md` includes a reminder to set `BEGINNING_JS_ADDRESS=0x289b5441af7510F7fDc8e08c092359175726B839` (Dav’s mainnet/Sepolia deployment) before running any Life adapter deploys.
- Summary recorded in `davs-thing-progress.md — Update (Nov 14, 2025)` to keep the Dav integration log in sync.
- Inline Tone host (Nov 16): introduced a chunked `InlineToneSource` + `DeployInlineToneSource.s.sol`/`SeedInlineToneSource.s.sol` that stores Dav’s Tone.js gzip + gunzip helper via SSTORE2. Deployed `InlineToneSource` @ `0x25B3aB6f2A774A7217E4E828F444ADAdf205B591`, redeployed Life adapters, and updated the preview script (`PREVIEW_TONE_FROM_FILES=1 ...`) so local HTML matches on-chain output. Verified on Sepolia by setting seven words + slot 5 for token 1 and confirming the Life lens renders with the embedded Tone bundle (no `Tone is not defined`).
- **Control rail & glyph font (Nov 17):**
  * Added an Audioglyph-style control strip to `LifeToneHtmlRenderer` (play button, seven-word label, reveal year) so mobile browsers have a reliable gesture surface.
  * Inlined the Bravura subset as its own SSTORE2 contract (`InlineGlyphFontSource`), complete with deployment script + docs (`COMMANDS.md §1.5`). Preview tooling can now swap between Dav’s EthFS font and the inline blob the same way we handle Tone.js.
  * Updated both Life renderers to accept an external font source (`LIFE_GLYPH_FONT_ADDRESS`) and redeployed fresh adapters on Sepolia (`LifeLensSvgRenderer` @ `0xa1BD2116036Ed064fcFFAE9A700883ba7DE15b9e`, `LifeToneHtmlRenderer` @ `0xf5Da29A82fa4D60e9322882B881D907349cCdEF2`). Registry slots 1 + 5 were rewired to those addresses while keeping the seven-word gate intact.
  * TokenURI now serves the new HTML payload without hitting the 24 KB cap, and local previews (`script/dev/PreviewLifeToneLens.s.sol`) mirror the on-chain tone/font sources.
- **Mobile audio + chaos polish (Nov 18):**
  * Removed the heavyweight control rail, tightened the overlay into a tap-to-start curtain, and added `Tone.getContext().rawContext.resume()` guards so iOS Safari consistently unlocks audio. The overlay auto-hides once `Tone.start()` resolves or after the first playback, with fallbacks logged to the console.
  * Shrunk the glyph font ratio in `LifeSVG` so ledger-note glyphs stay inside each rounded tile, then redeployed both adapters (`LifeLensSvgRenderer` @ `0x45a15BeC13f1A9bD3096Dc5dA0f97DD24f3d0eef`, later superseded by `0x09BD1914aD52f4ABA0Eae0279C02E60A0768362a`; `LifeToneHtmlRenderer` @ `0x965Ee39457672B8914b08941f2E9699CdB5b3432`, later superseded by `0xf12B96679d63dF09E283034B928132085eDD7C51`). Slot 5 was rewired after each deploy so holders see the latest build.
  * Flipped the Life chaos ramp so it now accelerates as reveal approaches, scaled the jitters off the actual supply (no 75-year clamp), and widened every knob (alive density, min alive, ±12 semitone pitch drift, duration variance up to 1.2×, tick intervals down to ~220 ms at peak). Latest renderer addresses: SVG `0x09BD1914aD52f4ABA0Eae0279C02E60A0768362a`, HTML `0xf12B96679d63dF09E283034B928132085eDD7C51`.
  * Verified `forge test --match-contract LifeToneHtmlRendererTest --no-storage-caching` after each change and noted the overlay behaviour in `LifeToneHtmlRenderer.t.sol`.

## 4. Status
- `forge test` (without `ENABLE_FINALIZE_TRACE`) passes all suites after the registry + Tone.js refactors.
- `forge build --sizes` reports `EveryTwoMillionBlocks` runtime at 24,014 bytes (< 24 KB cap).
- Ready to redeploy on Sepolia with the new registry + Life lens slot wiring, then hand off the new env snapshot + holder instructions to the frontend team.
- ✅ Nov 15 deploy completed: `EveryTwoMillionBlocks` @ `0x18a09608810f87f76061f4E075Edc49115194B78`, `PreRevealRegistry` @ `0x10C046CaC7Acc33D3fFEfEbbC3Ff630CDCC72910`, Life lens init/svg/html adapters + slot registered (rendererId=1), countdown slot set as default (rendererId=0), and points stack rewired to the new NFT.
- ✅ Nov 15 points refresh: minted 5 seed tokens for testing, then redeployed the entire L1 points stack (`PointsManager` @ `0x051cEaD10FE8ec708B749F77C5aA96EccB40063d`, `PointsAggregator` @ `0xE792A14b2A667EA22808967efDf7B899dBaF5CD0`, `L1BurnCollector` @ `0x6709B876B564c170a35177732aBD4dB5DAC85AD6`). Rewired `EveryTwoMillionBlocks` via `04_ConfigureE2MB.s.sol`, re-authorized Base/OP/Arbitrum receivers, and left `renderersFinalized` unset for future iterations.
- ✅ Nov 16 inline Tone host: new `InlineToneSource` @ `0x25B3aB6f2A774A7217E4E828F444ADAdf205B591` seeded with Dav’s Tone.js blob, plus refreshed Life adapters (current slot id=5). Token 1 now renders the Life lens HTML/audio on Sepolia using the on-chain Tone bundle we mirrored from Dav’s repo.
- ✅ Nov 17 glyph font mirror: deployed `InlineGlyphFontSource` @ `0x1075B211cB140Ca344c4ccec93ad6345490cE5BC`, redeployed Life adapters (`0xa1BD2116036Ed064fcFFAE9A700883ba7DE15b9e` / `0xf5Da29A82fa4D60e9322882B881D907349cCdEF2`), and rewired slots 1 + 5. Token 1’s `tokenURI` now returns the control-rail UI + on-chain font without code-size reverts.
- ✅ Nov 18 Life lens polish: multiple redeploys landed the overlay/audio fixes, chaos re-scaling, and glyph sizing (`LifeLensSvgRenderer` @ `0x09BD1914aD52f4ABA0Eae0279C02E60A0768362a`, `LifeToneHtmlRenderer` @ `0xf12B96679d63dF09E283034B928132085eDD7C51`; slot 5 rewired each time). Audio now primes reliably on iOS/Android, glyphs stay inside their cells, and near-reveal tokens exhibit noticeably higher visual/audio energy.
- ✅ Nov 18 points burn test: re-confirmed the Sepolia points stack by minting/burning dummy ERC-721/1155/20 assets through `L1BurnCollector` and watching `PointsManager`/`EveryTwoMillionBlocks` update ranks (token 1 = 650 pts, token 2 = 130 pts, token 3 = 1 pt). Documented tx hashes in the console log and noted the seven-word gating requirement before burns succeed.

## 5. Remaining Follow-ups
- ✅ Verify mobile UX: ensure tap-to-start audio consistently unlocks the Tone context on iOS and Android.
- Mirror the Life glyph font into EthFS (similar to Dav’s Tone bundle) so other builders can reuse it post-mainnet without copying our SSTORE2 contract.
- For production, replace the inline Tone chunk storage with Dav’s EthFS files so we ship the canonical assets again.
- During the production redeploy, keep Life lens assigned to slot 1 (either update rendererId 1 or remove the temporary slot 5 record) so existing docs and holder flows stay accurate.
