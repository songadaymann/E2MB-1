#!/bin/bash

# Generate Blockchain Sequence - Wrapper that runs script and auto-converts to MIDI
# Usage: ./generate-blockchain-sequence.sh

echo "=== Generating Blockchain Simulation Sequence ==="

# Run the Solidity script (--ffi needed for date command and mkdir)
forge script script/dev/GenerateBlockchainSequence.s.sol --ffi

# Find the most recent blockchain-sim-* directory
OUTPUT_DIR=$(ls -td OUTPUTS/blockchain-sim-* 2>/dev/null | head -1)

if [ -z "$OUTPUT_DIR" ]; then
    echo "⚠ Error: No blockchain-sim output directory found"
    exit 1
fi

echo ""
echo "=== Generating MIDI file ==="
echo "Output directory: ${OUTPUT_DIR}"

# Try to generate MIDI using Python script
if command -v python3 &> /dev/null; then
    if python3 -c "import mido" 2>/dev/null; then
        python3 convert-to-midi.py "${OUTPUT_DIR}"
    else
        echo "⚠ Python mido library not found. Install with: pip install mido"
        echo "  Or convert ABC manually: abc2midi combined-sequence.abc -o output.mid"
    fi
else
    echo "⚠ Python3 not found. Install Python or use abc2midi directly."
fi

echo ""
echo "=== Generation Complete ==="
echo "Output: ${OUTPUT_DIR}"
echo ""
echo "Files generated:"
echo "  - combined-sequence.abc (ABC notation)"
echo "  - combined-sequence.mid (MIDI file)"
echo "  - combined-midi-info.json (MIDI data)"
echo "  - token_metadata.csv (token metadata)"
echo "  - individual-beats/ (per-beat ABC and JSON)"
echo ""
echo "Play MIDI with: timidity ${OUTPUT_DIR}/combined-sequence.mid"
