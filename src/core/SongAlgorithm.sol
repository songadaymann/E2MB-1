// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/ISongAlgorithm.sol";

contract SongAlgorithm is ISongAlgorithm {
    // ===== Types =====
    // Event struct lives in ISongAlgorithm

    struct LeadState {
        uint8 chord;          // diatonic chord index (0-6)
        uint32 rng;           // 32-bit RNG state
        uint16 notesSinceRest;
    }

    struct BassState {
        uint8 chord;          // diatonic chord index (0-6)
        uint32 rng;           // 32-bit RNG state
        int16 previousPitch;  // for repetition logic
    }

    // ===== Constants =====
    uint16 constant QUARTER       = 480;
    uint16 constant DOTTED_QUART  = 720;
    uint16 constant HALF_NOTE     = 960;
    uint16 constant WHOLE         = 1920;
    uint16 constant EIGHTH        = 240;
    uint16 constant SIXTEENTH     = 120;
    uint8 constant PHRASE_LEN     = 8;
    uint8 constant BASE_KEY       = 3;  // Eb major (3 semitones up from C)

    // Diatonic chord lookup for Eb major (arrays can't be constexpr in Solidity)
    function _getDiatonicChord(uint8 index) private pure returns (uint8) {
        if (index == 0) return 6;  // Eb major (I)
        if (index == 1) return 9;  // F minor (ii)  
        if (index == 2) return 11; // G minor (iii)
        if (index == 3) return 16; // Ab major (IV)
        if (index == 4) return 20; // Bb major (V)
        if (index == 5) return 1;  // C minor (vi)
        if (index == 6) return 5;  // D diminished (vii°)
        return 6; // tonic fallback
    }

    // ===== Phrase Grammar =====
    function _phraseType(uint32 position) private pure returns (uint8) {
        uint8 m = uint8((position / PHRASE_LEN) % 7);
        if (m == 0 || m == 3 || m == 6) return 0;  // A
        if (m == 1 || m == 4) return 1;            // A'
        if (m == 2) return 2;                      // B
        return 3;                                  // C
    }

    // ===== RNG (LCG, 32-bit) =====
    function _adv(uint32 state, uint32 seedMod) private pure returns (uint32) {
        unchecked {
            return state * 1664525 + 1013904223 + seedMod;
        }
    }

    function _mix(uint32 a, uint32 b) private pure returns (uint32) {
        unchecked {
            uint32 s = a ^ (b * 0x9E3779B9);
            s ^= (s << 13);
            s ^= (s >> 17);
            s ^= (s << 5);
            return s;
        }
    }

    // ===== Diatonic Harmony System =====
    function _diatonicNeighbors(uint8 chordIdx) private pure returns (uint8[6] memory out) {
        // Find position in diatonic sequence
        uint8 currentPos = 0;
        for (uint8 i = 0; i < 7; i++) {
            if (_getDiatonicChord(i) == chordIdx) {
                currentPos = i;
                break;
            }
        }

        uint8 count = 0;
        
        // Add adjacent diatonic chords
        for (int8 offset = -2; offset <= 2; offset++) {
            if (offset != 0 && count < 6) {
                uint8 neighborPos = uint8((int8(currentPos) + offset + 7) % 7);
                out[count++] = _getDiatonicChord(neighborPos);
            }
        }

        // Add functional harmony relationships
        if (chordIdx == 6 && count < 6) {  // Eb major (I) -> ii,IV,V,vi
            out[count++] = 9;  // Fm (ii)
            if (count < 6) out[count++] = 16; // Ab (IV)
        } else if (chordIdx == 20 && count < 6) { // Bb major (V) -> I,vi
            out[count++] = 6;  // Eb (I)
            if (count < 6) out[count++] = 1;  // Cm (vi)
        } else if (chordIdx == 16 && count < 6) { // Ab major (IV) -> I,V
            out[count++] = 6;  // Eb (I)
            if (count < 6) out[count++] = 20; // Bb (V)
        }

        // Fill remaining slots if needed
        while (count < 6) {
            out[count++] = _getDiatonicChord(0); // Default to tonic
        }
    }

    function _preferredAreas(uint8 phraseType) private pure returns (uint8[3] memory pref) {
        if (phraseType == 0) {      // A: I, V, IV
            pref[0] = 6; pref[1] = 20; pref[2] = 16;  // Eb, Bb, Ab
        } else if (phraseType == 1) { // A': I, vi, iii
            pref[0] = 6; pref[1] = 1; pref[2] = 11;   // Eb, Cm, Gm
        } else if (phraseType == 2) { // B: ii, V, vi
            pref[0] = 9; pref[1] = 20; pref[2] = 1;   // Fm, Bb, Cm
        } else {                    // C: IV, I, V
            pref[0] = 16; pref[1] = 6; pref[2] = 20;  // Ab, Eb, Bb
        }
    }

    function _motionStyle(uint8 phraseType) private pure returns (uint8) {
        return phraseType; // 0=stable, 1=ornate, 2=exploratory, 3=conclusive
    }

    function _chooseHarmonicMovement(
        uint8 currentChord,
        uint8 phraseType,
        uint32 rngState,
        uint32 seed
    ) private pure returns (uint8 nextChord, uint32 newState) {
        uint8[6] memory nbrs = _diatonicNeighbors(currentChord);
        uint8 style = _motionStyle(phraseType);
        uint8[3] memory pref = _preferredAreas(phraseType);

        newState = _adv(rngState, seed);

        if (style == 0) { // stable: 1/8 chance to move
            if ((newState & 7) == 0) {
                // Prefer tonic-area neighbors
                uint8 matches;
                for (uint8 i = 0; i < 6; i++) {
                    uint8 n = nbrs[i];
                    if (n == pref[0] || n == pref[1] || n == pref[2]) {
                        matches++;
                    }
                }
                if (matches > 0) {
                    uint8 idx = uint8(newState % matches);
                    uint8 seen;
                    for (uint8 i = 0; i < 6; i++) {
                        uint8 n = nbrs[i];
                        if (n == pref[0] || n == pref[1] || n == pref[2]) {
                            if (seen == idx) { nextChord = n; break; }
                            seen++;
                        }
                    }
                } else {
                    nextChord = nbrs[uint8(newState % 6)];
                }
            } else {
                nextChord = currentChord;
            }
        } else if (style == 1) { // ornate: 1/4 chance to move
            if ((newState & 3) == 0) {
                nextChord = nbrs[uint8(newState % 6)];
            } else {
                nextChord = currentChord;
            }
        } else if (style == 2) { // exploratory: always move
            nextChord = nbrs[uint8(newState % 6)];
        } else { // conclusive: prefer I,IV,V
            uint8[3] memory strongChords = [6, 16, 20]; // Eb, Ab, Bb
            uint8 c; uint8[6] memory pool;
            for (uint8 i = 0; i < 6; i++) {
                uint8 n = nbrs[i];
                if (n == strongChords[0] || n == strongChords[1] || n == strongChords[2]) {
                    pool[c++] = n;
                }
            }
            if (c > 0) {
                nextChord = pool[uint8(newState % c)];
            } else {
                nextChord = nbrs[uint8(newState % 6)];
            }
        }
    }

    // ===== Diatonic Scale Mapping =====
    
    /// @notice Returns pitch class (0-11) for Eb major scale degree (0-6)
    /// @dev Eb major: Eb(3), F(5), G(7), Ab(8), Bb(10), C(0), D(2)
    function _ebMajorScale(uint8 degree) private pure returns (uint8) {
        if (degree == 0) return 3;   // Eb
        if (degree == 1) return 5;   // F
        if (degree == 2) return 7;   // G
        if (degree == 3) return 8;   // Ab
        if (degree == 4) return 10;  // Bb
        if (degree == 5) return 0;   // C
        if (degree == 6) return 2;   // D
        return 3; // tonic fallback
    }
    
    /// @notice Maps diatonic chord index to scale degree (0-6)
    /// @dev Diatonic chords: I(Eb)=6, ii(F)=9, iii(G)=11, IV(Ab)=16, V(Bb)=20, vi(C)=1, vii(D)=5
    function _chordIdxToScaleDegree(uint8 chordIdx) private pure returns (uint8) {
        if (chordIdx == 6) return 0;   // I (Eb)
        if (chordIdx == 9) return 1;   // ii (F)
        if (chordIdx == 11) return 2;  // iii (G)
        if (chordIdx == 16) return 3;  // IV (Ab)
        if (chordIdx == 20) return 4;  // V (Bb)
        if (chordIdx == 1) return 5;   // vi (C)
        if (chordIdx == 5) return 6;   // vii (D)
        return 0; // tonic fallback
    }

    // ===== Chord Conversion (Diatonic) =====
    function _chordToPitches(uint8 chordIdx, uint8 octave)
        private pure returns (uint8[3] memory tones)
    {
        uint8 scaleDegree = _chordIdxToScaleDegree(chordIdx);
        uint8 base = octave * 12;
        
        // Build chord from diatonic scale degrees (root, third, fifth)
        uint8 root = _ebMajorScale(scaleDegree);
        uint8 third = _ebMajorScale((scaleDegree + 2) % 7);  // Scale degree +2 = diatonic 3rd
        uint8 fifth = _ebMajorScale((scaleDegree + 4) % 7);  // Scale degree +4 = diatonic 5th
        
        tones[0] = base + root;
        tones[1] = base + third;
        tones[2] = base + fifth;
        
        // Handle octave wrap for proper chord voicing
        if (tones[1] < tones[0]) tones[1] += 12;
        if (tones[2] < tones[1]) tones[2] += 12;
        
        // Clamp lead register to C3..Bb4
        for (uint8 i = 0; i < 3; i++) {
            while (tones[i] < 48) tones[i] += 12;
            while (tones[i] > 70) tones[i] -= 12;
        }
    }

    function _bassChordToPitches(uint8 chordIdx, uint8 octave)
        private pure returns (uint8[8] memory tones)
    {
        uint8 scaleDegree = _chordIdxToScaleDegree(chordIdx);
        uint8 base = octave * 12;
        
        // Extended bass chord tones (root, 4th, 5th, 6th, 2nd, b5, 3rd, 7th)
        tones[0] = base + _ebMajorScale(scaleDegree);                    // 1. root
        tones[1] = base + _ebMajorScale((scaleDegree + 3) % 7);          // 2. fourth
        tones[2] = base + _ebMajorScale((scaleDegree + 4) % 7);          // 3. fifth
        tones[3] = base + _ebMajorScale((scaleDegree + 5) % 7);          // 4. sixth
        tones[4] = base + _ebMajorScale((scaleDegree + 1) % 7);          // 5. second
        tones[5] = base + _ebMajorScale((scaleDegree + 3) % 7);          // 6. fourth (was tritone, using 4th for diatonic)
        tones[6] = base + _ebMajorScale((scaleDegree + 2) % 7);          // 7. third
        tones[7] = base + _ebMajorScale((scaleDegree + 6) % 7);          // 8. seventh
        
        // Ensure each tone is above the root
        for (uint8 i = 1; i < 8; i++) {
            if (tones[i] < tones[0]) tones[i] += 12;
        }
        
        // Clamp bass register to C1..Bb2
        for (uint8 i = 0; i < 8; i++) {
            while (tones[i] < 24) tones[i] += 12;
            while (tones[i] > 46) tones[i] -= 12;
        }
    }

    // ===== Duration Helpers =====
    function _getDurationLead(uint8 phraseType, uint32 rngState) private pure returns (uint16) {
        if (phraseType == 0) { // A: Oracle's improved variety
            uint8 r = uint8(rngState % 6);
            if (r < 3) return QUARTER;      // 50% quarters
            if (r < 5) return EIGHTH;       // 33% eighths
            return DOTTED_QUART;            // 17% dotted quarters
        } else if (phraseType == 1) { // A'
            uint8 r = uint8(rngState % 3);
            if (r == 0) return EIGHTH;
            if (r == 1) return QUARTER;
            return DOTTED_QUART;
        } else if (phraseType == 2) { // B
            uint8 r = uint8(rngState % 4);
            if (r == 0) return SIXTEENTH;
            if (r == 1) return EIGHTH;
            if (r == 2) return QUARTER;
            return HALF_NOTE;
        } else { // C
            uint8 r = uint8(rngState % 3);
            if (r == 0) return QUARTER;
            if (r == 1) return DOTTED_QUART;
            return HALF_NOTE;
        }
    }

    function _getDurationBass(uint32 position) private pure returns (uint16) {
        // Bass duration cycle: half, quarter, half, eighth
        uint8 patternPos = uint8(position % 4);
        if (patternPos == 0) return HALF_NOTE;  // 1. half
        if (patternPos == 1) return QUARTER;    // 2. quarter
        if (patternPos == 2) return HALF_NOTE;  // 3. half
        return EIGHTH;                          // 4. eighth
    }

    function _getRestDuration(uint8 phraseType, uint32 rngState) private pure returns (uint16) {
        uint8 r = uint8(rngState & 3);
        if (phraseType == 2 || phraseType == 3) { // B or C
            if (r == 0) return QUARTER;
            if (r == 1) return DOTTED_QUART;
            return HALF_NOTE;
        } else { // A or A'
            return (r & 1) == 0 ? QUARTER : DOTTED_QUART;
        }
    }

    // ===== Lead Voice =====
    function _leadShouldRest(
        uint8 phraseType,
        uint8 posInPhrase,
        uint16 notesSinceRest,
        uint32 rngState
    ) private pure returns (bool) {
        if (notesSinceRest >= 8) return true;  // force rest
        if (notesSinceRest < 4)  return false; // too early

        uint8 restChance;
        if (posInPhrase == 3) restChance = 6;
        else if (posInPhrase == 7) restChance = 3;
        else {
            if (phraseType == 0) restChance = 12;       // A
            else if (phraseType == 1) restChance = 16;  // A'
            else if (phraseType == 2) restChance = 10;  // B
            else restChance = 8;                        // C
        }

        return (rngState & (uint32(restChance) - 1)) == 0;
    }

    function _chooseChordToneImproved(uint8 posInPhrase, uint32 rngState) private pure returns (uint8) {
        uint8 r = uint8(rngState & 7);
        
        if (posInPhrase == 0) {
            // Add variety to opening notes
            if (r < 4) return 0;    // 50% root
            if (r < 6) return 2;    // 25% fifth  
            return 1;               // 25% third
        } else if (posInPhrase == 1) {
            // Avoid immediate repetition
            if (r == 0) return 2;   // favor fifth over root
            return r % 3;
        } else if (posInPhrase == PHRASE_LEN - 1) {
            return (r & 1) == 0 ? 0 : 2; // root or fifth
        } else {
            return r % 3;
        }
    }

    // ===== Bass Voice =====
    function _chooseBasstone(
        uint32 position,
        uint32 rngState,
        int16 previousPitch,
        uint8[8] memory currentPitches
    ) private pure returns (uint8) {
        uint8 r = uint8(rngState & 15); // More bits for variety
        
        // Repeat previous bass tone 75% of the time
        if (previousPitch != -1) {
            for (uint8 i = 0; i < 8; i++) {
                if (int16(int256(uint256(currentPitches[i]))) == previousPitch) {
                    if (r < 12) { // 12/16 = 75% chance
                        return i;
                    }
                    break;
                }
            }
        }
        
        // Weighted preference: root=8, fifth=7, fourth=6, sixth=4, others=1-2
        uint8[8] memory weights = [8, 6, 7, 4, 2, 1, 2, 1];
        uint8 totalWeight = 31; // sum of weights
        
        uint8 randWeight = uint8((rngState >> 4) % totalWeight);
        uint8 cumulative = 0;
        
        for (uint8 i = 0; i < 8; i++) {
            cumulative += weights[i];
            if (randWeight < cumulative) {
                return i;
            }
        }
        
        return 0; // Fallback to root
    }

    // ===== Voice Generation =====
    function _leadGenerateStep(
        uint32 position,
        uint32 tokenSeed,
        LeadState memory st
    ) private pure returns (Event memory ev, LeadState memory out) {
        out = st;
        
        uint8 phraseType = _phraseType(position);
        uint8 posInPhrase = uint8(position % PHRASE_LEN);

        // Hard reset every 50 beats back to tonic
        if (position % 50 == 0) {
            out.chord = 0; // index 0 = Eb
            out.rng = _adv(out.rng, tokenSeed ^ 0x5050);
        }
        // Cadential nudge on phrase boundaries / quarter grid
        else if (position % PHRASE_LEN == 0 || (position % 4 == 0)) {
            out.rng = _adv(out.rng, tokenSeed ^ 0x1234);
            uint8[6] memory nbrs = _diatonicNeighbors(_getDiatonicChord(out.chord));
            out.chord = uint8(_getDiatonicIndex(nbrs[out.rng % 6]));
        }

        // Optional rest
        bool restNow = _leadShouldRest(phraseType, posInPhrase, out.notesSinceRest, out.rng);
        if (restNow) {
            uint16 restDur = _getRestDuration(phraseType, out.rng);
            ev = Event(-1, restDur);
            out.notesSinceRest = 0;
            return (ev, out);
        }

        // Advance harmony
        uint8 currentChordIdx = _getDiatonicChord(out.chord);
        (uint8 newChord, uint32 newRng) = _chooseHarmonicMovement(currentChordIdx, phraseType, out.rng, tokenSeed);
        out.rng = newRng;
        out.chord = _getDiatonicIndex(newChord);

        // Octave selection (slightly elevated vs. raw MIDI output)
        uint8 octave;
        if (phraseType == 0) octave = 5;      // A: low-middle
        else if (phraseType == 1) octave = 6; // A': high
        else if (phraseType == 2) octave = 5; // B: middle
        else octave = 6;                      // C: middle-high

        uint8[3] memory tones = _chordToPitches(_getDiatonicChord(out.chord), octave);

        // Tone selection; phrase B leans toward upper chord members
        uint8 idx;
        if (phraseType == 2) { // B: bias toward third and fifth
            uint32 s;
            unchecked {
                s = _adv(out.rng, tokenSeed * 2);
            }
            out.rng = s;
            uint8 r = uint8(s & 7);
            if (r < 2) idx = 0;     // 25% root
            else if (r < 5) idx = 1; // 37.5% third
            else idx = 2;           // 37.5% fifth
        } else {
            uint32 s;
            unchecked {
                s = _adv(out.rng, tokenSeed * 2);
            }
            out.rng = s;
            idx = _chooseChordToneImproved(posInPhrase, s);
        }

        uint16 dur = _getDurationLead(phraseType, out.rng);
        ev = Event(int16(uint16(tones[idx % 3])), dur);
        
        out.notesSinceRest += 1;
        return (ev, out);
    }

    function _bassGenerateStep(
        uint32 position,
        uint32 tokenSeed,
        BassState memory st
    ) private pure returns (Event memory ev, BassState memory out) {
        out = st;
        
        uint8 phraseType = _phraseType(position);

        // Hard reset every 50 beats
        if (position % 50 == 0) {
            out.chord = 0; // index 0 = Eb
            out.rng = _adv(out.rng, tokenSeed ^ 0x5050);
        }
        // Cadential nudge
        else if (position % PHRASE_LEN == 0 || (position % 4 == 0)) {
            out.rng = _adv(out.rng, tokenSeed ^ 0x1234);
            uint8[6] memory nbrs = _diatonicNeighbors(_getDiatonicChord(out.chord));
            out.chord = uint8(_getDiatonicIndex(nbrs[out.rng % 6]));
        }

        // Advance harmony
        uint8 currentChordIdx = _getDiatonicChord(out.chord);
        (uint8 newChord, uint32 newRng) = _chooseHarmonicMovement(currentChordIdx, phraseType, out.rng, tokenSeed);
        out.rng = newRng;
        out.chord = _getDiatonicIndex(newChord);

        // Bass octave choice (shifted for playback range)
        uint8 octave = (phraseType == 1) ? 5 : 4;
        uint8[8] memory pitches = _bassChordToPitches(_getDiatonicChord(out.chord), octave);

        // Bass tone selection with repetition bias
        uint32 s;
        unchecked {
            s = _adv(out.rng, tokenSeed * 2);
        }
        out.rng = s;
        uint8 toneIdx = _chooseBasstone(position, s, out.previousPitch, pitches);
        
        uint16 dur = _getDurationBass(position);
        int16 chosenPitch = int16(uint16(pitches[toneIdx]));
        ev = Event(chosenPitch, dur);
        
        out.previousPitch = chosenPitch;
        return (ev, out);
    }

    // ===== Helpers =====
    function _getDiatonicIndex(uint8 chordIdx) private pure returns (uint8) {
        for (uint8 i = 0; i < 7; i++) {
            if (_getDiatonicChord(i) == chordIdx) return i;
        }
        return 0; // Default to tonic
    }

    // ===== ABC Notation (Eb Major) =====
    function _pitchToAbcEb(int16 pitch) private pure returns (string memory) {
        if (pitch < 0) return "z";
        
        // Eb signature prefers flats
        string[12] memory noteNames = ["C","_D","D","_E","E","F","_G","G","_A","A","_B","B"];
        uint16 p = uint16(uint16(pitch));
        uint8 oct = uint8(p / 12);
        uint8 cls = uint8(p % 12);
        string memory note = noteNames[cls];

        if (oct <= 3) {
            for (uint8 i = oct; i < 4; i++) note = string(abi.encodePacked(note, ","));
        } else if (oct == 4) {
            // Already uppercase
        } else if (oct == 5) {
            // Lowercase
            bytes memory b = bytes(note);
            if (b.length == 1) { b[0] = bytes1(uint8(b[0]) + 32); }
            note = string(b);
        } else if (oct >= 6) {
            // Lowercase with apostrophes
            bytes memory b = bytes(note);
            if (b.length == 1) { b[0] = bytes1(uint8(b[0]) + 32); }
            note = string(b);
            for (uint8 i = 5; i < oct; i++) note = string(abi.encodePacked(note, "'"));
        }
        
        return note;
    }

    function _durToAbcEb(uint16 ticks) private pure returns (string memory) {
        if (ticks >= WHOLE)       return "8";
        if (ticks >= HALF_NOTE)   return "4";
        if (ticks >= DOTTED_QUART) return "3";
        if (ticks >= QUARTER)     return "2";
        if (ticks >= EIGHTH)      return "";
        return "/2";
    }

    // ===== Public API =====
    function generateBeat(uint32 beat, uint32 tokenSeed)
        external pure override returns (Event memory lead, Event memory bass)
    {
        // Initialize deterministic state machines
        LeadState memory L = LeadState({
            chord: 0,  // Index 0 = Eb major
            rng: 0xCAFEBABE,
            notesSinceRest: 0
        });
        BassState memory B = BassState({
            chord: 0,  // Index 0 = Eb major
            rng: 0xDEAFBEEF,  // Match Python seed
            previousPitch: -1
        });

        // Cycle every 365 beats (annual cadence)
        uint32 effectiveBeat = beat % 365;
        uint32 era = beat / 365;
        
        // Run sequence up to the requested beat
        for (uint32 i = 0; i < effectiveBeat; i++) {
            uint32 seed = _mix(tokenSeed, i);
            (, L) = _leadGenerateStep(i, seed, L);
            (, B) = _bassGenerateStep(i, seed ^ 0x7777, B);
        }

        // Emit the requested beat
        uint32 sNow = _mix(tokenSeed, effectiveBeat);
        (lead, L) = _leadGenerateStep(effectiveBeat, sNow, L);
        (bass, B) = _bassGenerateStep(effectiveBeat, sNow ^ 0x7777, B);
    }

    function generateAbcBeat(uint32 beat, uint32 tokenSeed)
        external pure override returns (string memory abc)
    {
        // Inline generation to avoid an external call
        LeadState memory L = LeadState({
            chord: 0, rng: 0xCAFEBABE, notesSinceRest: 0
        });
        BassState memory B = BassState({
            chord: 0, rng: 0xDEAFBEEF, previousPitch: -1
        });

        // Annual cycle (365 beats)
        uint32 effectiveBeat = beat % 365;
        uint32 era = beat / 365;
        
        // Run sequence up to beat-1
        for (uint32 i = 0; i < effectiveBeat; i++) {
            uint32 seed = _mix(tokenSeed, i);
            (, L) = _leadGenerateStep(i, seed, L);
            (, B) = _bassGenerateStep(i, seed ^ 0x7777, B);
        }

        // Emit current beat and format ABC
        uint32 sNow = _mix(tokenSeed, effectiveBeat);
        Event memory lead; Event memory bass;
        (lead, L) = _leadGenerateStep(effectiveBeat, sNow, L);
        (bass, B) = _bassGenerateStep(effectiveBeat, sNow ^ 0x7777, B);
        
        string memory la = string(abi.encodePacked(_pitchToAbcEb(lead.pitch), _durToAbcEb(lead.duration)));
        string memory ba = string(abi.encodePacked(_pitchToAbcEb(bass.pitch), _durToAbcEb(bass.duration)));

        abc = string(
            abi.encodePacked(
                "X:1\n",
                "T:Beat ", _u2s(beat + 1), " - Era ", _u2s(era + 1), " Day ", _u2s(effectiveBeat + 1), " (Eb major)\n",
                "M:4/4\nL:1/8\nQ:1/4=120\nK:Eb\n",  // Key signature: Eb major
                "V:1 clef=treble\nV:2 clef=bass\n",
                "%%score (1 2)\n",
                "V:1\n", la, " |\n",
                "V:2\n", ba, " |"
            )
        );
    }

    // Decimal encoding helper
    function _u2s(uint256 v) private pure returns (string memory) {
        if (v == 0) return "0";
        uint256 t=v; uint256 d; while (t!=0){ d++; t/=10; }
        bytes memory b=new bytes(d);
        while (v!=0){ d--; b[d]=bytes1(uint8(48+v%10)); v/=10; }
        return string(b);
    }
}
