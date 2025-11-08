// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MusicLib
 * @notice Solidity port of the Python "Dual System: V3 lead (with rests) + V2 bass (no rests)".
 *         Deterministic, history-driven simulation: given (beat, tokenSeed) it reproduces the
 *         same results by replaying from position 0..beat.
 *
 * Phrase grammar (len=7, period=7), phrase length=8:
 *   0:A, 1:A', 2:B, 3:A, 4:A', 5:C, 6:A
 *
 * RNG: LCG state = state*1664525 + 1013904223 + seed_modifier (mod 2^32),
 *      initial per-voice seeds: lead=0xCAFEBABE, bass=0xBEEFCAFE
 *
 * Lead (V3): rests enabled; Bass (V2): rests disabled.
 */
library MusicLib {
    // ---------------- Types ----------------
    struct Event {
        int16 pitch;      // MIDI pitch, -1 for rest
        uint16 duration;  // ticks (e.g., 480 = quarter)
    }

    // ---------------- Constants ----------------
    uint16 constant QUARTER       = 480;
    uint16 constant DOTTED_QUART  = 720;
    uint16 constant HALF_NOTE     = 960;
    uint16 constant WHOLE         = 1920;
    uint16 constant EIGHTH        = 240;
    uint16 constant SIXTEENTH     = 120;

    // phrase: 8 beats
    uint8 constant PHRASE_LEN = 8;

    // phrase grammar period = 7
    // map idx%7 -> 0:A,1:A',2:B,3:A,4:A',5:C,6:A
    function _phraseType(uint32 position) private pure returns (uint8) {
        uint8 m = uint8((position / PHRASE_LEN) % 7);
        if (m == 0) return 0;     // A
        if (m == 1) return 1;     // A'
        if (m == 2) return 2;     // B
        if (m == 3) return 0;     // A
        if (m == 4) return 1;     // A'
        if (m == 5) return 3;     // C
        // m == 6
        return 0;                 // A
    }

    // ---------------- RNG (LCG, 32-bit) ----------------
    function _adv(uint32 state, uint32 seedMod) private pure returns (uint32) {
        unchecked {
            return state * 1664525 + 1013904223 + seedMod;
        }
    }

    // simple deterministic mixing for per-position seed
    function _mix(uint32 a, uint32 b) private pure returns (uint32) {
        unchecked {
            // xorshift-like scramble around golden ratio constant
            uint32 s = a ^ (b * 0x9E3779B9);
            s ^= (s << 13);
            s ^= (s >> 17);
            s ^= (s << 5);
            return s;
        }
    }

    // ---------------- Tonnetz neighbors ----------------
    // chord index encoding: root(0..11)*2 + qual(0=maj,1=min)
    function _neighbors(uint8 chordIdx) private pure returns (uint8[6] memory out) {
        uint8 root = chordIdx >> 1;
        bool isMinor = (chordIdx & 1) == 1;

        if (!isMinor) {
            // Major chord neighbors (root,type):
            // parallel (root,1), relative ((root+9)%12,0), mediant ((root+4)%12,1),
            // subdominant ((root+5)%12,0), dominant ((root+7)%12,0), supertonic ((root+2)%12,1)
            out[0] = (root << 1) | 1;
            out[1] = (((root + 9) % 12) << 1) | 0;
            out[2] = (((root + 4) % 12) << 1) | 1;
            out[3] = (((root + 5) % 12) << 1) | 0;
            out[4] = (((root + 7) % 12) << 1) | 0;
            out[5] = (((root + 2) % 12) << 1) | 1;
        } else {
            // Minor chord neighbors:
            // parallel (root,0), relative ((root+3)%12,0), submediant ((root+8)%12,1),
            // subdominant ((root+5)%12,1), dominant ((root+7)%12,1), subtonic ((root+10)%12,0)
            out[0] = (root << 1) | 0;
            out[1] = (((root + 3) % 12) << 1) | 0;
            out[2] = (((root + 8) % 12) << 1) | 1;
            out[3] = (((root + 5) % 12) << 1) | 1;
            out[4] = (((root + 7) % 12) << 1) | 1;
            out[5] = (((root + 10) % 12) << 1) | 0;
        }
    }

    // ---------------- Harmony helpers ----------------
    function _chordToPitches(uint8 chordIdx, uint8 octave)
        private
        pure
        returns (uint8[3] memory tones)
    {
        uint8 root = chordIdx >> 1;
        bool isMinor = (chordIdx & 1) == 1;

        uint8 base = octave * 12;
        uint8 third = isMinor ? 3 : 4;
        uint8 fifth = 7;

        tones[0] = base + root;
        tones[1] = base + ((root + third) % 12);
        tones[2] = base + ((root + fifth) % 12);
        
        // Ensure values are within MIDI range (0-127)
        if (tones[0] > 127) tones[0] = 127;
        if (tones[1] > 127) tones[1] = 127;
        if (tones[2] > 127) tones[2] = 127;
    }

    // preferred areas by phrase type (encoded chordIdx entries)
    function _preferredAreas(uint8 phraseType) private pure returns (uint8[3] memory pref) {
        if (phraseType == 0) { // A: (0,0),(7,0),(5,0)
            pref[0] = (0 << 1) | 0;
            pref[1] = (7 << 1) | 0;
            pref[2] = (5 << 1) | 0;
        } else if (phraseType == 1) { // A': (0,0),(9,1),(4,0)
            pref[0] = (0 << 1) | 0;
            pref[1] = (9 << 1) | 1;
            pref[2] = (4 << 1) | 0;
        } else if (phraseType == 2) { // B: (2,1),(7,0),(11,1)
            pref[0] = (2 << 1) | 1;
            pref[1] = (7 << 1) | 0;
            pref[2] = (11 << 1) | 1;
        } else { // C: (5,0),(0,0),(7,0)
            pref[0] = (5 << 1) | 0;
            pref[1] = (0 << 1) | 0;
            pref[2] = (7 << 1) | 0;
        }
    }

    // motion style by phrase type: 0=stable, 1=ornate, 2=exploratory, 3=conclusive
    function _motionStyle(uint8 phraseType) private pure returns (uint8) {
        if (phraseType == 0) return 0; // A: stable
        if (phraseType == 1) return 1; // A': ornate
        if (phraseType == 2) return 2; // B: exploratory
        return 3;                      // C: conclusive
    }

    function _chooseHarmonicMovement(
        uint8 currentChord,
        uint8 phraseType,
        uint32 rngState,
        uint32 seed
    ) private pure returns (uint8 nextChord, uint32 newState) {
        uint8[6] memory nbrs = _neighbors(currentChord);
        uint8 style = _motionStyle(phraseType);
        uint8[3] memory pref = _preferredAreas(phraseType);

        newState = _adv(rngState, seed);

        if (style == 0) {
            // stable: usually stay; 1/8 chance to move (r&7==0)
            if ((newState & 7) == 0) {
                // prefer tonic-area neighbors if present
                // Find tonic neighbors
                // count matches
                uint8 matches;
                for (uint8 i = 0; i < 6; i++) {
                    uint8 n = nbrs[i];
                    if (n == pref[0] || n == pref[1] || n == pref[2]) {
                        matches++;
                    }
                }
                if (matches > 0) {
                    uint8 idx = uint8(newState % matches);
                    // select idx-th match
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
            return (nextChord, newState);
        } else if (style == 1) {
            // ornate: 1/4 chance to move, else stay
            if ((newState & 3) == 0) {
                nextChord = nbrs[uint8(newState % 6)];
            } else {
                nextChord = currentChord;
            }
            return (nextChord, newState);
        } else if (style == 2) {
            // exploratory: always move
            nextChord = nbrs[uint8(newState % 6)];
            return (nextChord, newState);
        } else {
            // conclusive: move, but prefer roots in {0,5,7}
            // gather candidates whose root in set
            uint8 c; uint8[6] memory pool;
            for (uint8 i = 0; i < 6; i++) {
                uint8 n = nbrs[i];
                uint8 r = n >> 1;
                if (r == 0 || r == 5 || r == 7) { pool[c++] = n; }
            }
            if (c > 0) {
                nextChord = pool[uint8(newState % c)];
            } else {
                nextChord = nbrs[uint8(newState % 6)];
            }
            return (nextChord, newState);
        }
    }

    // ---------------- Lead (V3) with rests ----------------
    struct LeadState {
        uint8 chord;          // chordIdx
        uint32 rng;           // 32-bit RNG state
        uint16 notesSinceRest;
    }

    function _leadGenerateStep(
        uint32 position,
        uint32 tokenSeed,
        LeadState memory st
    ) private pure returns (Event memory ev, LeadState memory out) {
        out = st;

        uint8 phraseType = _phraseType(position);
        uint8 posInPhrase = uint8(position % PHRASE_LEN);

        // rest decision
        bool restNow = _leadShouldRest(phraseType, posInPhrase, out.notesSinceRest, out.rng, tokenSeed);
        if (restNow) {
            uint16 dur = _leadRestDuration(phraseType, out.rng, tokenSeed);
            ev = Event(-1, dur);
            out.notesSinceRest = 0;
            return (ev, out);
        }

        // cadence trigger (phrase boundary or every 4 beats)
        if (position % PHRASE_LEN == 0 || (position % 4 == 0)) {
            uint32 s = _adv(out.rng, tokenSeed ^ 0x1234);
            out.rng = s;
            uint8[6] memory nbrs = _neighbors(out.chord);
            out.chord = nbrs[uint8(s % 6)];
        }

        // choose harmonic movement based on phrase style
        {
            uint8 newChord;
            uint32 ns;
            (newChord, ns) = _chooseHarmonicMovement(out.chord, phraseType, out.rng, tokenSeed);
            out.rng = ns;
            if (newChord != out.chord) out.chord = newChord;
        }

        // pick chord tone (higher octave for A')
        uint8 octave = (phraseType == 1) ? 5 : 4;
        uint8[3] memory tones = _chordToPitches(out.chord, octave);

        // tone choice
        {
            uint32 s = _adv(out.rng, uint32(uint64(tokenSeed) * 2));
            out.rng = s;
            uint8 idx;
            if (posInPhrase == 0) {
                idx = 0; // root
            } else if (posInPhrase == PHRASE_LEN - 1) {
                idx = (uint8(s) & 1) == 0 ? 0 : 2; // root or fifth
            } else {
                idx = uint8(s % 3);
            }

            uint16 dur = _durationForPhraseLead(phraseType, out.rng, tokenSeed);
            ev = Event(int16(int256(uint256(tones[idx]))), dur);
        }

        out.notesSinceRest += 1;
        return (ev, out);
    }

    function _leadShouldRest(
        uint8 phraseType,
        uint8 posInPhrase,
        uint16 notesSinceRest,
        uint32 rngState,
        uint32 tokenSeed
    ) private pure returns (bool) {
        uint16 minLen = 4;
        uint16 maxLen = 8;

        if (notesSinceRest >= maxLen) return true;
        if (notesSinceRest < minLen)  return false;

        // seed tweak
        uint32 s = _adv(rngState, tokenSeed ^ 0x7777);

        uint8 restChance;
        if (posInPhrase == 3) restChance = 6;
        else if (posInPhrase == 7) restChance = 3;
        else {
            if (phraseType == 0) restChance = 12;       // A
            else if (phraseType == 1) restChance = 16;  // A'
            else if (phraseType == 2) restChance = 10;  // B
            else restChance = 8;                        // C
        }

        // Python used: (rest_seed & (rest_chance - 1)) == 0 (biased, intentional)
        // We mirror that behavior exactly.
        return (s & (uint32(restChance) - 1)) == 0;
    }

    function _leadRestDuration(
        uint8 phraseType,
        uint32 rngState,
        uint32 tokenSeed
    ) private pure returns (uint16) {
        uint32 s = _adv(rngState, tokenSeed ^ 0x3333);
        if (phraseType == 2 || phraseType == 3) {
            // B or C: [quarter, dotted-quarter, half]
            uint8 pick = uint8(s % 3);
            if (pick == 0) return QUARTER;
            if (pick == 1) return DOTTED_QUART;
            return HALF_NOTE;
        } else {
            // A / A': [quarter, dotted-quarter]
            return (uint8(s) & 1) == 0 ? QUARTER : DOTTED_QUART;
        }
    }

    function _durationForPhraseLead(
        uint8 phraseType,
        uint32 rngState,
        uint32 tokenSeed
    ) private pure returns (uint16) {
        uint32 s = _adv(rngState, uint32(uint64(tokenSeed) * 3));
        if (phraseType == 0) { // A
            return QUARTER;
        } else if (phraseType == 1) { // A'
            uint8 r = uint8(s % 3);
            if (r == 0) return EIGHTH;
            if (r == 1) return QUARTER;
            return DOTTED_QUART;
        } else if (phraseType == 2) { // B
            uint8 r = uint8(s % 4);
            if (r == 0) return SIXTEENTH;
            if (r == 1) return EIGHTH;
            if (r == 2) return QUARTER;
            return HALF_NOTE;
        } else { // C
            uint8 r = uint8(s % 3);
            if (r == 0) return QUARTER;
            if (r == 1) return DOTTED_QUART;
            return HALF_NOTE;
        }
    }

    // ---------------- Bass (V2) no rests ----------------
    struct BassState {
        uint8 chord;
        uint32 rng;
    }

    function _bassGenerateStep(
        uint32 position,
        uint32 tokenSeed,
        BassState memory st
    ) private pure returns (Event memory ev, BassState memory out) {
        out = st;

        uint8 phraseType = _phraseType(position);
        uint8 posInPhrase = uint8(position % PHRASE_LEN);

        // cadence movement
        if (position % PHRASE_LEN == 0 || (position % 4 == 0)) {
            uint32 s = _adv(out.rng, tokenSeed ^ 0x1234);
            out.rng = s;
            uint8[6] memory nbrs = _neighbors(out.chord);
            out.chord = nbrs[uint8(s % 6)];
        }

        // choose harmonic movement (same logic as lead, but no rests)
        {
            uint8 newChord;
            uint32 ns;
            (newChord, ns) = _chooseHarmonicMovement(out.chord, phraseType, out.rng, tokenSeed);
            out.rng = ns;
            if (newChord != out.chord) out.chord = newChord;
        }

        // lower octave than lead
        uint8 octave = (phraseType == 1) ? 3 : 2;
        uint8[3] memory tones = _chordToPitches(out.chord, octave);

        // tone choice
        {
            uint32 s = _adv(out.rng, uint32(uint64(tokenSeed) * 2));
            out.rng = s;
            uint8 idx;
            if (posInPhrase == 0) {
                idx = 0;
            } else if (posInPhrase == PHRASE_LEN - 1) {
                idx = (uint8(s) & 1) == 0 ? 0 : 2;
            } else {
                idx = uint8(s % 3);
            }

            // durations (same sets as V2/lead)
            uint16 dur = _durationForPhraseLead(phraseType, out.rng, tokenSeed);
            ev = Event(int16(int256(uint256(tones[idx]))), dur);
        }
        return (ev, out);
    }

    // ---------------- Public API ----------------

    /**
     * @dev Generate a dual-voice (lead,bass) event at absolute beat "beat" for a tokenSeed.
     *      Replays from position 0..beat to reproduce Python's stateful behavior.
     */
    function generateBeat(uint32 beat, uint32 tokenSeed)
        external
        pure
        returns (Event memory lead, Event memory bass)
    {
        // initial states
        LeadState memory L = LeadState({
            chord: (0 << 1) | 0,       // C major
            rng: 0xCAFEBABE,
            notesSinceRest: 0
        });
        BassState memory B = BassState({
            chord: (0 << 1) | 0,       // C major
            rng: 0xBEEFCAFE
        });

        // simulate history up to beat-1
        for (uint32 i = 0; i < beat; i++) {
            uint32 seed = _mix(tokenSeed, i);
            (, L) = _leadGenerateStep(i, seed, L);
            (, B) = _bassGenerateStep(i, seed ^ 0x7777, B);
        }

        // current beat
        uint32 sNow = _mix(tokenSeed, beat);
        (lead, L) = _leadGenerateStep(beat, sNow, L);
        (bass, B) = _bassGenerateStep(beat, sNow ^ 0x7777, B);
    }

    // ------- ABC helpers (same as before) -------
    function _u2s(uint256 v) private pure returns (string memory) {
        if (v == 0) return "0";
        uint256 t=v; uint256 d; while (t!=0){ d++; t/=10; }
        bytes memory b=new bytes(d);
        while (v!=0){ d--; b[d]=bytes1(uint8(48+v%10)); v/=10; }
        return string(b);
    }

    function _pitchToAbc(int16 pitch) private pure returns (string memory) {
        if (pitch < 0) return "z";
        string[12] memory N = ["C","^C","D","^D","E","F","^F","G","^G","A","^A","B"];
        uint16 p = uint16(uint16(pitch));
        uint8 oct = uint8(p / 12);
        uint8 cls = uint8(p % 12);
        string memory note = N[cls];

        if (oct <= 3) {
            for (uint8 i = oct; i < 4; i++) note = string(abi.encodePacked(note, ","));
        } else if (oct >= 5) {
            bytes memory b = bytes(note);
            if (b.length == 1) { b[0] = bytes1(uint8(b[0]) + 32); } // lowercase
            note = string(b);
            for (uint8 i = 5; i < oct; i++) note = string(abi.encodePacked(note, "'"));
        }
        return note;
    }

    function _durToAbc(uint16 ticks) private pure returns (string memory) {
        if (ticks >= WHOLE)     return "8";
        if (ticks >= HALF_NOTE) return "4";
        if (ticks >= QUARTER)   return "2";
        if (ticks >= EIGHTH)    return "";
        return "/2";
    }

    function generateAbcBeat(uint32 beat, uint32 tokenSeed)
        external
        pure
        returns (string memory abc)
    {
        // Inline the generateBeat logic to avoid external call
        // initial states
        LeadState memory L = LeadState({
            chord: (0 << 1) | 0,       // C major
            rng: 0xCAFEBABE,
            notesSinceRest: 0
        });
        BassState memory B = BassState({
            chord: (0 << 1) | 0,       // C major
            rng: 0xBEEFCAFE
        });

        // simulate history up to beat-1
        for (uint32 i = 0; i < beat; i++) {
            uint32 seed = _mix(tokenSeed, i);
            (, L) = _leadGenerateStep(i, seed, L);
            (, B) = _bassGenerateStep(i, seed ^ 0x7777, B);
        }

        // current beat
        uint32 sNow = _mix(tokenSeed, beat);
        Event memory lead;
        Event memory bass;
        (lead, L) = _leadGenerateStep(beat, sNow, L);
        (bass, B) = _bassGenerateStep(beat, sNow ^ 0x7777, B);
        
        string memory la = string(abi.encodePacked(_pitchToAbc(lead.pitch), _durToAbc(lead.duration)));
        string memory ba = string(abi.encodePacked(_pitchToAbc(bass.pitch), _durToAbc(bass.duration)));

        abc = string(
            abi.encodePacked(
                "X:1\n",
                "T:Beat ", _u2s(beat + 1), "\n",
                "M:4/4\nL:1/8\nQ:1/4=120\nK:C\n",
                "V:1 clef=treble\nV:2 clef=bass\n",
                "%%score (1 2)\n",
                "V:1\n", la, " |\n",
                "V:2\n", ba, " |"
            )
        );
    }
}
