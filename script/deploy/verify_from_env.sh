#!/bin/bash

# Verifies on-chain contracts using addresses exported in an env file (default: deployed.env).
# Requires ETHERSCAN_API_KEY in the environment (e.g., via .env).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_ENV_FILE="$ROOT_DIR/deployed.env"
ENV_FILE="${1:-$DEFAULT_ENV_FILE}"
NETWORK="${NETWORK:-sepolia}"
LOWER_NETWORK="$(printf '%s' "$NETWORK" | tr '[:upper:]' '[:lower:]')"
if [[ "$LOWER_NETWORK" == "" || "$LOWER_NETWORK" == "sepolia" || "$LOWER_NETWORK" == "11155111" ]]; then
  ETHERSCAN_URL="${ETHERSCAN_URL:-https://api-sepolia.etherscan.io/v2/api}"
elif [[ "$LOWER_NETWORK" == "mainnet" || "$LOWER_NETWORK" == "1" ]]; then
  ETHERSCAN_URL="${ETHERSCAN_URL:-https://api.etherscan.io/v2/api}"
else
  ETHERSCAN_URL="${ETHERSCAN_URL:-https://api-sepolia.etherscan.io/v2/api}"
fi
FORGE_BIN="${FORGE_BIN:-forge}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$ROOT_DIR/.env"
# shellcheck source=/dev/null
source "$ENV_FILE"

if [[ -z "${ETHERSCAN_API_KEY:-}" ]]; then
  echo "ETHERSCAN_API_KEY is not set. Populate it in .env before running." >&2
  exit 1
fi

forge_verify() {
  local address="$1"
  local target="$2"
  local constructor_args="${3:-}"

  if [[ -z "$address" || "$address" == "0x0000000000000000000000000000000000000000" ]]; then
    echo "Skipping $target (address empty)."
    return
  fi

  if [[ -z "$constructor_args" ]]; then
    "$FORGE_BIN" verify-contract \
      --verifier etherscan \
      --verifier-url "$ETHERSCAN_URL" \
      --etherscan-api-key "$ETHERSCAN_API_KEY" \
      --chain "$NETWORK" \
      --watch \
      "$address" "$target"
  else
    "$FORGE_BIN" verify-contract \
      --verifier etherscan \
      --verifier-url "$ETHERSCAN_URL" \
      --etherscan-api-key "$ETHERSCAN_API_KEY" \
      --chain "$NETWORK" \
      --constructor-args "$constructor_args" \
      --watch \
      "$address" "$target"
  fi
}

# Core NFT
forge_verify "${MSONG_ADDRESS:-}" "src/core/EveryTwoMillionBlocks.sol:EveryTwoMillionBlocks"

# Points stack
forge_verify "${POINTS_MANAGER_ADDRESS:-}" "src/points/PointsManager.sol:PointsManager"

if [[ -n "${POINTS_AGGREGATOR_ADDRESS:-}" ]]; then
  ctor=$(cast abi-encode "constructor(address)" "${POINTS_MANAGER_ADDRESS:-0x0000000000000000000000000000000000000000}")
  forge_verify "$POINTS_AGGREGATOR_ADDRESS" "src/points/PointsAggregator.sol:PointsAggregator" "$ctor"
fi

if [[ -n "${L1_BURN_COLLECTOR_ADDRESS:-}" ]]; then
  ctor=$(cast abi-encode "constructor(address,address)" \
    "${POINTS_AGGREGATOR_ADDRESS:-0x0000000000000000000000000000000000000000}" \
    "${SONG_A_DAY_COLLECTION_ADDRESS:-0x0000000000000000000000000000000000000000}")
  forge_verify "$L1_BURN_COLLECTOR_ADDRESS" "src/points/L1BurnCollector.sol:L1BurnCollector" "$ctor"
fi

# Renderers / supporting contracts (verify if addresses are present)
declare -A OPTIONAL_CONTRACTS=(
  ["SONG_ALGORITHM_ADDRESS"]="src/core/SongAlgorithm.sol:SongAlgorithm"
  ["MUSIC_RENDERER_ADDRESS"]="src/contracts/MusicRendererOrchestrator.sol:MusicRendererOrchestrator"
  ["AUDIO_RENDERER_ADDRESS"]="src/render/post/AudioRenderer.sol:AudioRenderer"
  ["COUNTDOWN_SVG_ADDRESS"]="src/render/pre/CountdownSvgRenderer.sol:CountdownSvgRenderer"
  ["COUNTDOWN_HTML_ADDRESS"]="src/render/pre/CountdownHtmlRenderer.sol:CountdownHtmlRenderer"
)

for var in "${!OPTIONAL_CONTRACTS[@]}"; do
  address="${!var:-}"
  target="${OPTIONAL_CONTRACTS[$var]}"
  forge_verify "$address" "$target"
done

echo "Verification commands submitted. Monitor forge output for status."
