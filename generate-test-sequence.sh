#!/bin/bash

# Generate Test Sequence - Wrapper script that creates output dirs and runs the generator
# Usage: ./generate-test-sequence.sh

# Get timestamp
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
OUTPUT_DIR="OUTPUTS/test-sequence-${TIMESTAMP}"

echo "=== Generating Test Sequence ==="
echo "Output directory: ${OUTPUT_DIR}"

# Create output directories
mkdir -p "${OUTPUT_DIR}/individual-beats"

# Run the Solidity script (which will use the pre-created directory)
# Note: The script currently uses a fixed timestamp; we'd need to modify it to use env vars
# For now, just ensure the directory from the script exists
mkdir -p "OUTPUTS/test-sequence-20251002-1/individual-beats"

forge script script/dev/GenerateTestSequence.s.sol

echo ""
echo "=== Generating MIDI file ==="

# Try to generate MIDI using Python script
if command -v python3 &> /dev/null; then
    if python3 -c "import mido" 2>/dev/null; then
        python3 convert-to-midi.py "OUTPUTS/test-sequence-20251002-1"
    else
        echo "⚠ Python mido library not found. Install with: pip install mido"
        echo "  Or convert ABC manually: abc2midi combined-sequence.abc -o output.mid"
    fi
else
    echo "⚠ Python3 not found. Install Python or use abc2midi directly."
fi

echo ""
echo "=== Generation Complete ==="
echo "Output: OUTPUTS/test-sequence-20251002-1"
echo ""
echo "Files generated:"
echo "  - combined-sequence.abc (ABC notation)"
echo "  - combined-sequence.mid (MIDI file)"
echo "  - combined-midi-info.json (MIDI data)"
echo "  - individual-beats/ (per-beat ABC and JSON)"
