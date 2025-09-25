# Millennium Song — On-chain SVG Countdown NFT (Progress Log)

This log captures every significant step, change, deploy, issue, and fix during the on-chain SVG countdown prototyping in this repo.

## 0) Environment + Tooling

- Chose Foundry (no NPM risk) over Hardhat.
- Installed Foundry via `foundryup`; initialized project structure with `forge init`.
- Added OpenZeppelin (via Foundry submodule) and switched imports to `openzeppelin-contracts/...`.

## 1) First ERC-721 + On-chain SVG

- Implemented `CountdownNFT.sol` (ERC-721 + Ownable) with `tokenURI()` returning `data:` JSON with embedded `image` as SVG (Base64).
- Reused a 7‑segment digit SVG (d0–d9) and initial 1-line odometer (no animation initially).
- Test: `test/CountdownNFT.t.sol` validates mint + `tokenURI` shape. All good.

## 2) Animation + Multi-digit Odometer

- Ported odometer animation (SMIL) using `<animateTransform>` translate; per-digit stacks with clip window; correct cycle durations (ones fastest → millions slowest).
- Verified compilation and local tests.

## 3) Sepolia Deploys (Chronological)

Note: Several iterations; each listed with a short purpose.

- 0x83F7D8c70F0D4730Bbc914d76700e9D0FFcee027 — First simple on-chain SVG (single-line digits).
- 0x80C5B0c37f7f45D10Ba9a1016C6573F2eDb5E6bE — Animated odometer added.
- 0x8b8a2B7333B2235296DEe2c9d5Ca4b8DBB9Aeb21 — 8‑digit display (millions of blocks), basic timing.

## 4) Time-based Countdown (Reveal by Year)

- Used `block.timestamp` as canonical time.
- Simplified reveal schedule: `revealYear = 2026 + rank` (rank initially = tokenId for testing).
- Converted time remaining to blocks using ~12s/block.

## 5) Dynamic Ranking (Points Overlay)

- Added:
  - `mapping(uint256 => uint256) public points;`
  - `mapping(uint256 => uint256) public basePermutation;` (VRF tiebreaker placeholder = tokenId)
  - `earnPoints(tokenId, amount)` (owner-only caller for test)
  - `getCurrentRank(tokenId)` and `_getCurrentRank(tokenId)` (descending points, tie → basePermutation asc)
- Updated countdown to use current rank, not tokenId.
- Deploy: 0xA7CF678566D81D2547B683D61D7fC0782c0F3B04; verified rank flips after `earnPoints`.

## 6) Expanding Digit Capacity (4×3 Grid)

- Switched from single row to a 4×3 grid (12 digits): supports ~3.8e5 years (~380,000 years) @ 12s/block.
- Row semantics (left→right):
  - Row 1 (top): 10^11, 10^10, 10^9, 10^8
  - Row 2: 10^7, 10^6, 10^5, 10^4
  - Row 3 (bottom): 10^3, 10^2, 10^1, 10^0
- Also show 4‑digit reveal year (white) below the odometer.
- Initial deploys for this shape:
  - 0xEEaF90D3e7573D7A5D713D6d0E53b17a81C2f9C4 — first 4×3 attempt
  - 0xF1E2077F79b5f4Da827cA1263E842b4FB3a9E983 — follow-up (verif issues)
  - 0x844adAC9b14522609d3f841bA8eCB98785Fcf1Ab — grid + tweaks

## 7) "AAAA…" Corruption Fix (SVG String Assembly)

- Root cause: concatenating `uint256` directly into `abi.encodePacked` injects binary; Base64 shows long `AAAA…` and breaks XML.
- Fixes applied:
  - Convert all inserted numbers to strings with `Strings.toString()` (notably in reveal year `<use href="#dX">`).
  - Added `xmlns:xlink` on `<svg>` for viewer compatibility (some expect `xlink:href`).
- Deploys after fix:
  - 0x5E4fF0cC81d35B8C4de5DC5f75EF836F5dff2370 — fixed string conversions.

## 8) Persistence Between Refreshes (Time-sync)

- Implemented begin offsets per column: `begin="-<elapsed>s"` where `elapsed = block.timestamp % cycleSeconds`.
- This makes the animation position canonical/time-synced—refreshes do not reset.
- Integrated into `_generateAnimatedDigitColumn(...)` (now `view`), passing explicit `cycleSeconds` per place value.
- Deploys:
  - 0xE8f6e456Dfc7bb359C62455c20c1207416d1fb92 — persistence + timing + centering updates.

## 9) Alignment + Centering Journey

- Original clip window: x = −5, width 50; inner translate x = 12; outer columns absolute → double-offset issues.
- Centering math (360px wide): 4 columns of width 50, gutter 10 ⇒ total width 230 ⇒ left edge 65; centers 90,150,210,270.
- Final robust geometry:
  - clipPath: `clipPathUnits="userSpaceOnUse"` with `rect x=0, y=−5, width=50, height=60`.
  - Inner per-column group: `translate(13, 10)` and animate from `13 10` to `13 −440` (glyphs are 24px wide; 13 = (50−24)/2 + 0 for centering around digit bounding box).
  - Row groups: `translate(65, Y)` for Y = 80, 140, 200.
  - Column offsets within row: `0, 60, 120, 180`.
- Verified ones tick ~12s and columns persist across refresh.
- Deploys:
  - 0xf8B56d23167863ac68Ff8F50D14F5Ce579d9Ec22 — per-digit tuning (inner translate 13) + uniform centering.
  - 0xC4c1DF5B6071d936d8B335e4d0c447ac15Cf9927 — intermediate alignment pass.

## 10) Current Contract Shape (Key Functions)

- `mint(address to)` — owner-only test mint; initializes `basePermutation[tokenId] = tokenId`.
- `earnPoints(uint256 tokenId, uint256 amount)` — owner of token earns points (test hook).
- `getCurrentRank(uint256 tokenId) → uint256` — public view; points-desc, tie→`basePermutation` asc.
- `tokenURI(uint256 tokenId) → data: JSON` — includes `image` as `data:image/svg+xml;base64,...`.
- SVG internals:
  - `<defs>` includes 7‑segment digit glyphs and `clipPath`.
  - 3 row groups → 4 columns each; each column includes stacked `<use>` digits + SMIL translate animation.
  - Per-column `begin` time uses `block.timestamp` modulo cycle.
  - Reveal year (4 digits, white) below grid.

## 10.5) Tick Mode + Tight Clip

- Added tick animation for all columns except the ones place (which remains continuous): discrete steps each cycle using SMIL `calcMode="discrete"` with 50px per-step translate.
- Tightened clip window to 50px height (per step) and aligned inner translate to y=0 to eliminate neighbor bleed.
- Deploys:
  - Tick build: `0xE35962cE7d03F5D310CC5157882a687E4aa267b1` ([out-tick.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-tick.svg))
  - Tick + tight clip: `0xABe782248869C43AF4c4Bc61b15730D4DE62d57E` ([out-tick-tight.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-tick-tight.svg))

## 10.6) Centered Year (4-digit)

- Centered the year label after scale; translate set to `translate(38, 310)` with `scale(1.5)` to visually center within 360px viewport.
- Deploy: `0xfc6d57c0Bfb67168224aa1e2a5969BbE6E12F8e1` ([out-centered-year.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-centered-year.svg)).

## 10.7) No-Reset Time Sync

- Removed negative `begin` offsets. Rendering starts in the correct phase and schedules the next change in the future.
  - Tick columns: compute `timeToNext = step - (elapsed % step)`; initial y=0; `begin=timeToNext` with discrete values for 11 keyTimes (wrap).
  - Ones column: staged animation — first partial from current `y0` to end; then repeating full cycles.
- Result: Refreshing does not reset animation state; columns remain time-synced to `block.timestamp`.
- Deploy: `0x990aA5327F7EDCeEFc9bEbcc1BAdd609753C68Fe` ([out-no-reset.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-no-reset.svg)).

## 10.8) Snapshots & Tags

- Locked snapshots for reference:
  - v0.1-tick-tight — tick mode + tight 50px clip, bleed fixed.
  - v0.2-no-reset — future-begin ticks + staged ones column; centered year retained.
- Prior Sepolia decodes archived for regression comparison:
  - `0xEEaF90…` → [out-prev-EEaF90.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-prev-EEaF90.svg)
  - `0x844adA…` → [out-prev-844adA.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-prev-844adA.svg)
  - `0xE8f6e4…` → [out-prev-E8f6e4.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-prev-E8f6e4.svg)
  - `0xf8B56d…` → [out-prev-f8B56d.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-prev-f8B56d.svg)
  - `0xC4c1DF…` → [out-prev-C4c1DF.svg](file:///Users/jonathanmann/SongADAO%20Dropbox/Jonathan%20Mann/projects/THE-LONG-SONG/contracts/out-prev-C4c1DF.svg)

## 11) Outstanding / Next Tweaks

- [ ] Rank-aware coloring with minimal byte-size:
  - Phase A (low-risk): opacity ramp for digits: `fill-opacity = 0.15 + 0.85 * closeness` (closeness = 1 - rank/(supply-1)).
  - Phase B (optional): subtle hue per row using inline `hsl(h,s%,l%)`, computed on the fly (no shared helpers) to avoid byte-size growth.
- [ ] UTC Jan-1 table for precise reveal boundaries (current method is simplified).
- [ ] Optional: add `restart="never"` where supported (most viewers behave correctly already).
- [ ] Test coverage for time-sync math (tick edges, ones column handoff).

- [ ] Micro‑align per-digit centering across all digits (renderer differences can introduce 1–2px variance). Options:
  - Fine‑tune inner translate x (12↔14) and/or switch segment stroke/joins.
  - Add `shape-rendering="crispEdges"` on digit segments for consistent rasterization.
- [ ] Scale-aware centering for the reveal year (center after scale).
- [ ] Optional: switch to `xlink:href` duplicates for `<use>` if any marketplace still misrenders.
- [ ] If supply grows large, optimize `_getCurrentRank()` from O(n) view to cached structures (out of scope for this test).

## 12) Security/Robustness Notes

- `tokenURI()` uses `require(_exists(tokenId), ...)` (custom error string).
- All SVG assembled via pure/view functions, no external calls; only Base64 and Strings utils used.
- No storage writes during `tokenURI()`.

## 13) Quick Reference — Addresses Used

- First simple SVG: `0x83F7D8c70F0D4730Bbc914d76700e9D0FFcee027`
- First animation: `0x80C5B0c37f7f45D10Ba9a1016C6573F2eDb5E6bE`
- 8‑digit: `0x8b8a2B7333B2235296DEe2c9d5Ca4b8DBB9Aeb21`
- Ranking prototype: `0xA7CF678566D81D2547B683D61D7fC0782c0F3B04`
- 4×3 initial: `0xEEaF90D3e7573D7A5D713D6d0E53b17a81C2f9C4`
- Variants / verif: `0xF1E2077F79b5f4Da827cA1263E842b4FB3a9E983`, `0x844adAC9b14522609d3f841bA8eCB98785Fcf1Ab`, `0x5E4fF0cC81d35B8C4de5DC5f75EF836F5dff2370`, `0xE8f6e456Dfc7bb359C62455c20c1207416d1fb92`, `0xf8B56d23167863ac68Ff8F50D14F5Ce579d9Ec22`, `0xC4c1DF5B6071d936d8B335e4d0c447ac15Cf9927`

## 14) Commands Cheat Sheet

- Build: `forge build`
- Test: `forge test -vv`
- Deploy: `forge script script/DeployCountdown.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast`
- Mint (cast):
  - `cast send <addr> "mint(address)" <yourAddress> --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY`
- tokenURI (debug):
  - `cast call <addr> "tokenURI(uint256)" <id> --rpc-url $SEPOLIA_RPC_URL`

---

If needed I can append renders or decoded SVG examples here for archival/debugging.
