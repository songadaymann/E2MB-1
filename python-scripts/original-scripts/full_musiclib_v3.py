#!/usr/bin/env python3
"""
Complete MusicLib V3+V2 Python Implementation
Full tonnetz harmonic movement with chord progressions in Eb major
"""

import os
import json
import csv
import hashlib
import random
from dataclasses import dataclass
from typing import List, Tuple, Dict

@dataclass
class Event:
    pitch: int  # MIDI pitch, -1 for rest
    duration: int  # ticks (480 = quarter note)

@dataclass
class LeadState:
    chord: int          # chord index
    rng: int           # RNG state
    notes_since_rest: int

@dataclass
class BassState:
    chord: int          # chord index  
    rng: int           # RNG state
    previous_pitch: int # previous bass note for repetition logic

class CompleteMusicLibV3:
    def __init__(self):
        # Constants
        self.QUARTER = 480
        self.DOTTED_QUART = 720
        self.HALF_NOTE = 960
        self.WHOLE = 1920
        self.EIGHTH = 240
        self.SIXTEENTH = 120
        self.PHRASE_LEN = 8
        
        # CHANGED: Start in Eb major instead of C major
        self.BASE_KEY = 3  # Eb major (3 semitones up from C)
        
        # DIATONIC ONLY: Seven chords in Eb major
        self.DIATONIC_CHORDS = [
            6,   # Eb major (I)   - (3 << 1) | 0 = 6
            9,   # F minor (ii)   - (4 << 1) | 1 = 9  
            11,  # G minor (iii)  - (5 << 1) | 1 = 11
            16,  # Ab major (IV)  - (8 << 1) | 0 = 16
            20,  # Bb major (V)   - (10 << 1) | 0 = 20
            1,   # C minor (vi)   - (0 << 1) | 1 = 1
            5    # D diminished (vii°) - treat as D minor for now - (2 << 1) | 1 = 5
        ]

    def lcg_advance(self, state: int, seed_mod: int) -> int:
        """LCG RNG: state*1664525 + 1013904223 + seed_mod (mod 2^32)"""
        return (state * 1664525 + 1013904223 + seed_mod) & 0xFFFFFFFF

    def mix_seeds(self, a: int, b: int) -> int:
        """Deterministic seed mixing (same as Solidity _mix)"""
        s = a ^ (b * 0x9E3779B9)
        s ^= (s << 13) & 0xFFFFFFFF
        s ^= (s >> 17)
        s ^= (s << 5) & 0xFFFFFFFF
        return s & 0xFFFFFFFF

    def phrase_type(self, position: int) -> int:
        """Get phrase type: 0=A, 1=A', 2=B, 3=C"""
        m = (position // self.PHRASE_LEN) % 7
        if m in [0, 3, 6]: return 0  # A
        elif m in [1, 4]: return 1   # A'
        elif m == 2: return 2        # B
        else: return 3               # C

    def diatonic_neighbors(self, chord_idx: int) -> List[int]:
        """DIATONIC ONLY: Find neighboring chords that stay in Eb major"""
        # Simple diatonic movement: step up/down in the diatonic sequence
        current_pos = self.DIATONIC_CHORDS.index(chord_idx) if chord_idx in self.DIATONIC_CHORDS else 0
        
        neighbors = []
        # Add adjacent diatonic chords (wrap around)
        for offset in [-2, -1, 1, 2]:
            neighbor_pos = (current_pos + offset) % len(self.DIATONIC_CHORDS)
            neighbors.append(self.DIATONIC_CHORDS[neighbor_pos])
        
        # Add some functional harmony relationships
        if chord_idx == 6:  # Eb major (I) - go to ii, IV, V, vi
            neighbors.extend([9, 16, 20, 1])  # Fm, Ab, Bb, Cm
        elif chord_idx == 20:  # Bb major (V) - strong pull to I
            neighbors.extend([6, 1])  # Eb, Cm
        elif chord_idx == 16:  # Ab major (IV) - go to I, V
            neighbors.extend([6, 20])  # Eb, Bb
        
        # Remove duplicates and ensure all are diatonic
        return [n for n in set(neighbors) if n in self.DIATONIC_CHORDS][:6]  # Limit to 6 like original

    def neighbors(self, chord_idx: int) -> List[int]:
        """Use diatonic neighbors instead of full tonnetz"""
        return self.diatonic_neighbors(chord_idx)

    def preferred_areas(self, phrase_type: int) -> List[int]:
        """DIATONIC ONLY: Preferred harmonic areas using only Eb major chords"""
        if phrase_type == 0:  # A: I, V, IV
            return [6, 20, 16]  # Eb major, Bb major, Ab major
        elif phrase_type == 1:  # A': I, vi, iii  
            return [6, 1, 11]   # Eb major, C minor, G minor
        elif phrase_type == 2:  # B: ii, V, vi
            return [9, 20, 1]   # F minor, Bb major, C minor
        else:  # C: IV, I, V
            return [16, 6, 20]  # Ab major, Eb major, Bb major

    def motion_style(self, phrase_type: int) -> int:
        """Motion style by phrase type: 0=stable, 1=ornate, 2=exploratory, 3=conclusive"""
        return phrase_type  # 0=A, 1=A', 2=B, 3=C

    def choose_harmonic_movement(self, current_chord: int, phrase_type: int, rng_state: int, seed: int) -> Tuple[int, int]:
        """Full tonnetz harmonic movement logic (same as Solidity)"""
        nbrs = self.neighbors(current_chord)
        style = self.motion_style(phrase_type)
        pref = self.preferred_areas(phrase_type)
        
        new_state = self.lcg_advance(rng_state, seed)
        
        if style == 0:  # stable: usually stay; 1/8 chance to move
            if (new_state & 7) == 0:
                # Prefer tonic-area neighbors if present
                matches = [n for n in nbrs if n in pref]
                if matches:
                    idx = new_state % len(matches)
                    next_chord = matches[idx]
                else:
                    next_chord = nbrs[new_state % 6]
            else:
                next_chord = current_chord
        elif style == 1:  # ornate: 1/4 chance to move
            if (new_state & 3) == 0:
                next_chord = nbrs[new_state % len(nbrs)] if nbrs else current_chord
            else:
                next_chord = current_chord
        elif style == 2:  # exploratory: always move
            next_chord = nbrs[new_state % len(nbrs)] if nbrs else current_chord
        else:  # conclusive: move, prefer strong diatonic chords (I, IV, V)
            strong_chords = [6, 16, 20]  # Eb major (I), Ab major (IV), Bb major (V)
            candidates = [n for n in nbrs if n in strong_chords]
            
            if candidates:
                next_chord = candidates[new_state % len(candidates)]
            else:
                next_chord = nbrs[new_state % len(nbrs)] if nbrs else current_chord
        
        return next_chord, new_state

    def chord_to_pitches(self, chord_idx: int, octave: int) -> List[int]:
        """Convert chord index to MIDI pitches"""
        root = chord_idx >> 1
        is_minor = (chord_idx & 1) == 1
        
        base = octave * 12
        third = 3 if is_minor else 4
        fifth = 7
        
        return [
            base + root,
            base + (root + third) % 12,
            base + (root + fifth) % 12
        ]

    def should_rest_lead(self, phrase_type: int, pos_in_phrase: int, notes_since_rest: int, rng_state: int) -> bool:
        """Lead voice rest decision (V3 logic)"""
        min_len, max_len = 4, 8
        if notes_since_rest >= max_len: return True
        if notes_since_rest < min_len: return False
        
        # Rest chances by phrase and position
        if pos_in_phrase == 3: rest_chance = 6
        elif pos_in_phrase == 7: rest_chance = 3
        else:
            rest_chances = {0: 12, 1: 16, 2: 10, 3: 8}  # A, A', B, C
            rest_chance = rest_chances[phrase_type]
        
        return (rng_state & (rest_chance - 1)) == 0

    def get_duration_lead(self, phrase_type: int, rng_state: int) -> int:
        """IMPROVED: Get duration with Oracle's fix for phrase A variety"""
        if phrase_type == 0:  # A: IMPROVED with rhythm variety
            r = rng_state % 6
            if r < 3: return self.QUARTER      # 50% quarters
            elif r < 5: return self.EIGHTH     # 33% eighths  
            else: return self.DOTTED_QUART     # 17% dotted quarters
        elif phrase_type == 1:  # A'
            r = rng_state % 3
            return [self.EIGHTH, self.QUARTER, self.DOTTED_QUART][r]
        elif phrase_type == 2:  # B
            r = rng_state % 4
            return [self.SIXTEENTH, self.EIGHTH, self.QUARTER, self.HALF_NOTE][r]
        else:  # C
            r = rng_state % 3
            return [self.QUARTER, self.DOTTED_QUART, self.HALF_NOTE][r]

    def get_rest_duration(self, phrase_type: int, rng_state: int) -> int:
        """Get rest duration"""
        r = rng_state & 3
        if phrase_type in [2, 3]:  # B or C
            return [self.QUARTER, self.DOTTED_QUART, self.HALF_NOTE][r % 3]
        else:  # A or A'
            return self.QUARTER if (r & 1) == 0 else self.DOTTED_QUART
    
    def get_duration_bass(self, position: int) -> int:
        """PRESCRIBED: Bass duration pattern - half, quarter, half, eighth (cycling)"""
        pattern_position = position % 4
        if pattern_position == 0: return self.HALF_NOTE    # 1. half
        elif pattern_position == 1: return self.QUARTER   # 2. quarter  
        elif pattern_position == 2: return self.HALF_NOTE # 3. half
        else: return self.EIGHTH                          # 4. eighth

    def bass_chord_to_pitches(self, chord_idx: int, octave: int) -> List[int]:
        """Generate extended bass chord tones: root, fourth, fifth, sixth, second, minor fourth, third, 7th"""
        root = chord_idx >> 1
        is_minor = (chord_idx & 1) == 1
        
        base = octave * 12
        
        # Extended chord tones for bass
        return [
            base + root,                    # 1. root
            base + (root + 5) % 12,         # 2. fourth (perfect fourth)
            base + (root + 7) % 12,         # 3. fifth
            base + (root + 9) % 12,         # 4. sixth (major sixth)
            base + (root + 2) % 12,         # 5. second (major second)
            base + (root + 6) % 12,         # 6. minor fourth (tritone)
            base + (root + (3 if is_minor else 4)) % 12,  # 7. third
            base + (root + 10) % 12,        # 8. 7th (minor seventh)
        ]

    def choose_bass_tone(self, position: int, rng_state: int, previous_pitch: int, current_pitches: List[int]) -> int:
        """BASS-SPECIFIC: Choose chord tone with preference order and repetition"""
        r = rng_state & 15  # More bits for variety
        
        # REPETITION: High chance to repeat the same note (bass foundational behavior)
        if previous_pitch != -1 and previous_pitch in current_pitches:
            repeat_chance = 12  # 12/16 = 75% chance to repeat
            if r < repeat_chance:
                return previous_pitch
        
        # PREFERENCE ORDER: root, fourth, fifth, sixth, then less preferred others
        preference_weights = [
            8,  # 1. root - highest weight
            6,  # 2. fourth - strong bass note  
            7,  # 3. fifth - very strong
            4,  # 4. sixth - moderate
            2,  # 5. second - less preferred
            1,  # 6. minor fourth - rarely
            2,  # 7. third - less preferred for bass
            1   # 8. 7th - rarely
        ]
        
        # Weighted random selection
        total_weight = sum(preference_weights)
        rand_weight = (rng_state >> 4) % total_weight
        
        cumulative = 0
        for i, weight in enumerate(preference_weights):
            cumulative += weight
            if rand_weight < cumulative:
                return current_pitches[i] if i < len(current_pitches) else current_pitches[0]
        
        # Fallback to root
        return current_pitches[0]

    def choose_chord_tone_improved(self, pos_in_phrase: int, rng_state: int) -> int:
        """IMPROVED: Choose chord tone with anti-repetition logic"""
        r = rng_state & 7
        
        if pos_in_phrase == 0:
            # IMPROVED: Add variety to opening notes
            if r < 4: return 0    # 50% root
            elif r < 6: return 2  # 25% fifth
            else: return 1        # 25% third
        elif pos_in_phrase == 1:
            # IMPROVED: Avoid immediate repetition
            if r == 0: return 2   # favor fifth over root
            else: return r % 3
        elif pos_in_phrase == self.PHRASE_LEN - 1:
            return 0 if (r & 1) == 0 else 2  # root or fifth
        else:
            return r % 3

    def generate_lead_step(self, position: int, token_seed: int, state: LeadState) -> Tuple[Event, LeadState]:
        """Generate lead voice step (V3 with rests and full tonnetz)"""
        phrase_type = self.phrase_type(position)
        pos_in_phrase = position % self.PHRASE_LEN
        
        # Rest decision
        should_rest = self.should_rest_lead(phrase_type, pos_in_phrase, state.notes_since_rest, state.rng)
        if should_rest:
            duration = self.get_rest_duration(phrase_type, state.rng)
            event = Event(-1, duration)
            state.notes_since_rest = 0
            return event, state
        
        # MAJOR STRUCTURAL RESET every 50 beats - return to tonic for "downbeat" feeling
        if position % 50 == 0:
            state.chord = 6  # Reset to Eb major (I) - strong downbeat
            s = self.lcg_advance(state.rng, token_seed ^ 0x5050)
            state.rng = s
        # Cadence trigger (phrase boundary or every 4 beats)
        elif position % self.PHRASE_LEN == 0 or (position % 4 == 0):
            s = self.lcg_advance(state.rng, token_seed ^ 0x1234)
            state.rng = s
            nbrs = self.neighbors(state.chord)
            if nbrs:  # Make sure we have neighbors
                state.chord = nbrs[s % len(nbrs)]  # Move to neighbor
        
        # FULL TONNETZ: Choose harmonic movement based on phrase style
        new_chord, new_rng = self.choose_harmonic_movement(state.chord, phrase_type, state.rng, token_seed)
        state.rng = new_rng
        if new_chord != state.chord:
            state.chord = new_chord
        
        # VARIED OCTAVES BY PHRASE TYPE for better register coverage
        # Shifted up 1 octave for proper playback range
        if phrase_type == 0:    # A: low-middle
            octave = 5
        elif phrase_type == 1:  # A': high  
            octave = 6
        elif phrase_type == 2:  # B: middle (fills the missing middle register!)
            octave = 5
        else:  # phrase_type == 3, C: middle-high transition
            octave = 6
        
        pitches = self.chord_to_pitches(state.chord, octave)
        
        # For phrase B specifically, bias toward the higher tones in the chord
        if phrase_type == 2:
            # Use mostly third and fifth (indices 1 and 2) which are higher
            s = self.lcg_advance(state.rng, (token_seed * 2) & 0xFFFFFFFF)
            state.rng = s
            r = s & 7
            if r < 2:
                idx = 0  # 25% root
            elif r < 5:
                idx = 1  # 37.5% third (higher)
            else:
                idx = 2  # 37.5% fifth (highest)
        else:
            # Normal tone selection for other phrases
            s = self.lcg_advance(state.rng, (token_seed * 2) & 0xFFFFFFFF)
            state.rng = s
            idx = self.choose_chord_tone_improved(pos_in_phrase, s)
        
        # IMPROVED: Duration with variety
        duration = self.get_duration_lead(phrase_type, state.rng)
        event = Event(pitches[idx % 3], duration)
        
        state.notes_since_rest += 1
        return event, state

    def generate_bass_step(self, position: int, token_seed: int, state: BassState) -> Tuple[Event, BassState]:
        """Generate bass voice step (V2 no rests, full tonnetz)"""
        phrase_type = self.phrase_type(position)
        pos_in_phrase = position % self.PHRASE_LEN
        
        # MAJOR STRUCTURAL RESET every 50 beats - return to tonic for "downbeat" feeling
        if position % 50 == 0:
            state.chord = 6  # Reset to Eb major (I) - strong downbeat
            s = self.lcg_advance(state.rng, token_seed ^ 0x5050)
            state.rng = s
        # Cadence movement (same as lead)
        elif position % self.PHRASE_LEN == 0 or (position % 4 == 0):
            s = self.lcg_advance(state.rng, token_seed ^ 0x1234)
            state.rng = s
            nbrs = self.neighbors(state.chord)
            if nbrs:  # Make sure we have neighbors
                state.chord = nbrs[s % len(nbrs)]
        
        # FULL TONNETZ: Choose harmonic movement
        new_chord, new_rng = self.choose_harmonic_movement(state.chord, phrase_type, state.rng, token_seed)
        state.rng = new_rng
        if new_chord != state.chord:
            state.chord = new_chord
        
        # Bass octaves (shifted up 2 octaves for proper playback range)
        octave = 5 if phrase_type == 1 else 4
        pitches = self.bass_chord_to_pitches(state.chord, octave)
        
        # BASS-SPECIFIC: Tone choice with preference and repetition
        s = self.lcg_advance(state.rng, (token_seed * 2) & 0xFFFFFFFF)
        state.rng = s
        chosen_pitch = self.choose_bass_tone(position, s, state.previous_pitch, pitches)
        
        # PRESCRIBED: Bass uses fixed duration pattern
        duration = self.get_duration_bass(position)
        event = Event(chosen_pitch, duration)
        
        # Update previous pitch for next iteration
        state.previous_pitch = chosen_pitch
        
        return event, state

    def generate_beat(self, beat: int, token_seed: int) -> Tuple[Event, Event]:
        """Generate dual-voice beat with FULL V3+V2 tonnetz complexity"""
        
        # Initial states - START IN EB MAJOR (diatonic)
        lead_state = LeadState(
            chord=6,  # Eb major (diatonic chord index)
            rng=0xCAFEBABE,
            notes_since_rest=0
        )
        bass_state = BassState(
            chord=6,  # Eb major (diatonic chord index)
            rng=0xDEAFBEEF,
            previous_pitch=-1  # No previous pitch initially
        )
        
        # Simulate history up to beat-1 (FULL STATE PROGRESSION)
        for i in range(beat):
            seed = self.mix_seeds(token_seed, i)
            _, lead_state = self.generate_lead_step(i, seed, lead_state)
            _, bass_state = self.generate_bass_step(i, seed ^ 0x7777, bass_state)
        
        # Generate current beat
        seed_now = self.mix_seeds(token_seed, beat)
        lead_event, _ = self.generate_lead_step(beat, seed_now, lead_state)
        bass_event, _ = self.generate_bass_step(beat, seed_now ^ 0x7777, bass_state)
        
        return lead_event, bass_event

    def pitch_to_abc(self, pitch: int) -> str:
        """Convert MIDI pitch to ABC notation with proper Eb major key signature"""
        if pitch < 0:
            return "z"
        
        # Eb major key signature: Eb, F, G, Ab, Bb, C, D
        # Use flats for the black keys that belong to Eb major
        note_names_eb = ["C","_D","D","_E","E","F","_G","G","_A","A","_B","B"]
        octave = pitch // 12
        note_class = pitch % 12
        note = note_names_eb[note_class]
        
        if octave <= 3:
            # Uppercase with commas for low octaves
            for _ in range(4 - octave):
                note += ","
        elif octave == 4:
            # Uppercase, no modification (middle C octave)
            pass
        elif octave == 5:
            # Lowercase, no apostrophes
            note = note.lower()
        elif octave >= 6:
            # Lowercase with apostrophes for high octaves
            note = note.lower()
            for _ in range(octave - 5):
                note += "'"
        
        return note

    def duration_to_abc(self, ticks: int) -> str:
        """Convert duration ticks to ABC notation"""
        if ticks >= self.WHOLE: return "8"
        elif ticks >= self.HALF_NOTE: return "4"
        elif ticks >= self.DOTTED_QUART: return "3"
        elif ticks >= self.QUARTER: return "2"
        elif ticks >= self.EIGHTH: return ""
        else: return "/2"

    def chord_name(self, chord_idx: int) -> str:
        """Get chord name for debugging"""
        root = chord_idx >> 1
        is_minor = (chord_idx & 1) == 1
        note_names = ["C","Db","D","Eb","E","F","Gb","G","Ab","A","Bb","B"]
        quality = "m" if is_minor else "M"
        return f"{note_names[root]}{quality}"

def main():
    print("🎼 COMPLETE MUSICLIB V3+V2 IMPLEMENTATION")
    print("=" * 60)
    print("✨ FULL FEATURES:")
    print("   • Complete tonnetz harmonic movement")
    print("   • Chord progressions within Eb major")
    print("   • V3 lead (with rests) + V2 bass (no rests)")
    print("   • Oracle's rhythm improvements")
    print("   • Phrase grammar (A, A', B, A, A', C, A)")
    print("=" * 60)
    
    generator = CompleteMusicLibV3()
    
    # Test the chord progression system
    print(f"\n🎼 Testing harmonic movement in Eb major...")
    
    # Generate a short sequence to show chord changes
    test_seed = 12345
    print(f"First 16 beats chord progression:")
    
    # Track chord changes
    lead_state = LeadState(chord=(generator.BASE_KEY << 1) | 0, rng=0xCAFEBABE, notes_since_rest=0)
    bass_state = BassState(chord=(generator.BASE_KEY << 1) | 0, rng=0xBEEFCAFE)
    
    chord_progression = []
    
    for beat in range(16):
        # Show current chord
        chord_name = generator.chord_name(lead_state.chord)
        chord_progression.append(chord_name)
        
        if beat < 12:  # Don't spam
            print(f"   Beat {beat:2d}: {chord_name}")
        
        # Advance state
        seed = generator.mix_seeds(test_seed, beat)
        _, lead_state = generator.generate_lead_step(beat, seed, lead_state)
        _, bass_state = generator.generate_bass_step(beat, seed ^ 0x7777, bass_state)
    
    # Analyze chord variety
    unique_chords = len(set(chord_progression))
    print(f"\n📊 Harmonic Analysis:")
    print(f"   Unique chords in 16 beats: {unique_chords}")
    print(f"   Chord sequence: {' → '.join(chord_progression[:8])}...")
    print(f"   Expected: Rich chord progression in Eb major!")
    
    print(f"\n🎯 Ready to generate full timeline with REAL harmonic movement!")

if __name__ == "__main__":
    main()
