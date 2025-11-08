#!/usr/bin/env python3
"""
Generate test data for reveal system testing

Creates 10 CSV files, each with 100 tokens worth of test data:
- tokenId (1-100)
- revealTimestamp (Jan 1 of sequential years starting 2026)
- previousNotesHash (rolling hash simulation)
- sevenWords (fake 7-word commitment as bytes32)
"""

import hashlib
import csv
import random
from pathlib import Path
from datetime import datetime

# Output directory
OUTPUT_DIR = Path("OUTPUTS/reveal-test-data")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Constants
START_YEAR = 2026
NUM_TOKENS = 100
NUM_CSV_FILES = 10

# Word bank for generating fake seven-word phrases
WORD_BANK = [
    "arpeggio", "crescendo", "diminuendo", "fermata", "glissando", "harmonic", "interval",
    "legato", "melody", "octave", "piano", "rhythm", "staccato", "tempo", "vibrato",
    "chord", "scale", "tonic", "dominant", "subdominant", "modulation", "cadence",
    "forte", "mezzo", "allegro", "adagio", "andante", "presto", "largo",
    "timbre", "resonance", "dissonance", "consonance", "chromatic", "diatonic", "enharmonic",
    "transpose", "inversion", "augment", "diminish", "syncopation", "rubato", "ostinato"
]


def year_to_jan1_timestamp(year):
    """Convert year to Unix timestamp of Jan 1, 00:00:00 UTC"""
    # Simplified calculation (doesn't account for leap years perfectly)
    # This matches the placeholder _jan1Timestamp() in the contract
    return (year - 1970) * 365 * 24 * 60 * 60


def generate_seven_words():
    """Generate a random 7-word phrase from word bank"""
    words = random.sample(WORD_BANK, 7)
    phrase = " | ".join(words)
    # Hash it to get bytes32
    hash_obj = hashlib.sha256(phrase.encode())
    return phrase, "0x" + hash_obj.hexdigest()


def simulate_previous_notes_hash(token_id, run_id):
    """
    Simulate a rolling previousNotesHash
    For token 1, hash is zero (no previous notes)
    For token N, hash includes all previous reveals
    """
    if token_id == 1:
        return "0x" + "00" * 32  # Zero hash for first token
    
    # Simulate rolling hash by hashing: previous hash + fake note data
    prev_hash = simulate_previous_notes_hash(token_id - 1, run_id)
    
    # Fake note data (just for simulation)
    fake_lead_pitch = 60 + (token_id % 12)  # C4 to B4 range
    fake_bass_pitch = 36 + (token_id % 12)  # C2 to B2 range
    fake_lead_dur = 480
    fake_bass_dur = 960
    
    # Hash it
    data = f"{prev_hash}{fake_lead_pitch}{fake_lead_dur}{fake_bass_pitch}{fake_bass_dur}{run_id}"
    hash_obj = hashlib.sha256(data.encode())
    return "0x" + hash_obj.hexdigest()


def generate_csv(run_id):
    """Generate a single CSV file with 100 tokens"""
    filename = OUTPUT_DIR / f"reveal-test-data-{run_id:02d}.csv"
    
    rows = []
    for token_id in range(1, NUM_TOKENS + 1):
        year = START_YEAR + token_id - 1  # Token 1 reveals in 2026, token 2 in 2027, etc.
        timestamp = year_to_jan1_timestamp(year)
        
        # Add some randomness to timestamp (±1 hour)
        timestamp += random.randint(-3600, 3600)
        
        previous_hash = simulate_previous_notes_hash(token_id, run_id)
        seven_words_phrase, seven_words_hash = generate_seven_words()
        
        rows.append({
            "tokenId": token_id,
            "revealYear": year,
            "revealTimestamp": timestamp,
            "previousNotesHash": previous_hash,
            "sevenWordsPhrase": seven_words_phrase,
            "sevenWordsHash": seven_words_hash,
        })
    
    # Write CSV
    with open(filename, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=[
            "tokenId", "revealYear", "revealTimestamp", 
            "previousNotesHash", "sevenWordsPhrase", "sevenWordsHash"
        ])
        writer.writeheader()
        writer.writerows(rows)
    
    print(f"Generated: {filename} ({len(rows)} tokens)")
    return filename


def main():
    print("=" * 60)
    print("GENERATING REVEAL TEST DATA")
    print("=" * 60)
    print(f"Output directory: {OUTPUT_DIR}")
    print(f"Generating {NUM_CSV_FILES} CSV files with {NUM_TOKENS} tokens each")
    print()
    
    generated_files = []
    for run_id in range(1, NUM_CSV_FILES + 1):
        filename = generate_csv(run_id)
        generated_files.append(filename)
    
    print()
    print("=" * 60)
    print("COMPLETE")
    print("=" * 60)
    print(f"Generated {len(generated_files)} CSV files:")
    for f in generated_files:
        print(f"  - {f}")
    print()
    print("Sample data from first file:")
    print()
    
    # Show first 5 rows of first file
    with open(generated_files[0], 'r') as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            if i >= 5:
                break
            print(f"Token {row['tokenId']} (Year {row['revealYear']}):")
            print(f"  Timestamp: {row['revealTimestamp']}")
            print(f"  Seven Words: {row['sevenWordsPhrase']}")
            print(f"  Seven Words Hash: {row['sevenWordsHash'][:18]}...")
            print(f"  Previous Hash: {row['previousNotesHash'][:18]}...")
            print()


if __name__ == "__main__":
    main()
