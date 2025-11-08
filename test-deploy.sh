#!/bin/bash
set -e
source .env
source deployed-renderers.env

MSONG=0x2c4A66Eb9a12678cDc2f537378abced0ba80AF2c
SONG_ALGO=0xBfaAD2Fd28692F1F4E41d8DC8Ff4fA8f020006C6

echo "✅ MillenniumSong: $MSONG"
echo ""

echo "1. Setting renderers..."
cast send $MSONG "setRenderers(address,address,address)" $MUSIC_RENDERER_ADDRESS $AUDIO_RENDERER_ADDRESS $SONG_ALGO --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY > /dev/null 2>&1
echo "✅ Renderers set"

echo "2. Minting token..."
cast send $MSONG "mint(address,uint32)" 0xAd9fDaD276AB1A430fD03177A07350CD7C61E897 12345 --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY > /dev/null 2>&1
echo "✅ Token #1 minted"

echo "3. Getting tokenURI..."
cast call $MSONG "tokenURI(uint256)" 1 --rpc-url $SEPOLIA_RPC_URL | xxd -r -p | sed 's/^.*data:application\/json;base64,//' | base64 -d > OUTPUTS/token-1-metadata.json
echo "✅ Metadata saved"

echo "4. Extracting animation HTML..."
cat OUTPUTS/token-1-metadata.json | jq -r '.animation_url' | sed 's/data:text\/html;base64,//' | base64 -d > OUTPUTS/token-1-animation.html
echo "✅ Animation HTML saved"

echo ""
echo "=== DEPLOYMENT COMPLETE ==="
echo "Contract: $MSONG"
echo "View on Rarible: https://testnet.rarible.com/token/sepolia/$MSONG:1"
echo ""
echo "Open animation:"
echo "  open OUTPUTS/token-1-animation.html"
