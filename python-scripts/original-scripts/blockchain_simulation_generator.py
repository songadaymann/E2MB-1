#!/usr/bin/env python3
"""
Blockchain Simulation Generator
Simulates realistic on-chain behavior with individual beat generation
Uses reveal index method for progressive complexity over time
"""

import os
import json
import csv
import hashlib
import random
from datetime import datetime
from dataclasses import dataclass
from typing import List, Tuple, Dict
from full_musiclib_v3 import CompleteMusicLibV3, Event

@dataclass 
class TokenData:
    token_id: int
    reveal_index: int  # Position in reveal timeline (0, 1, 2...)
    reveal_year: int
    seven_words: List[str]
    previous_notes_hash: str
    global_state_hash: str
    final_seed: str
    abc_content: str
    lead_event: Event
    bass_event: Event

class BlockchainSimulator:
    def __init__(self, collection_phrase: str, start_year: int = 2026):
        self.collection_phrase = collection_phrase
        self.start_year = start_year
        self.music_generator = CompleteMusicLibV3()
        
        # Collection salt from phrase
        self.collection_salt = hashlib.sha256(collection_phrase.encode('utf-8')).hexdigest()
        print(f"🎵 Collection Phrase: '{collection_phrase}'")
        print(f"🔑 Collection Salt: {self.collection_salt[:16]}...")
        
    def generate_seven_words(self, token_id: int) -> List[str]:
        """Generate 7 meaningful words for each token using collection phrase as seed"""
        # Use collection phrase + token_id as seed for consistency
        seed_str = f"{self.collection_phrase}_{token_id}"
        seed_hash = hashlib.sha256(seed_str.encode()).hexdigest()
        
        # Create deterministic but meaningful word list
        word_bank = [
            "harmony", "melody", "rhythm", "crescendo", "allegro", "andante", "forte", "piano",
            "symphony", "sonata", "chord", "scale", "tempo", "timbre", "resonance", "cadence",
            "vibrato", "staccato", "legato", "diminuendo", "accelerando", "ritardando", "sforzando",
            "passage", "phrase", "movement", "composition", "arrangement", "improvisation", "modulation",
            "transpose", "chromatic", "diatonic", "enharmonic", "counterpoint", "polyphony", "monophony",
            "octave", "interval", "consonance", "dissonance", "resolution", "suspension", "ornament"
        ]
        
        # Use hash to deterministically select 7 words
        selected_words = []
        for i in range(7):
            word_index = int(seed_hash[i*2:i*2+2], 16) % len(word_bank)
            selected_words.append(word_bank[word_index])
        
        return selected_words
    
    def simulate_blockchain_hash(self, *components) -> str:
        """Simulate a blockchain hash from multiple components"""
        combined = "_".join(str(c) for c in components)
        return hashlib.sha256(combined.encode()).hexdigest()
    
    def generate_previous_notes_hash(self, reveal_index: int, all_tokens: List[TokenData]) -> str:
        """Generate hash of previous notes for this reveal index"""
        if reveal_index == 0:
            return "0000000000000000000000000000000000000000000000000000000000000000"
        
        # Hash of all previously revealed notes
        previous_notes = []
        for token in all_tokens[:reveal_index]:  # Only previously revealed
            if token.lead_event.pitch != -1:
                previous_notes.append(str(token.lead_event.pitch))
            previous_notes.append(str(token.bass_event.pitch))
        
        if not previous_notes:
            return "0000000000000000000000000000000000000000000000000000000000000000"
            
        combined = "_".join(previous_notes)
        return hashlib.sha256(combined.encode()).hexdigest()
    
    def generate_global_state_hash(self, reveal_index: int, year: int) -> str:
        """Generate global blockchain state hash"""
        # Simulate blockchain state including year, reveal count, etc.
        state_components = [
            f"year:{year}",
            f"revealed_count:{reveal_index + 1}",
            f"collection:{self.collection_phrase}",
            f"chain_state:ethereum_block_{999000 + reveal_index}"
        ]
        combined = "_".join(state_components)
        return hashlib.sha256(combined.encode()).hexdigest()
    
    def generate_final_seed(self, token_data: TokenData) -> str:
        """Generate final seed as specified: hash(collection_salt + token_id + seven_words + previous_notes + global_state)"""
        components = [
            self.collection_salt,
            str(token_data.token_id),
            "_".join(token_data.seven_words),
            token_data.previous_notes_hash,
            token_data.global_state_hash
        ]
        
        combined = "_".join(components)
        return hashlib.sha256(combined.encode()).hexdigest()
    
    def generate_single_token(self, token_id: int, reveal_index: int, all_tokens: List[TokenData]) -> TokenData:
        """Generate a single token simulating on-chain behavior"""
        reveal_year = self.start_year + reveal_index
        seven_words = self.generate_seven_words(token_id)
        
        # Create initial token data structure
        token_data = TokenData(
            token_id=token_id,
            reveal_index=reveal_index,
            reveal_year=reveal_year,
            seven_words=seven_words,
            previous_notes_hash="",
            global_state_hash="",
            final_seed="",
            abc_content="",
            lead_event=Event(0, 0),
            bass_event=Event(0, 0)
        )
        
        # Generate blockchain-like hashes
        token_data.previous_notes_hash = self.generate_previous_notes_hash(reveal_index, all_tokens)
        token_data.global_state_hash = self.generate_global_state_hash(reveal_index, reveal_year)
        token_data.final_seed = self.generate_final_seed(token_data)
        
        # Convert seed to integer for music generation
        seed_int = int(token_data.final_seed[:8], 16)
        
        # CRITICAL: Use reveal_index as beat parameter, not 0!
        # This gives us the progressive complexity over centuries
        lead_event, bass_event = self.music_generator.generate_beat(reveal_index, seed_int)
        
        token_data.lead_event = lead_event
        token_data.bass_event = bass_event
        
        # Generate ABC content
        lead_abc = self.music_generator.pitch_to_abc(lead_event.pitch) + self.music_generator.duration_to_abc(lead_event.duration)
        bass_abc = self.music_generator.pitch_to_abc(bass_event.pitch) + self.music_generator.duration_to_abc(bass_event.duration)
        
        token_data.abc_content = f"""X:1
T:Millennium Song - Token {token_id}
C:Blockchain Composition
M:4/4
L:1/8
K:Eb
V:1 clef=treble name="Lead"
V:2 clef=bass name="Bass"
[V:1] {lead_abc} |
[V:2] {bass_abc} |
"""
        
        return token_data

    def generate_token_collection(self, num_tokens: int) -> List[TokenData]:
        """Generate a collection of tokens in reveal order"""
        print(f"\n🎼 Generating {num_tokens} tokens with blockchain simulation...")
        print(f"📅 Reveal timeline: {self.start_year} - {self.start_year + num_tokens - 1}")
        
        tokens = []
        
        for reveal_index in range(num_tokens):
            # Simulate different token IDs (not sequential reveal)
            # In real blockchain, token IDs would be from auction winners
            token_id = 1000 + reveal_index * 7  # Simulate non-sequential IDs
            
            token = self.generate_single_token(token_id, reveal_index, tokens)
            tokens.append(token)
            
            if reveal_index % 50 == 0 or reveal_index < 10:
                print(f"   Token {token_id} (reveal #{reveal_index}): {token.reveal_year} - Beat complexity level {reveal_index}")
            elif reveal_index % 10 == 0:
                print(f"   ...Token {token_id} (reveal #{reveal_index}): {token.reveal_year}")
        
        return tokens
    
    def save_individual_files(self, tokens: List[TokenData], output_dir: str):
        """Save individual ABC files and create summary data"""
        os.makedirs(output_dir, exist_ok=True)
        os.makedirs(os.path.join(output_dir, "individual_abc"), exist_ok=True)
        
        # Save individual ABC files
        for token in tokens:
            abc_filename = f"token_{token.token_id}_beat_{token.reveal_index}.abc"
            abc_path = os.path.join(output_dir, "individual_abc", abc_filename)
            
            with open(abc_path, 'w') as f:
                f.write(token.abc_content)
        
        # Create CSV summary
        csv_path = os.path.join(output_dir, "token_metadata.csv")
        with open(csv_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow([
                'token_id', 'reveal_index', 'reveal_year', 'seven_words', 
                'lead_pitch', 'lead_duration', 'bass_pitch', 'bass_duration',
                'final_seed_preview', 'abc_file'
            ])
            
            for token in tokens:
                writer.writerow([
                    token.token_id,
                    token.reveal_index, 
                    token.reveal_year,
                    ' | '.join(token.seven_words),
                    token.lead_event.pitch,
                    token.lead_event.duration,
                    token.bass_event.pitch,
                    token.bass_event.duration,
                    token.final_seed[:16] + "...",
                    f"token_{token.token_id}_beat_{token.reveal_index}.abc"
                ])
        
        # Create detailed JSON metadata
        json_path = os.path.join(output_dir, "full_metadata.json")
        json_data = []
        for token in tokens:
            json_data.append({
                'token_id': token.token_id,
                'reveal_index': token.reveal_index,
                'reveal_year': token.reveal_year,
                'seven_words': token.seven_words,
                'lead_event': {
                    'pitch': token.lead_event.pitch,
                    'duration': token.lead_event.duration
                },
                'bass_event': {
                    'pitch': token.bass_event.pitch,
                    'duration': token.bass_event.duration
                },
                'blockchain_data': {
                    'collection_salt': self.collection_salt,
                    'previous_notes_hash': token.previous_notes_hash,
                    'global_state_hash': token.global_state_hash,
                    'final_seed': token.final_seed
                }
            })
        
        with open(json_path, 'w') as f:
            json.dump(json_data, f, indent=2)
        
        print(f"✅ Saved {len(tokens)} individual ABC files to {output_dir}/individual_abc/")
        print(f"✅ Created CSV metadata: {csv_path}")
        print(f"✅ Created JSON metadata: {json_path}")
    
    def create_combined_abc(self, tokens: List[TokenData], output_dir: str):
        """Create combined ABC file for MIDI conversion"""
        combined_abc = f"""X:1
T:Millennium Song - Blockchain Simulation
C:Collection: "{self.collection_phrase}"
M:4/4
L:1/8
K:Eb
V:1 clef=treble name="Lead"
V:2 clef=bass name="Bass"
"""
        
        # Add each token as a measure
        for i, token in enumerate(tokens):
            lead_abc = self.music_generator.pitch_to_abc(token.lead_event.pitch) + self.music_generator.duration_to_abc(token.lead_event.duration)
            bass_abc = self.music_generator.pitch_to_abc(token.bass_event.pitch) + self.music_generator.duration_to_abc(token.bass_event.duration)
            
            combined_abc += f"% Token {token.token_id} - Year {token.reveal_year} - Beat {token.reveal_index}\n"
            combined_abc += f"[V:1] {lead_abc} |\n"
            combined_abc += f"[V:2] {bass_abc} |\n"
        
        combined_path = os.path.join(output_dir, "combined_sequence.abc")
        with open(combined_path, 'w') as f:
            f.write(combined_abc)
        
        print(f"✅ Created combined ABC: {combined_path}")
        return combined_path

def main():
    print("🌟 BLOCKCHAIN SIMULATION GENERATOR")
    print("=" * 60)
    print("🎯 Simulates realistic on-chain NFT behavior")
    print("🔄 Individual beat generation with progressive complexity")
    print("🎵 Uses reveal index method for millennium-scale arc")
    print("=" * 60)
    
    # Configuration
    collection_phrase = "half the battle's just gettin outta bed"
    num_tokens = 500  # Generate 500 tokens with corrected Eb major notation
    
    # Create simulator
    simulator = BlockchainSimulator(collection_phrase)
    
    # Generate token collection
    tokens = simulator.generate_token_collection(num_tokens)
    
    # Create output directory
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = f"outputs/blockchain_simulation_{timestamp}"
    
    # Save all files
    simulator.save_individual_files(tokens, output_dir)
    combined_abc_path = simulator.create_combined_abc(tokens, output_dir)
    
    # Analysis
    print(f"\n📊 BLOCKCHAIN SIMULATION ANALYSIS")
    print(f"Collection phrase: '{collection_phrase}'")
    print(f"Tokens generated: {len(tokens)}")
    print(f"Year range: {tokens[0].reveal_year} - {tokens[-1].reveal_year}")
    
    # Show progression of complexity
    print(f"\n🎼 MILLENNIUM-SCALE MUSICAL ARC:")
    early_tokens = tokens[:10]
    mid_tokens = tokens[len(tokens)//2-2:len(tokens)//2+3]
    later_tokens = tokens[-10:]
    
    print(f"Early reveals (2026-2035):")
    for token in early_tokens:
        if token.reveal_index < 8:
            beat_type = "simple (foundational)"
        elif token.reveal_index < 16:
            beat_type = "developing (rests possible)"
        else:
            beat_type = "sophisticated"
        print(f"   Year {token.reveal_year}: Beat {token.reveal_index} ({beat_type})")
    
    print(f"\nMiddle reveals (~{mid_tokens[0].reveal_year}s):")
    for token in mid_tokens:
        beat_type = "fully sophisticated"
        print(f"   Year {token.reveal_year}: Beat {token.reveal_index} ({beat_type})")
    
    print(f"\nLater reveals ({tokens[-10].reveal_year}s):")
    for token in later_tokens:
        beat_type = "peak complexity"
        print(f"   Year {token.reveal_year}: Beat {token.reveal_index} ({beat_type})")
    
    print(f"\n🎯 Ready for ABC → SVG testing and MIDI audition!")
    print(f"📁 Output directory: {output_dir}")
    
    # Try to create MIDI if combine script exists
    try:
        import subprocess
        midi_output = os.path.join(output_dir, "combined_sequence.mid")
        result = subprocess.run([
            "python3", "combine_to_midi.py", combined_abc_path, midi_output
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f"🎵 Created MIDI file: {midi_output}")
        else:
            print(f"⚠️  MIDI conversion failed: {result.stderr}")
    except Exception as e:
        print(f"⚠️  Could not create MIDI automatically: {e}")

if __name__ == "__main__":
    main()
