#!/usr/bin/env python3
"""
Combine ABC Experiment Files into Playable MIDI
Takes individual ABC notes and creates a complete musical sequence
"""

import os
import re
import json
import subprocess
from pathlib import Path
import glob

class ABCToMidiCombiner:
    def __init__(self):
        self.midi_output_dir = "midi-output"
        os.makedirs(self.midi_output_dir, exist_ok=True)
        
    def parse_abc_file(self, filepath: str) -> dict:
        """Parse an ABC file to extract musical information"""
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Extract metadata from filename and content
        filename = os.path.basename(filepath)
        
        # Parse filename patterns - handle collection salts with spaces/special chars
        if "collection_" in filename and "_token_" in filename:
            # Find the token_XXX_beat_XXX_revealed_XXX pattern at the end
            match = re.search(r'_token_(\d+)_beat_(\d+)_revealed_(\d+)\.abc$', filename)
            if match:
                token_id = int(match.group(1))
                beat = int(match.group(2))
                revealed = int(match.group(3))
                
                # Extract collection salt (everything between "collection_" and "_token_")
                start_idx = filename.find('collection_') + len('collection_')
                end_idx = filename.find('_token_')
                collection_salt = filename[start_idx:end_idx]
            else:
                collection_salt = "unknown"
                token_id = 0
                beat = 0
                revealed = 0
        else:
            # Other filename patterns
            collection_salt = "unknown"
            token_id = 0
            beat = 0
            revealed = 0
            
        # Extract musical content (V:1 and V:2 lines)
        lead_line = ""
        bass_line = ""
        
        lines = content.split('\n')
        current_voice = None
        
        for line in lines:
            line = line.strip()
            if line.startswith('V:1'):
                current_voice = 'lead'
            elif line.startswith('V:2'):
                current_voice = 'bass'
            elif current_voice == 'lead' and '|' in line:
                lead_line = line.replace('|', '').strip()
            elif current_voice == 'bass' and '|' in line:
                bass_line = line.replace('|', '').strip()
                
        return {
            'filename': filename,
            'collection_salt': collection_salt,
            'token_id': token_id,
            'beat': beat,
            'revealed': revealed,
            'lead_line': lead_line,
            'bass_line': bass_line
        }
    
    def combine_by_collection_salt(self, experiment_dir: str) -> list:
        """Combine ABC files by collection salt"""
        abc_files = glob.glob(os.path.join(experiment_dir, "*.abc"))
        
        if not abc_files:
            print(f"No ABC files found in {experiment_dir}")
            return []
        
        # Parse all files
        parsed_files = []
        for filepath in abc_files:
            parsed = self.parse_abc_file(filepath)
            parsed_files.append(parsed)
        
        # Group by collection salt
        by_salt = {}
        for parsed in parsed_files:
            salt = parsed['collection_salt']
            if salt not in by_salt:
                by_salt[salt] = []
            by_salt[salt].append(parsed)
        
        # Sort each group by beat order
        for salt in by_salt:
            by_salt[salt].sort(key=lambda x: (x['beat'], x['token_id'], x['revealed']))
        
        return by_salt
    
    def create_combined_abc(self, salt_name: str, files_data: list, experiment_name: str) -> str:
        """Create a combined ABC file from multiple individual files"""
        
        # Clean salt name for filename
        clean_salt = re.sub(r'[^\w\s-]', '', salt_name).replace(' ', '_')
        output_filename = f"{experiment_name}_{clean_salt}_combined.abc"
        output_path = os.path.join(self.midi_output_dir, output_filename)
        
        # Create combined ABC content
        abc_content = f"""X:1
T:{experiment_name} - {salt_name}
C:Combined sequence from {len(files_data)} individual beats
M:4/4
L:1/8
Q:1/4=120
K:Eb
V:1 clef=treble name="Lead"
V:2 clef=bass name="Bass"
%%score (1 2)
V:1
"""
        
        # Add all lead notes in sequence
        lead_notes = []
        bass_notes = []
        
        for i, file_data in enumerate(files_data):
            lead_note = file_data['lead_line'] if file_data['lead_line'] else "z2"
            bass_note = file_data['bass_line'] if file_data['bass_line'] else "z2"
            
            # Add bar lines every 4 beats for readability
            if i > 0 and i % 4 == 0:
                lead_notes.append("|")
                bass_notes.append("|")
            
            lead_notes.append(lead_note)
            bass_notes.append(bass_note)
        
        # Finish with final bar
        lead_notes.append("|")
        bass_notes.append("|")
        
        abc_content += " ".join(lead_notes) + "\nV:2\n"
        abc_content += " ".join(bass_notes)
        
        # Write combined ABC file
        with open(output_path, 'w') as f:
            f.write(abc_content)
        
        print(f"   📝 Created: {output_filename}")
        return output_path
    
    def convert_to_midi(self, abc_path: str) -> bool:
        """Convert ABC to MIDI using abc2midi"""
        try:
            result = subprocess.run(['abc2midi', abc_path], 
                                  cwd=self.midi_output_dir, 
                                  capture_output=True, 
                                  text=True)
            if result.returncode == 0:
                midi_name = os.path.basename(abc_path).replace('.abc', '.mid')
                print(f"   🎼 Created: {midi_name}")
                return True
            else:
                print(f"   ❌ abc2midi error: {result.stderr}")
                return False
        except FileNotFoundError:
            print(f"   ⚠️  abc2midi not found - ABC file ready for manual conversion")
            return False
    
    def combine_experiment(self, experiment_dir: str) -> str:
        """Combine all ABC files from an experiment into MIDI files"""
        experiment_name = os.path.basename(experiment_dir)
        print(f"\n🎵 COMBINING EXPERIMENT: {experiment_name}")
        print(f"📁 Input: {experiment_dir}")
        print(f"📁 Output: {self.midi_output_dir}")
        print("-" * 60)
        
        # Group files by collection salt
        by_salt = self.combine_by_collection_salt(experiment_dir)
        
        if not by_salt:
            return ""
        
        created_files = []
        
        for salt_name, files_data in by_salt.items():
            print(f"\n🧂 Collection Salt: '{salt_name}'")
            print(f"   📊 Combining {len(files_data)} beats...")
            
            # Create combined ABC
            abc_path = self.create_combined_abc(salt_name, files_data, experiment_name)
            created_files.append(abc_path)
            
            # Convert to MIDI
            self.convert_to_midi(abc_path)
        
        print(f"\n✅ COMPLETE: Generated {len(created_files)} combined files")
        return self.midi_output_dir

def main():
    print("🎼 ABC TO MIDI COMBINER")
    print("=" * 60)
    print("Combine individual ABC experiment files into playable MIDI sequences")
    print("=" * 60)
    
    combiner = ABCToMidiCombiner()
    
    # Find all experiment directories
    outputs_dir = "outputs"
    if not os.path.exists(outputs_dir):
        print(f"❌ No outputs directory found!")
        return
    
    experiment_dirs = [d for d in os.listdir(outputs_dir) 
                      if os.path.isdir(os.path.join(outputs_dir, d))]
    
    if not experiment_dirs:
        print(f"❌ No experiment directories found in {outputs_dir}")
        return
    
    print(f"📁 Found {len(experiment_dirs)} experiment directories:")
    for i, dirname in enumerate(experiment_dirs, 1):
        print(f"   {i}. {dirname}")
    
    # Process the most recent experiment (or you can modify to choose)
    most_recent = max(experiment_dirs, 
                     key=lambda d: os.path.getctime(os.path.join(outputs_dir, d)))
    
    print(f"\n🎯 Processing most recent: {most_recent}")
    
    experiment_path = os.path.join(outputs_dir, most_recent)
    output_dir = combiner.combine_experiment(experiment_path)
    
    print(f"\n🎵 READY TO LISTEN:")
    print(f"   📁 Check {output_dir}/ for combined MIDI files")
    print(f"   🎧 Open the .mid files in your audio player")
    print(f"   🎼 Each collection salt creates a different musical sequence!")

if __name__ == "__main__":
    main()
