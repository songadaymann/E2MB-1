# Blockchain Simulation Test - Complete Trace

## Test Execution Flow

### Python Version (`blockchain_simulation_generator.py`)

```
1. Script starts with collection phrase: "half the battle's just gettin outta bed"
   └─> Creates collection_salt via SHA256 hash

2. For each token (e.g., token 1000, reveal_index 0):
   ├─> Generate seven_words from tokenId + collectionSalt
   ├─> Generate previous_notes_hash (empty for beat 0)
   ├─> Generate global_state_hash (year, reveal count, etc.)
   └─> Create final_seed = SHA256(collectionSalt + tokenId + seven_words + prev + global)
       └─> Convert to int: seed_int = int(final_seed[:8], 16)

3. Call music_generator.generate_beat(reveal_index, seed_int)
   └─> full_musiclib_v3.py line 143

4. In CompleteMusicLibV3.generate_beat(beat, token_seed):
   ├─> Initialize states:
   │   ├─> LeadState(chord=6, rng=0xCAFEBABE, notes_since_rest=0)
   │   └─> BassState(chord=6, rng=0xDEAFBEEF, previous_pitch=-1)
   │
   ├─> Simulate history for beats 0 to (beat-1):
   │   └─> For each i in range(beat):
   │       ├─> seed = mix_seeds(token_seed, i)
   │       ├─> generate_lead_step(i, seed, lead_state)
   │       └─> generate_bass_step(i, seed ^ 0x7777, bass_state)
   │
   └─> Generate current beat:
       ├─> seed_now = mix_seeds(token_seed, beat)
       └─> Return: lead_event, bass_event

5. In generate_lead_step() - LINE 290-357:
   ├─> Calculate phrase_type = phrase_type(position)
   ├─> Decide if rest needed
   ├─> Choose harmonic movement (diatonic neighbors)
   │
   └─> **OCTAVE SELECTION** (lines 322-330):
       ├─> if phrase_type == 0:  octave = 4  # A: low-middle
       ├─> elif phrase_type == 1: octave = 5  # A': high
       ├─> elif phrase_type == 2: octave = 4  # B: middle
       └─> else:                  octave = 5  # C: middle-high
   
   └─> pitches = chord_to_pitches(chord, octave)
       └─> base = octave * 12
           ├─> octave 4 → MIDI 48-59 (C3-B3 in music software convention)
           └─> octave 5 → MIDI 60-71 (C4-B4 in music software convention)

6. In generate_bass_step() - LINE 359-398:
   ├─> Calculate phrase_type = phrase_type(position)
   ├─> Choose harmonic movement (diatonic neighbors)
   │
   └─> **OCTAVE SELECTION** (line 384):
       └─> octave = 3 if phrase_type == 1 else 2
   
   └─> pitches = bass_chord_to_pitches(chord, octave)
       └─> base = octave * 12
           ├─> octave 2 → MIDI 24-35 (C1-B1)
           └─> octave 3 → MIDI 36-47 (C2-B2)

7. Convert MIDI to ABC notation (lines 429-457):
   └─> pitch_to_abc() uses:
       ├─> octave <= 3: uppercase + commas (C,,, C,, C,)
       ├─> octave == 4: uppercase (C, D, E...) ← BASE OCTAVE
       ├─> octave == 5: lowercase (c, d, e...)
       └─> octave >= 6: lowercase + apostrophes (c', d'...)
```

### Solidity Version (`GenerateBlockchainSequence.s.sol` + `SongAlgorithm.sol`)

```
1. Script starts with same collection phrase: "half the battle's just gettin outta bed"
   └─> Creates collectionSalt via keccak256

2. For each token (e.g., token 1000, reveal_index 0):
   ├─> Generate seven words from tokenId + collectionSalt (different method than Python)
   ├─> Generate previousNotesHash (bytes32(0) for beat 0)
   ├─> Generate globalStateHash (keccak256 of reveal info)
   └─> Create finalSeed = keccak256(collectionSalt + tokenId + sevenWords + prev + global)
       └─> Convert to uint32: seedInt = uint32(uint256(finalSeed) >> 224)

3. Call SongAlgorithm.generateBeat(revealIndex, seedInt)
   └─> SongAlgorithm.sol line 137

4. In SongAlgorithm.generateBeat(beat, tokenSeed) - LINES 541-571:
   ├─> Initialize states:
   │   ├─> LeadState(chord=0, rng=0xCAFEBABE, notesSinceRest=0)
   │   └─> BassState(chord=0, rng=0xDEAFBEEF, previousPitch=-1)
   │
   ├─> Apply 365-beat era system:
   │   ├─> effectiveBeat = beat % 365
   │   └─> era = beat / 365
   │
   ├─> Simulate history for beats 0 to (effectiveBeat-1):
   │   └─> For i in 0..effectiveBeat:
   │       ├─> seed = _mix(tokenSeed, i)
   │       ├─> _leadGenerateStep(i, seed, L)
   │       └─> _bassGenerateStep(i, seed ^ 0x7777, B)
   │
   └─> Generate current beat:
       ├─> sNow = _mix(tokenSeed, effectiveBeat)
       └─> Return: lead, bass events

5. In _leadGenerateStep() - LINES 375-443:
   ├─> Calculate phraseType = _phraseType(position)
   ├─> Decide if rest needed
   ├─> Choose harmonic movement (_diatonicNeighbors)
   │
   └─> **OCTAVE SELECTION (UPDATED)** (lines 408-413):
       ├─> if (phraseType == 0) octave = 5;      # CHANGED FROM 4
       ├─> else if (phraseType == 1) octave = 6; # CHANGED FROM 5
       ├─> else if (phraseType == 2) octave = 5; # CHANGED FROM 4
       └─> else octave = 6;                      # CHANGED FROM 5
   
   └─> tones = _chordToPitches(chord, octave)
       └─> base = octave * 12
           ├─> octave 5 → MIDI 60-71 (C4-B4)
           └─> octave 6 → MIDI 72-83 (C5-B5)

6. In _bassGenerateStep() - LINES 445-490:
   ├─> Calculate phraseType = _phraseType(position)
   ├─> Choose harmonic movement (_diatonicNeighbors)
   │
   └─> **OCTAVE SELECTION (UPDATED)** (line 472):
       └─> octave = (phraseType == 1) ? 4 : 3;  # CHANGED FROM 3:2
   
   └─> pitches = _bassChordToPitches(chord, octave)
       └─> base = octave * 12
           ├─> octave 3 → MIDI 36-47 (C2-B2)
           └─> octave 4 → MIDI 48-59 (C3-B3)

7. Convert MIDI to ABC notation (lines 501-528):
   └─> _pitchToAbcEb() uses SAME LOGIC AS PYTHON:
       ├─> oct <= 3: uppercase + commas
       ├─> oct == 4: uppercase (C, D, E...) ← BASE OCTAVE
       ├─> oct == 5: lowercase (c, d, e...)
       └─> oct >= 6: lowercase + apostrophes
```

## Key Differences Summary

| Component | Python (Original) | Solidity (Updated) | Difference |
|-----------|------------------|-------------------|------------|
| **Lead Octaves** | 4-5 | 5-6 | **+1 octave** |
| **Bass Octaves** | 2-3 | 3-4 | **+1 octave** |
| **Lead MIDI Range** | 48-71 (C3-B4) | 60-83 (C4-B5) | **+12 semitones** |
| **Bass MIDI Range** | 24-47 (C1-B2) | 36-59 (C2-B3) | **+12 semitones** |
| **ABC Conversion** | Same | Same | **Identical logic** |

## The Octave Confusion Issue

Both versions were using **Scientific Pitch Notation (SPN)** where:
- Octave 4 = MIDI 48-59
- Octave 5 = MIDI 60-71

But the ABC rendering (from svg-staff-reveal-ideas/progress.md) revealed that the **music software convention** treats:
- **C3 = middle C (MIDI 60)** NOT C4!

This means:
1. Python was generating notes in **SPN octaves 4-5** → Too low
2. Solidity was initially generating the same → Too low  
3. Solidity was then shifted up by 1 octave → **Correct for music software**
4. Python still needs the same +1 octave shift

## Result

- **Solidity output (after fix)**: Bass in octaves 3-4 (C2-B3), Lead in 5-6 (C4-B5) ✓
- **Python output (current)**: Bass in octaves 2-3 (C1-B2), Lead in 4-5 (C3-B4) ✗

Both are now using identical algorithm logic, but Python needs the same octave shift to match the music software convention.
