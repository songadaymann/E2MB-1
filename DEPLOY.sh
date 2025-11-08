#!/bin/bash
# Millennium Song - Phase 1 Deployment Script
# Deploys all contracts to Sepolia and mints/reveals a test token

set -e  # Exit on error

echo "======================================"
echo "Millennium Song - Phase 1 Deployment"
echo "======================================"
echo ""

# Load environment
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

source .env

if [ -z "$SEPOLIA_RPC_URL" ]; then
    echo "Error: SEPOLIA_RPC_URL not set in .env"
    exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
    echo "Error: PRIVATE_KEY not set in .env"
    exit 1
fi

echo "Using RPC: $SEPOLIA_RPC_URL"
echo "Deployer: $(cast wallet address $PRIVATE_KEY)"
echo ""

# Step 1: Deploy rendering contracts
echo "Step 1/5: Deploying rendering contracts..."
echo "This will take a few minutes..."
forge script script/deploy/01_DeployRenderers.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvv

if [ ! -f deployed-renderers.env ]; then
    echo "Error: deployed-renderers.env not created"
    exit 1
fi

echo "✓ Rendering contracts deployed"
echo ""

# Load renderer addresses
source deployed-renderers.env

# Step 2: Deploy main contract
echo "Step 2/5: Deploying MillenniumSong NFT..."
forge script script/deploy/02_DeployMain.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    --verify \
    -vvv

if [ ! -f deployed-main.env ]; then
    echo "Error: deployed-main.env not created"
    exit 1
fi

echo "✓ MillenniumSong deployed"
echo ""

# Load main contract address
source deployed-main.env

# Step 3: Wire renderers
echo "Step 3/5: Wiring renderers to main contract..."
forge script script/deploy/03_WireRenderers.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    -vvv

echo "✓ Renderers wired"
echo ""

# Step 4: Mint and reveal test token
echo "Step 4/5: Minting and revealing test token..."
forge script script/test/MintAndReveal.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --broadcast \
    -vvv

echo "✓ Test token minted and revealed"
echo ""

# Step 5: Decode and save metadata
echo "Step 5/5: Decoding metadata..."
forge script script/test/DecodeMetadata.s.sol \
    --sig 'run(uint256)' 1 \
    -vvv

echo "✓ Metadata decoded"
echo ""

# Extract files manually
echo "Extracting SVG and HTML..."
cat OUTPUTS/token-1-metadata.json | jq -r '.image' | sed 's/data:image\/svg+xml;base64,//' | base64 -d > OUTPUTS/token-1-image.svg
cat OUTPUTS/token-1-metadata.json | jq -r '.animation_url' | sed 's/data:text\/html;base64,//' | base64 -d > OUTPUTS/token-1-animation.html

echo "✓ Files extracted"
echo ""

echo "======================================"
echo "✓ DEPLOYMENT COMPLETE!"
echo "======================================"
echo ""
echo "Contract Address: $MSONG_ADDRESS"
echo ""
echo "Test token #1 revealed!"
echo ""
echo "View files:"
echo "  - Metadata JSON: OUTPUTS/token-1-metadata.json"
echo "  - SVG Image: OUTPUTS/token-1-image.svg"
echo "  - Animation HTML: OUTPUTS/token-1-animation.html"
echo ""
echo "Open in browser:"
echo "  open OUTPUTS/token-1-animation.html"
echo ""
echo "View on Rarible:"
echo "  https://testnet.rarible.com/token/sepolia/$MSONG_ADDRESS:1"
echo ""
echo "Addresses saved to:"
echo "  - deployed-renderers.env"
echo "  - deployed-main.env"
echo ""
