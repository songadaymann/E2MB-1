#!/usr/bin/env python3
"""
Convert the generated MIDI JSON to an actual .mid file
Requires: pip install mido
"""

import json
import sys
from pathlib import Path

try:
    from mido import Message, MidiFile, MidiTrack, MetaMessage
except ImportError:
    print("Error: mido library not found")
    print("Install with: pip install mido")
    sys.exit(1)


def json_to_midi(json_path, output_path):
    """Convert MIDI JSON to .mid file"""
    
    # Read the JSON file
    with open(json_path, 'r') as f:
        data = json.load(f)
    
    metadata = data['metadata']
    events = data['events']
    
    print(f"Converting {len(events)} beats to MIDI...")
    seed_info = metadata.get('seed', metadata.get('collection', 'blockchain simulation'))
    print(f"Source: {seed_info}, Key: {metadata['key']}")
    
    # Create MIDI file
    mid = MidiFile(type=1)  # Type 1: multiple tracks, synchronous
    
    # Track 0: Tempo and metadata
    meta_track = MidiTrack()
    mid.tracks.append(meta_track)
    
    if 'collection' in metadata:
        track_name = f"Millennium Song - {metadata['collection']}"
    elif 'seed' in metadata:
        track_name = f"Millennium Song - Seed {metadata['seed']}"
    else:
        track_name = "Millennium Song"
    meta_track.append(MetaMessage('track_name', name=track_name, time=0))
    meta_track.append(MetaMessage('key_signature', key='Eb', time=0))
    meta_track.append(MetaMessage('time_signature', numerator=4, denominator=4, time=0))
    meta_track.append(MetaMessage('set_tempo', tempo=500000, time=0))  # 120 BPM
    
    # Track 1: Lead (treble)
    lead_track = MidiTrack()
    mid.tracks.append(lead_track)
    lead_track.append(MetaMessage('track_name', name='Lead', time=0))
    lead_track.append(Message('program_change', program=0, time=0))  # Acoustic Grand Piano
    
    # Track 2: Bass
    bass_track = MidiTrack()
    mid.tracks.append(bass_track)
    bass_track.append(MetaMessage('track_name', name='Bass', time=0))
    bass_track.append(Message('program_change', program=32, time=0))  # Acoustic Bass
    
    # Convert events to MIDI messages
    for event in events:
        beat = event['beat']
        lead = event['lead']
        bass = event['bass']
        
        # Lead note
        if lead['pitch'] >= 0:  # Not a rest
            # Note on
            lead_track.append(Message('note_on', note=lead['pitch'], velocity=80, time=0))
            # Note off (duration in ticks; 480 ticks = quarter note)
            lead_track.append(Message('note_off', note=lead['pitch'], velocity=0, time=lead['duration']))
        else:
            # Rest: just advance time
            lead_track.append(Message('note_on', note=0, velocity=0, time=lead['duration']))
        
        # Bass note (no rests in bass)
        bass_track.append(Message('note_on', note=bass['pitch'], velocity=70, time=0))
        bass_track.append(Message('note_off', note=bass['pitch'], velocity=0, time=bass['duration']))
    
    # Add end of track messages
    lead_track.append(MetaMessage('end_of_track', time=0))
    bass_track.append(MetaMessage('end_of_track', time=0))
    meta_track.append(MetaMessage('end_of_track', time=0))
    
    # Save MIDI file
    mid.save(output_path)
    print(f"✓ Saved MIDI file: {output_path}")
    print(f"  Tracks: {len(mid.tracks)}")
    print(f"  Length: {len(events)} beats")


def main():
    if len(sys.argv) < 2:
        print("Usage: python convert-to-midi.py <output-directory>")
        print("Example: python convert-to-midi.py OUTPUTS/test-sequence-20251002-1")
        sys.exit(1)
    
    output_dir = Path(sys.argv[1])
    
    if not output_dir.exists():
        print(f"Error: Directory not found: {output_dir}")
        sys.exit(1)
    
    json_file = output_dir / "combined-midi-info.json"
    midi_file = output_dir / "combined-sequence.mid"
    
    if not json_file.exists():
        print(f"Error: JSON file not found: {json_file}")
        sys.exit(1)
    
    json_to_midi(json_file, midi_file)
    print(f"\n✓ Done! Play with:")
    print(f"  timidity {midi_file}")
    print(f"  or open in your DAW/sequencer")


if __name__ == "__main__":
    main()
