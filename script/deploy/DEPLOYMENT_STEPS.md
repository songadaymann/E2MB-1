# Deployment Steps - Refactored Architecture

## Prerequisites

Make sure your `.env` file has:
```bash
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
PRIVATE_KEY=your_private_key
```

---

## Step 1: Deploy NFT Contract

```bash
forge script script/deploy/02_DeployNewNFT.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --legacy
```

**Save the NFT address** to your `.env`:
```bash
NFT_ADDRESS=0x...
```

---

## Step 2: Deploy PointsManager

```bash
forge script script/deploy/01_DeployPointsManager.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --legacy
```

**Save the PointsManager address** to your `.env`:
```bash
POINTS_MANAGER_ADDRESS=0x...
```

---

## Step 3: Wire Everything Together

This connects:
- PointsManager to NFT
- Existing rendering contracts to NFT (from Session 3)

```bash
forge script script/deploy/03_WireContracts.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --legacy
```

---

## Step 4: Verify Wiring

Check all contracts are connected:

```bash
# Check renderers
cast call $NFT_ADDRESS "getSongAlgorithm()" --rpc-url $SEPOLIA_RPC_URL
cast call $NFT_ADDRESS "getMusicRenderer()" --rpc-url $SEPOLIA_RPC_URL
cast call $NFT_ADDRESS "getAudioRenderer()" --rpc-url $SEPOLIA_RPC_URL

# Check PointsManager
cast call $NFT_ADDRESS "pointsManager()" --rpc-url $SEPOLIA_RPC_URL

# Should return: 0xc0Da9A18f16807725dc0C6bEd7E49A2725D912A3 (SongAlgorithm)
# Should return: 0x9EB5f4DA5Eb104dd34AAf9397B9b178AdFA2DC81 (MusicRenderer)
# Should return: 0xF68310926327B76b102ddc5e25500A42F83DE7af (AudioRenderer)
# Should return: your PointsManager address
```

---

## Step 5: Test Minting

```bash
# Mint token #1
cast send $NFT_ADDRESS \
  "mint(address,uint32)" \
  YOUR_ADDRESS \
  12345 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy

# Get metadata (should show countdown)
cast call $NFT_ADDRESS "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL | \
  xxd -r -p | sed 's/^.*data:application\/json;base64,//' | base64 -d | jq '.'
```

---

## Step 6: Test Two-Step Reveal

```bash
# Step 1: Prepare reveal
cast send $NFT_ADDRESS \
  "prepareReveal(uint256)" 1 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy

# Step 2: Finalize reveal  
cast send $NFT_ADDRESS \
  "finalizeReveal(uint256)" 1 \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy \
  --gas-limit 300000

# Get metadata (should show staff notation)
cast call $NFT_ADDRESS "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL | \
  xxd -r -p | sed 's/^.*data:application\/json;base64,//' | base64 -d | jq '.'
```

---

## Step 7: Test Points System

```bash
# Add points to token #1
cast send $POINTS_MANAGER_ADDRESS \
  'addPoints(uint256,uint256,string)' \
  1 \
  100 \
  "Test" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy

# Check points
cast call $POINTS_MANAGER_ADDRESS "pointsOf(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL

# Check rank
cast call $POINTS_MANAGER_ADDRESS "currentRankOf(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL
```

---

## Step 8: Finalize (Optional)

⚠️ **WARNING**: This makes the contract immutable! Only do this when ready.

```bash
cast send $NFT_ADDRESS \
  "finalizeRenderers()" \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --legacy
```

After finalization:
- Cannot change renderers
- Cannot change PointsManager
- Contract is permanently locked

---

## Existing Rendering Contracts (Session 3)

These are already deployed and will be reused:

| Contract | Address |
|----------|---------|
| SongAlgorithm | `0xc0Da9A18f16807725dc0C6bEd7E49A2725D912A3` |
| MusicRendererOrchestrator | `0x9EB5f4DA5Eb104dd34AAf9397B9b178AdFA2DC81` |
| AudioRenderer | `0xF68310926327B76b102ddc5e25500A42F83DE7af` |
| SvgMusicGlyphs | `0xd6DF883c23337B0925012Da2646a6E7bA5D9083f` |
| StaffUtils | `0xF0ac54C0D3Fe7FCd911776F9B83C99d440cEe2F1` |
| MidiToStaff | `0xd3bada9A75268fa43dd6F6F6891d8cfAA5DD8Ff0` |
| NotePositioning | `0x64935B6349bfbEc5fB960EAc1e34c19539AA70C2` |

---

## Troubleshooting

### Gas Issues
If transactions fail with out-of-gas:
- Add `--gas-limit 500000` to cast send commands
- Use `--legacy` flag for better compatibility

### ABI Issues
If getting "function not found" errors:
- Verify addresses are correct in `.env`
- Check contract is deployed: `cast code $ADDRESS --rpc-url $SEPOLIA_RPC_URL`

### Verification Failed
If Etherscan verification fails:
```bash
forge verify-contract \
  $NFT_ADDRESS \
  src/core/EveryTwoMillionBlocks.sol:EveryTwoMillionBlocks \
  --chain sepolia \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

---

## Quick Deploy Script (All-in-One)

```bash
#!/bin/bash
set -e

# Load environment
source .env

# Step 1: Deploy NFT
echo "Deploying NFT..."
forge script script/deploy/02_DeployNewNFT.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --legacy
# Manually add NFT_ADDRESS to .env here

# Step 2: Deploy PointsManager
echo "Deploying PointsManager..."
forge script script/deploy/01_DeployPointsManager.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --legacy
# Manually add POINTS_MANAGER_ADDRESS to .env here

# Step 3: Wire
echo "Wiring contracts..."
forge script script/deploy/03_WireContracts.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --legacy

echo "Deployment complete!"
```

---

## Expected Output

After successful deployment, you should have:

✅ New NFT contract with refactored architecture  
✅ PointsManager connected to NFT  
✅ All rendering contracts wired  
✅ Working countdown (pre-reveal)  
✅ Working staff notation + audio (post-reveal)  
✅ Working points and ranking system  

Contract sizes:
- EveryTwoMillionBlocks: 23,433 B ✅
- PointsManager: 3,322 B ✅

All under 24KB limit with comfortable margins!
