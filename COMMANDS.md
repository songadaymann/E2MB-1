# Millennium Song — Command Reference

Step-by-step CLI cheatsheet covering full redeploys, wiring checks, VRF setup, and burn tests. Run everything from the project root after sourcing environment files.

---

## 0. Environment Prep
- Load secrets and latest deployment addresses:
  ```sh
  source .env
  source deployed.env

  ```
- Helpful aliases (optional):
  ```sh
  export OWNER=$(cast wallet address --private-key $PRIVATE_KEY)
  export NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  ```

---

## 1. Renderer & Core NFT Deployment

### 1.1 Deploy shared renderers (rare; only when bytecode changes)
```sh
forge script script/deploy/01_DeployRenderers.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY
```
*Updates multiple renderer addresses; copy any new values into `deployed.env` / docs.*

### 1.2 Deploy EveryTwoMillionBlocks
```sh
forge script script/deploy/02_DeployMain.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY
```
*Write the printed `MSONG_ADDRESS` to `deployed.env`, `ADDRESSES.md`, etc.*

### 1.3 Wire renderers + static config
```sh
forge script script/deploy/03_WireRenderers.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY

forge script script/deploy/04_ConfigureE2MB.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY

# Register Life lens adapters (new pre-reveal slot)
forge script script/dev/WireLifeLens.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY
```
*`03_WireRenderers` still points slot 0 at the countdown renderer + seeds VRF/mint config. `04_ConfigureE2MB` handles owner-only knobs (supply caps, payout, etc.). Run `script/dev/WireLifeLens.s.sol` afterwards to register the Life lens SVG/HTML pair as its own slot without touching slot 0. Update `deployed.env` with the new `MSONG_ADDRESS`, Life lens renderer IDs, and keep the points/VRF commands commented out until we’re ready for a full production cutover.*

### 1.4 Mint initial Millennium Song supply (IDs 1–50)
```sh
forge script script/tools/MintBatch50.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY
```

### 1.5 Pre-reveal renderer registry (slot management + holder UX)

> **Quick mental model**: slot `0` == legacy countdown. Additional slots hold (SVG, HTML, active) pairs. Tokens default to `defaultPreRevealRendererId` unless the holder picks a slot via `setTokenPreRevealRenderer`.

- **Set slot 0 (countdown) during wiring**
  ```sh
  cast send $MSONG_ADDRESS 'setCountdownRenderer(address)' $COUNTDOWN_SVG_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

  cast send $MSONG_ADDRESS 'setCountdownHtmlRenderer(address)' $COUNTDOWN_HTML_ADDRESS \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

  cast send $MSONG_ADDRESS 'setDefaultPreRevealRenderer(uint256)' 0 \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
  ```

- **Register a new renderer pair (e.g., Life lens adapters)**
  ```sh
  cast send $MSONG_ADDRESS 'addPreRevealRenderer(address,address,bool)' \
    $LIFE_LENS_SVG_ADDRESS $LIFE_LENS_HTML_ADDRESS true \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
  ```
  *Read the emitted `PreRevealRendererRegistered` event (or `cast call getPreRevealRenderer(id)`) to learn the slot ID. Leave slot `0` untouched so countdown remains the default until we intentionally flip it.*

- **Update or deactivate an existing slot**
  ```sh
  cast send $MSONG_ADDRESS 'updatePreRevealRenderer(uint256,address,address,bool)' \
    $RENDERER_ID $NEW_SVG $NEW_HTML $IS_ACTIVE \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
  ```

- **Freeze further mutations once we're confident in the menu**
  ```sh
  cast send $MSONG_ADDRESS 'freezePreRevealRegistry()' \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
  ```
  *After freezing, slot edits (including `setCountdownRenderer`) are permanently disabled, but holders can still switch between the already-registered slots.*

- **Holder instructions (Etherscan write tab or `cast`)**
  - Switch to slot `N`:  
    `cast send $MSONG_ADDRESS 'setTokenPreRevealRenderer(uint256,uint256)' $TOKEN_ID $RENDERER_ID --rpc-url ... --private-key <token-owner>`
  - Reset to default countdown:  
    `cast send $MSONG_ADDRESS 'clearTokenPreRevealRenderer(uint256)' $TOKEN_ID --rpc-url ... --private-key <token-owner>`
  - Read active slot for a token:  
    `cast call $MSONG_ADDRESS 'getTokenPreRevealRenderer(uint256)(uint256,bool)' $TOKEN_ID --rpc-url ...`

- **Safety checks**
  ```sh
  cast call $MSONG_ADDRESS 'getPreRevealRenderer(uint256)(address,address,bool)' 0 \
    --rpc-url $SEPOLIA_RPC_URL                     # slot 0 still countdown?
  cast call $MSONG_ADDRESS 'defaultPreRevealRendererId()(uint256)' \
    --rpc-url $SEPOLIA_RPC_URL
  cast call $MSONG_ADDRESS 'tokenPreRevealChoice(uint256)(uint256)' $TOKEN_ID \
    --rpc-url $SEPOLIA_RPC_URL                     # = rendererId if custom
  cast call $MSONG_ADDRESS 'tokenPreRevealChoiceSet(uint256)(bool)' $TOKEN_ID \
    --rpc-url $SEPOLIA_RPC_URL
  ```

---

## 2. Points Stack Deployment & Wiring

### 2.1 Fresh deploy (new aggregator + L1 collector; reuses existing PointsManager)
```sh
forge script script/deploy/10_FreshPointsStack.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY
```
*Outputs new `PointsAggregator` + `L1BurnCollector` addresses, registers dummy assets, refreshes approvals, authorizes receivers, and sets E2MB pointers. Update `POINTS_AGGREGATOR_ADDRESS` / `L1_BURN_COLLECTOR_ADDRESS` in `deployed.env` afterwards.*

### 2.2 Rewire existing stack (no redeploy; brings pointers back in sync)
```sh
forge script script/deploy/09_RewirePointsStack.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY
```
*Re-synchronizes PointsManager ↔ Aggregator, refreshes eligible assets + approvals, and authorizes LayerZero receivers.*

### 2.3 LayerZero receiver refresh (run on each L2 testnet after redeploy)
```sh
forge script script/ops/ReconfigureBaseCollector.s.sol \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY

forge script script/ops/ReconfigureOpCollector.s.sol \
  --rpc-url $OP_SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY

forge script script/ops/ReconfigureArbCollector.s.sol \
  --rpc-url $ARB_SEPOLIA_RPC_URL \
  --broadcast --legacy \
  --private-key $PRIVATE_KEY
```
*Sets each collector’s aggregator peer, re-adds dummy eligibility with base values (ERC721=100k, ERC1155=10k, ERC20=1 @ 18 decimals), and refreshes approvals/allowances on the burner wallet.*

### 2.4 Manual pointer fixes (useful when scripts can’t run)
```sh
# E2MB -> Aggregator
cast send $MSONG_ADDRESS 'setPointsAggregator(address)' $POINTS_AGGREGATOR_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Aggregator -> NFT
cast send $POINTS_AGGREGATOR_ADDRESS 'setNftContract(address)' $MSONG_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# PointsManager reveal plumbing
cast send $POINTS_MANAGER_ADDRESS 'setRevealQueue(address)' $MSONG_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $POINTS_MANAGER_ADDRESS 'setPermutationZeroIndexed(bool)' true \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# LayerZero receiver -> new aggregator
cast send $BASE_L1_LAYERZERO_RECEIVER_ADDRESS 'setAggregator(address)' $POINTS_AGGREGATOR_ADDRESS \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

---

## 3. Wiring Verification Checklist

Run these after any deploy/rewire (expect every pointer to match the new addresses):
```sh
cast call $POINTS_MANAGER_ADDRESS 'aggregator()(address)'                     --rpc-url $SEPOLIA_RPC_URL
cast call $POINTS_AGGREGATOR_ADDRESS 'pointsManager()(address)'               --rpc-url $SEPOLIA_RPC_URL
cast call $POINTS_AGGREGATOR_ADDRESS 'l1BurnCollector()(address)'             --rpc-url $SEPOLIA_RPC_URL
cast call $POINTS_AGGREGATOR_ADDRESS 'nftContract()(address)'                 --rpc-url $SEPOLIA_RPC_URL
cast call $POINTS_MANAGER_ADDRESS 'revealQueue()(address)'                    --rpc-url $SEPOLIA_RPC_URL
cast call $POINTS_MANAGER_ADDRESS 'permutationZeroIndexed()(bool)'            --rpc-url $SEPOLIA_RPC_URL
cast call $MSONG_ADDRESS 'pointsManager()(address)'                           --rpc-url $SEPOLIA_RPC_URL
cast call $MSONG_ADDRESS 'pointsAggregator()(address)'                        --rpc-url $SEPOLIA_RPC_URL
cast call $BASE_L1_LAYERZERO_RECEIVER_ADDRESS 'aggregator()(address)'         --rpc-url $SEPOLIA_RPC_URL
cast call $OP_L1_LAYERZERO_RECEIVER_ADDRESS 'aggregator()(address)'         --rpc-url $SEPOLIA_RPC_URL
cast call $ARB_L1_LAYERZERO_RECEIVER_ADDRESS 'aggregator()(address)'         --rpc-url $SEPOLIA_RPC_URL
cast call $BASE_L1_LAYERZERO_RECEIVER_ADDRESS 'trustedPeers(uint32)(bytes32)' $BASE_LAYERZERO_EID \
  --rpc-url $SEPOLIA_RPC_URL
cast call $OP_L1_LAYERZERO_RECEIVER_ADDRESS 'trustedPeers(uint32)(bytes32)' $OP_LAYERZERO_EID \
  --rpc-url $SEPOLIA_RPC_URL
cast call $ARB_L1_LAYERZERO_RECEIVER_ADDRESS 'trustedPeers(uint32)(bytes32)' $ARB_LAYERZERO_EID \
  --rpc-url $SEPOLIA_RPC_URL
```

*Repeat trusted peer checks for OP / ARB receivers using their endpoint IDs.*

---

## 4. Dummy Asset Eligibility & Approvals (Sepolia L1)

```sh
# Base values (ERC721=100k, ERC1155=10k, ERC20=1)
cast send $L1_BURN_COLLECTOR_ADDRESS 'addEligibleAsset(address,uint256)' $DUMMY_ONE_OF_ONE_ADDRESS 100000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $L1_BURN_COLLECTOR_ADDRESS 'addEligibleAsset(address,uint256)' $DUMMY_EDITION1155_ADDRESS 10000 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $L1_BURN_COLLECTOR_ADDRESS 'addEligibleAsset(address,uint256)' $DUMMY_ERC20_ADDRESS 1 \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Burner wallet approvals / allowance
cast send $DUMMY_ONE_OF_ONE_ADDRESS    'setApprovalForAll(address,bool)' $L1_BURN_COLLECTOR_ADDRESS true \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $DUMMY_EDITION1155_ADDRESS   'setApprovalForAll(address,bool)' $L1_BURN_COLLECTOR_ADDRESS true \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $DUMMY_ERC20_ADDRESS         'approve(address,uint256)'       $L1_BURN_COLLECTOR_ADDRESS 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
```

Verification:
```sh
cast call $L1_BURN_COLLECTOR_ADDRESS 'eligibleAssets(address)(uint256)' $DUMMY_ONE_OF_ONE_ADDRESS    --rpc-url $SEPOLIA_RPC_URL
cast call $L1_BURN_COLLECTOR_ADDRESS 'eligibleAssets(address)(uint256)' $DUMMY_EDITION1155_ADDRESS   --rpc-url $SEPOLIA_RPC_URL
cast call $L1_BURN_COLLECTOR_ADDRESS 'eligibleAssets(address)(uint256)' $DUMMY_ERC20_ADDRESS         --rpc-url $SEPOLIA_RPC_URL
```

---

## 5. LayerZero Collector Commands (Base examples)

```sh
# Mint dummy assets to burner
cast send $BASE_DUMMY_ONE_OF_ONE_ADDRESS  'mint(address)'             $OWNER --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $BASE_DUMMY_EDITION1155_ADDRESS 'mintEdition(address,uint256,uint256)' $OWNER 1 400 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $BASE_DUMMY_ERC20_ADDRESS       'mint(address,uint256)'     $OWNER 1000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Approvals / allowances
cast send $BASE_DUMMY_ONE_OF_ONE_ADDRESS    'setApprovalForAll(address,bool)' $BASE_BURN_COLLECTOR_ADDRESS true \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $BASE_DUMMY_EDITION1155_ADDRESS   'setApprovalForAll(address,bool)' $BASE_BURN_COLLECTOR_ADDRESS true \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $BASE_DUMMY_ERC20_ADDRESS         'approve(address,uint256)'       $BASE_BURN_COLLECTOR_ADDRESS 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Queue burns (ERC721 / ERC1155 / ERC20)
cast send $BASE_BURN_COLLECTOR_ADDRESS 'queueERC721(address,uint256,uint256)'  $BASE_DUMMY_ONE_OF_ONE_ADDRESS 15 1 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $BASE_BURN_COLLECTOR_ADDRESS 'queueERC1155(address,uint256,uint256,uint256)' $BASE_DUMMY_EDITION1155_ADDRESS 1 400 37 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $BASE_BURN_COLLECTOR_ADDRESS 'queueERC20(address,uint256,uint256)'   $BASE_DUMMY_ERC20_ADDRESS 1000000000000000000 37 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Bridge queued deltas (quote first, then send with native fee)
cast call $BASE_BURN_COLLECTOR_ADDRESS 'quoteCheckpoint(uint256[])((uint128,uint128))' '[1]' \
  --rpc-url $BASE_SEPOLIA_RPC_URL

cast send $BASE_BURN_COLLECTOR_ADDRESS \
  'checkpoint(uint256[])' \
  '[1]' \
  --value 56656200994488 \
  --rpc-url $BASE_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY
```

## 5a. LayerZero Collector Commands (OP examples)
```sh
# Mint dummy assets to burner
cast send $OP_DUMMY_ONE_OF_ONE_ADDRESS  'mint(address)'             $OWNER --rpc-url $OP_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $OP_DUMMY_EDITION1155_ADDRESS 'mintEdition(address,uint256,uint256)' $OWNER 1 400 \
  --rpc-url $|OP_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $OP_DUMMY_ERC20_ADDRESS       'mint(address,uint256)'     $OWNER 1000000000000000000 \
  --rpc-url $OP_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Approvals / allowances
cast send $OP_DUMMY_ONE_OF_ONE_ADDRESS    'setApprovalForAll(address,bool)' $OP_BURN_COLLECTOR_ADDRESS true \
  --rpc-url $OP_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $OP_DUMMY_EDITION1155_ADDRESS   'setApprovalForAll(address,bool)' $OP_BURN_COLLECTOR_ADDRESS true \
  --rpc-url $OP_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $OP_DUMMY_ERC20_ADDRESS         'approve(address,uint256)'       $OP_BURN_COLLECTOR_ADDRESS 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --rpc-url $OP_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Queue burns (ERC721 / ERC1155 / ERC20)
cast send $OP_BURN_COLLECTOR_ADDRESS 'queueERC721(address,uint256,uint256)'  $OP_DUMMY_ONE_OF_ONE_ADDRESS 1 2 \
  --rpc-url $OP_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $OP_BURN_COLLECTOR_ADDRESS 'queueERC1155(address,uint256,uint256,uint256)' $OP_DUMMY_EDITION1155_ADDRESS 1 400 37 \
  --rpc-url $OP_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $OP_BURN_COLLECTOR_ADDRESS 'queueERC20(address,uint256,uint256)'   $OP_DUMMY_ERC20_ADDRESS 1000000000000000000 37 \
  --rpc-url $BASE_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Bridge queued deltas (quote first, then send with native fee)
cast call $OP_BURN_COLLECTOR_ADDRESS 'quoteCheckpoint(uint256[])((uint128,uint128))' '[2]' \
  --rpc-url $OP_SEPOLIA_RPC_URL

cast send $OP_BURN_COLLECTOR_ADDRESS \
  'checkpoint(uint256[])' \
  '[2]' \
  --value 8075062387060 \
  --rpc-url $OP_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY


## 5b. LayerZero Collector Commands (ARB examples)
# Mint dummy assets to burner
cast send $ARB_DUMMY_ONE_OF_ONE_ADDRESS  'mint(address)'             $OWNER --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $ARB_DUMMY_EDITION1155_ADDRESS 'mintEdition(address,uint256,uint256)' $OWNER 1 400 \
  --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $ARB_DUMMY_ERC20_ADDRESS       'mint(address,uint256)'     $OWNER 1000000000000000000 \
  --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Approvals / allowances
cast send $ARB_DUMMY_ONE_OF_ONE_ADDRESS    'setApprovalForAll(address,bool)' $ARB_BURN_COLLECTOR_ADDRESS true \
  --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $ARB_DUMMY_EDITION1155_ADDRESS   'setApprovalForAll(address,bool)' $ARB_BURN_COLLECTOR_ADDRESS true \
  --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $ARB_DUMMY_ERC20_ADDRESS         'approve(address,uint256)'       $ARB_BURN_COLLECTOR_ADDRESS 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Queue burns (ERC721 / ERC1155 / ERC20)
cast send $ARB_BURN_COLLECTOR_ADDRESS 'queueERC721(address,uint256,uint256)'  $ARB_DUMMY_ONE_OF_ONE_ADDRESS 14 1 \
  --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $ARB_BURN_COLLECTOR_ADDRESS 'queueERC1155(address,uint256,uint256,uint256)' $ARB_DUMMY_EDITION1155_ADDRESS 1 400 37 \
  --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
cast send $ARB_BURN_COLLECTOR_ADDRESS 'queueERC20(address,uint256,uint256)'   $ARB_DUMMY_ERC20_ADDRESS 1000000000000000000 4 \
  --rpc-url $ARB_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY

# Bridge queued deltas (quote first, then send with native fee)
cast call $ARB_BURN_COLLECTOR_ADDRESS 'quoteCheckpoint(uint256[])((uint128,uint128))' '[4]' \
  --rpc-url $ARB_SEPOLIA_RPC_URL

cast send $ARB_BURN_COLLECTOR_ADDRESS \
  'checkpoint(uint256[])' \
  '[4]' \
  --value 8523025602960 \
  --rpc-url $ARB_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY

Verification on Sepolia:
```sh
cast call $POINTS_MANAGER_ADDRESS 'pointsOf(uint256)(uint256)' 1 --rpc-url $SEPOLIA_RPC_URL
```

---

## 6. VRF & Permutation Workflow

1. **Add E2MB as a VRF consumer**
   ```sh
   cast send 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B \
     "addConsumer(uint256,address)" \
     0xc1db20cb0e1a6e08198b382012720b3205c8f3cf28237604ec99e9f37ce770dd \
     $MSONG_ADDRESS \
     --rpc-url $SEPOLIA_RPC_URL \
     --private-key $PRIVATE_KEY
   ```

2. **Request randomness**
   ```sh
   cast send $MSONG_ADDRESS \
     "requestPermutationSeed()" \
     --gas-limit 300000 \
     --rpc-url $SEPOLIA_RPC_URL \
     --private-key $PRIVATE_KEY
   ```

3. **Read the fulfilled seed**
   ```sh
   cast call $MSONG_ADDRESS 'permutationSeed()(bytes32)' --rpc-url $SEPOLIA_RPC_URL
   ```

4. **Generate permutation JSON**
   ```sh
   SEED=<bytes32_from_previous_call>
   python3 script/tools/fisher_yates.py $SEED 50 > OUTPUTS/permutation_$(date +%Y%m%d).json
   export PERMUTATION_JSON=OUTPUTS/permutation_YYYYMMDD.json
   export PERMUTATION_OFFSET=0
   export PERMUTATION_CHUNK=50
   ```

5. **Ingest permutation chunks**
   ```sh
   forge script script/tools/IngestPermutation.s.sol \
     --rpc-url $SEPOLIA_RPC_URL \
     --broadcast --legacy \
     --private-key $PRIVATE_KEY
   ```

6. **Finalize permutation + renderers**
   ```sh
   cast send $MSONG_ADDRESS 'finalizePermutation()' --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   cast send $MSONG_ADDRESS 'finalizeRenderers()'   --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```

7. *(Optional)* Store permutation script pointer when ready:
   ```sh
   cast send $MSONG_ADDRESS 'setPermutationScript(address)' <SSTORE2_pointer> \
     --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
   ```

---

## 7. Token Setup & Burn Tests (E2MB)

- Set seven words (required before applying points):
  ```sh
  cast send $MSONG_ADDRESS \
    'setSevenWords(uint256,string)' \
    <TOKEN_ID> "word1|word2|word3|word4|word5|word6|word7" \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
  ```

- Confirm the gate is satisfied before queueing burns:
  ```sh
  cast call $MSONG_ADDRESS \
    'hasSevenWords(uint256)(bool)' \
    1 \
    --rpc-url $SEPOLIA_RPC_URL
  ```

- L1 burn helpers:
  ```sh
  cast send $L1_BURN_COLLECTOR_ADDRESS 'burnERC721(address,uint256,uint256)'  $DUMMY_ONE_OF_ONE_ADDRESS <ERC721_TOKEN_ID> <MSONG_TOKEN_ID> \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
  cast send $L1_BURN_COLLECTOR_ADDRESS 'burnERC1155(address,uint256,uint256,uint256)' $DUMMY_EDITION1155_ADDRESS <ID> <AMOUNT> <MSONG_TOKEN_ID> \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
  cast send $L1_BURN_COLLECTOR_ADDRESS 'burnERC20(address,uint256,uint256)'   $DUMMY_ERC20_ADDRESS <RAW_AMOUNT> <MSONG_TOKEN_ID> \
    --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY
  ```

- Points verification:
  ```sh
  cast call $POINTS_MANAGER_ADDRESS 'pointsOf(uint256)(uint256)' <TOKEN_ID> --rpc-url $SEPOLIA_RPC_URL
  cast call $MSONG_ADDRESS 'getCurrentRank(uint256)(uint256)'   <TOKEN_ID> --rpc-url $SEPOLIA_RPC_URL
  ```

---

## 8. Troubleshooting & Payload Replay

GET PAYLOAD
cast receipt --rpc-url $BASE_SEPOLIA_RPC_URL \
  0xd9149c3147c33764cdea94d0f6c3d4ca5702a34f0324bbf4296c417d8fdc12cd



- **LayerZero payload stuck?** Replay after fixing the underlying revert (e.g., missing seven words):
  ```sh
  cast send $L1_LAYERZERO_ENDPOINT \
    'retryPayload(uint32,bytes32,bytes)' \
    40245 \
    0x00000000000000000000000039b391df153c252e9486e7e3990b1c74289f9950 \
    0x0000000000000000000000000000000000000000000000000000000000000060
00000000000000000000000000000000000000000000000000000000000000a0
00000000000000000000000000000000000000000000000000000000000000e0
0000000000000000000000000000000000000000000000000000000000000001
0000000000000000000000000000000000000000000000000000000000000001
000000000000000000000000000000000000000000000000000000000000028a
0000000000000000000000000000000000000000000000000000000000000001
0000000000000000000000000000000000000000000000000000000000000020
000000000000000000000000000000000000000000000000000000000000000b
424153455f455243373231000000000000000000000000000000000000000000
 \
    --value 56656200994488 \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY
  ```
  *Use the exact `payload` emitted in the Base (or OP/ARB) `CheckpointSent` log.*

- **Seven-word gate check**:
  ```sh
  cast call $MSONG_ADDRESS 'hasSevenWords(uint256)(bool)' <TOKEN_ID> --rpc-url $SEPOLIA_RPC_URL
  ```

- **Pending burn queue inspection** (via events):
  ```sh
  cast logs --rpc-url $BASE_SEPOLIA_RPC_URL $BASE_BURN_COLLECTOR_ADDRESS \
    'BurnQueued(address,address,uint256,uint256,uint256,string)' \
    --from-block <startBlock>
  ```

---

Keep this file updated whenever scripts gain new side effects or addresses rotate. For longer checklists, cross-reference `points-checklist.md`. When in doubt, re-run the wiring verification before finalizing renderers—once they’re locked, E2MB cannot accept new pointers without a fresh deploy.
