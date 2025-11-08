#!/usr/bin/env python3
"""
Generate reference output using Python full_musiclib_v3.py
Same structure as Solidity test output for comparison
"""

import sys
import json
from pathlib import Path
from datetime import datetime

# Import the Python MusicLib
sys.path.insert(0, 'python-scripts/original-scripts')
from full_musiclib_v3 import CompleteMusicLibV3

def main():
    # Same config as Solidity test
    seed = 12345
    start_beat = 0
    num_beats = 20
    
    print("=== GENERATING PYTHON REFERENCE ===")
    print(f"Seed: {seed}")
    print(f"Beats: {start_beat} to {start_beat + num_beats - 1}")
    
    # Create output directory
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    base_dir = Path(f"OUTPUTS/python-reference-{timestamp}")
    beats_dir = base_dir / "individual-beats"
    beats_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Output directory: {base_dir}")
    
    # Initialize library
    lib = CompleteMusicLibV3()
    
    # Collect data for combined files
    abc_beats = []
    midi_events = []
    
    # Generate each beat
    for i in range(num_beats):
        beat = start_beat + i
        year = 2026 + beat
        
        # Generate events
        lead, bass = lib.generate_beat(beat, seed)
        
        # 1. Individual ABC file (generate manually since method name may differ)
        lead_abc = lib.pitch_to_abc(lead.pitch) + lib.duration_to_abc(lead.duration)
        bass_abc = lib.pitch_to_abc(bass.pitch) + lib.duration_to_abc(bass.duration)
        abc_content = f"""X:1
T:Beat {beat + 1} - Era 1 Day {beat + 1} (Eb major)
M:4/4
L:1/8
Q:1/4=120
K:Eb
V:1 clef=treble
V:2 clef=bass
%%score (1 2)
V:1
{lead_abc} |
V:2
{bass_abc} |"""
        abc_file = beats_dir / f"beat-{beat}-year-{year}.abc"
        abc_file.write_text(abc_content)
        
        # 2. Individual MIDI JSON
        midi_json = {
            "beat": beat,
            "year": year,
            "lead": {"pitch": lead.pitch, "duration": lead.duration},
            "bass": {"pitch": bass.pitch, "duration": bass.duration}
        }
        json_file = beats_dir / f"beat-{beat}-year-{year}.json"
        json_file.write_text(json.dumps(midi_json, indent=2) + "\n")
        
        # Collect for combined files
        abc_beats.append(format_abc_beat(beat, year, lead, bass, lib))
        midi_events.append(midi_json)
        
        print(f"  Beat {beat}: Lead MIDI={lead.pitch:3d} Bass MIDI={bass.pitch:3d}")
    
    # 3. Combined ABC file
    combined_abc = generate_combined_abc(seed, start_beat, num_beats, abc_beats)
    (base_dir / "combined-sequence.abc").write_text(combined_abc)
    
    # 4. Combined MIDI info
    combined_midi = {
        "metadata": {
            "seed": seed,
            "startBeat": start_beat,
            "numBeats": num_beats,
            "key": "Eb major",
            "algorithm": "Python full_musiclib_v3.py"
        },
        "events": midi_events
    }
    (base_dir / "combined-midi-info.json").write_text(json.dumps(combined_midi, indent=2) + "\n")
    
    # 5. Summary
    summary = f"""# Python Reference Output

**Generated:** {timestamp}
**Seed:** {seed}
**Beats:** {start_beat} to {start_beat + num_beats - 1} ({num_beats} total)
**Algorithm:** Python full_musiclib_v3.py (Eb major)

## Files

- `individual-beats/` - Individual ABC and JSON files for each beat
- `combined-sequence.abc` - All beats in single ABC file for playback
- `combined-midi-info.json` - MIDI event data for all beats

## Usage

**Convert to MIDI:**
```bash
cd {base_dir}
abc2midi combined-sequence.abc -o combined-sequence.mid
# or
python3 ../../convert-to-midi.py .
```

**Play:**
```bash
timidity combined-sequence.mid
```

## Comparison

This output is generated from the **Python** implementation.
Compare with Solidity output in `OUTPUTS/test-sequence-*/`
"""
    (base_dir / "README.md").write_text(summary)
    
    print(f"\n=== OUTPUT SUMMARY ===")
    print(f"Individual beats: {num_beats}")
    print(f"Combined ABC: {base_dir}/combined-sequence.abc")
    print(f"Combined MIDI: {base_dir}/combined-midi-info.json")
    print(f"\nTo convert to MIDI:")
    print(f"  python3 convert-to-midi.py {base_dir}")


def format_abc_beat(beat, year, lead, bass, lib):
    """Format one beat for combined ABC"""
    lead_note = lib.pitch_to_abc(lead.pitch)
    lead_dur = lib.duration_to_abc(lead.duration)
    bass_note = lib.pitch_to_abc(bass.pitch)
    bass_dur = lib.duration_to_abc(bass.duration)
    
    return f"""% Beat {beat} - Year {year}
[V:1] {lead_note}{lead_dur} |
[V:2] {bass_note}{bass_dur} |"""


def generate_combined_abc(seed, start_beat, num_beats, abc_beats):
    """Generate combined ABC file"""
    header = f"""X:1
T:Millennium Song - Python Reference
C:Seed {seed} | Beats {start_beat}-{start_beat + num_beats - 1}
M:4/4
L:1/8
K:Eb
V:1 clef=treble name="Lead"
V:2 clef=bass name="Bass"
"""
    
    return header + "\n".join(abc_beats)


if __name__ == "__main__":
    main()
