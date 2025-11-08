#!/usr/bin/env python3
"""
ABC to SVG renderer for THE LONG SONG
Reads ABC notation and generates staff notation SVGs.
"""

import re
from typing import List, Tuple, Dict, Optional, Union

# Staff geometry (matches our canonical SVG layout)
CANVAS_SIZE = 600
STAFF_SPACE = 40
TREBLE_TOP = 80
BASS_TOP = 320  # Moved up to make room for low ledger lines
CENTER_X = 300
NOTE_X = 350  # Position notes between clef (~250) and staff end (500)

# Note positioning: step 0 = top line, step increases downward by half-spaces
# Lines are at steps 0,2,4,6,8. Spaces at 1,3,5,7.
def y_for_step(staff: str, step: int) -> float:
    """Convert staff step to Y coordinate."""
    base = TREBLE_TOP if staff == 'treble' else BASS_TOP
    return base + (step * STAFF_SPACE) / 2

def apply_octave_transposition(y: float, step: int, staff: str) -> Tuple[float, Optional[str], int]:
    """Apply 8va/8vb transposition to keep notes on canvas."""
    # Canvas bounds with some margin
    if staff == 'treble':
        if y < 40:  # Too high - use 8va (octave higher written, sounds as played)
            new_y = y + (7 * STAFF_SPACE / 2)  # Move down 1 octave
            new_step = step + 7
            return new_y, "8va", new_step
        elif y > 400:  # Too low for treble - use 8vb (more permissive)
            new_y = y - (7 * STAFF_SPACE / 2)  # Move up 1 octave
            new_step = step - 7
            return new_y, "8vb", new_step
    else:  # bass
        # Standard ABC bass clef is non-transposing - use ledger lines for low notes
        # Only use 8va/8vb for extremely out-of-range notes
        if y < 200:  # Very high for bass - use 8va
            new_y = y + (7 * STAFF_SPACE / 2)  # Move down 1 octave  
            new_step = step + 7
            return new_y, "8va", new_step
        elif y > 700:  # Extremely low - use 8vb only if way off canvas
            new_y = y - (7 * STAFF_SPACE / 2)  # Move up 1 octave
            new_step = step - 7
            return new_y, "8vb", new_step
    
    return y, None, step

def get_stem_direction(step: int, staff: str) -> str:
    """Determine stem direction based on note position on staff."""
    # Traditional rule: notes on/above middle line get stems down, below get stems up
    # Middle line is step 4 for both treble and bass (5-line staff: steps 0,2,4,6,8)
    if step <= 4:
        return "down"  # High notes: stems down
    else:
        return "up"    # Low notes: stems up

# ABC pitch to staff step mapping - MUSIC SOFTWARE CONVENTION (C3 = middle C)
# In ABC notation: capital letters = lower octave, lowercase = higher octave  
# Using industry standard: Logic Pro, ABC parsers, DAWs use C3 = middle C
TREBLE_PITCHES = {
    # Lowercase letters (higher octave starting at middle C = C3)
    'c': 3,    # C4 - 2nd space (higher than uppercase)
    'd': 2,    # D4 - 2nd line  
    'e': 1,    # E4 - top space
    'f': 0,    # F4 - top line
    'g': -1,   # G4 - space above staff (ledger line)
    'a': -2,   # A4 - ledger line above staff
    'b': -3,   # B4 - space above ledger line
    # Next octave up (add apostrophe in ABC)
    "c'": -4,  # C5 - higher ledger line
    "d'": -5,  # D5 - even higher
    "e'": -6,  # E5 - even higher
    "f'": -7,  # F5 - very high
}

# Uppercase letters (lower octave, one octave below lowercase)  
TREBLE_PITCHES_UPPER = {
    'C': 10,   # C3 on first ledger line below staff (one octave below lowercase c)
    'D': 9,    # D3 in space below bottom line
    'E': 8,    # E3 on bottom line of staff  
    'F': 7,    # F3 in bottom space
    'G': 6,    # G3 on 2nd line (4th line from top)
    'A': 5,    # A3 in 3rd space
    'B': 4,    # B3 on middle line
}

# Bass clef: Adjusted to match ABC parser behavior exactly
BASS_PITCHES = {
    # Capital letters adjusted to match where ABC parsers actually show them
    'C': 5,    # C on 3rd space (ABC parsers show C, closer to staff)
    'D': 4,    # D on middle line
    'E': 3,    # E on 2nd space  
    'F': 2,    # F on 2nd line from top (where ABC parsers show F,)
    'G': 1,    # G on top space
    'A': 0,    # A on top line
    'B': 6,    # B still on 4th line (this was correct)
    # Next octave up (lowercase in ABC) - keep these the same
    'c': 5,    # C2 - 3rd space
    'd': 4,    # D2 - middle line
    'e': 3,    # E2 - 2nd space
    'f': 2,    # F2 - 2nd line
    'g': 1,    # G2 - top space
    'a': 0,    # A2 - top line
    'b': -1,   # B2 - space above top line
}

def parse_abc_pitch(abc_note: str) -> Tuple[str, int, bool]:
    """
    Parse ABC pitch notation into (pitch_class, octave_adjustment, is_lowercase).
    
    Returns:
        pitch_class: Uppercase letter (C, D, E, F, G, A, B)
        octave_adjustment: Number of octaves to adjust (negative = lower)
        is_lowercase: Whether the original was lowercase
    """
    # Remove duration numbers and other modifiers
    clean_note = re.sub(r'[0-9/]+', '', abc_note)
    
    # Remove accidentals (^, =, _) - they don't affect staff position
    clean_note = re.sub(r'[\^=_]+', '', clean_note)
    
    # Check if original was lowercase before converting
    is_lowercase = clean_note[0].islower() if clean_note else False
    
    # Count octave modifiers
    comma_count = clean_note.count(',')
    apostrophe_count = clean_note.count("'")
    
    # Extract base pitch (keep original case for now)
    base_pitch = clean_note.replace(',', '').replace("'", '')
    
    # Calculate octave adjustment from modifiers only
    octave_adj = apostrophe_count - comma_count
        
    return base_pitch, octave_adj, is_lowercase

def pitch_to_step(staff: str, abc_note: str) -> int:
    """Convert ABC notation to staff step position - FIXED VERSION."""
    pitch_with_case, octave_adj, is_lowercase = parse_abc_pitch(abc_note)
    
    if staff == 'treble':
        # Check both uppercase and lowercase mappings
        if pitch_with_case in TREBLE_PITCHES:
            base_step = TREBLE_PITCHES[pitch_with_case]
        elif pitch_with_case.upper() in TREBLE_PITCHES_UPPER:
            base_step = TREBLE_PITCHES_UPPER[pitch_with_case.upper()]
        else:
            # Handle notes with apostrophes built into the mapping
            pitch_upper = pitch_with_case.upper()
            if pitch_with_case.lower() + "'" in TREBLE_PITCHES:
                base_step = TREBLE_PITCHES[pitch_with_case.lower() + "'"]
                octave_adj -= 1  # Already accounted for one apostrophe
            else:
                # Default mapping for unmapped notes
                base_step = 6  # Default to G4 position
    else:  # bass
        # For bass clef, use the pitch with its original case
        if pitch_with_case in BASS_PITCHES:
            base_step = BASS_PITCHES[pitch_with_case]
        elif pitch_with_case.upper() in BASS_PITCHES:
            # If we only have uppercase but the note was uppercase, use it
            base_step = BASS_PITCHES[pitch_with_case.upper()]
        elif pitch_with_case.lower() in BASS_PITCHES:
            # If we only have lowercase but the note was lowercase, use it  
            base_step = BASS_PITCHES[pitch_with_case.lower()]
        else:
            base_step = 4  # Default to D3 position
    
    # Apply octave adjustments (each octave = 7 steps)
    step_with_octave = base_step - (octave_adj * 7)
    
    # BASS CLEF COMMA FIX: Based on ABC parser behavior analysis
    if staff == 'bass' and octave_adj < 0:
        # B with single comma: should be much higher (above staff)
        if pitch_with_case.upper() == 'B' and octave_adj == -1:
            step_with_octave = base_step - 7  # Raise by full octave (B, goes above staff)
        # B with double comma: treat same as regular B (ignore double comma)
        elif pitch_with_case.upper() == 'B' and octave_adj == -2:
            step_with_octave = base_step  # B,, shows at same position as B
        # Double commas on other notes: need full octave lowering to match ABC parsers
        elif octave_adj == -2:  # Double comma  
            step_with_octave = base_step + 7  # Lower by full octave (7 steps) for double comma
        # Single comma: ignore like we do for B
        else:
            step_with_octave = base_step  # Ignore single comma like we do for B
    
    return step_with_octave

def generate_ledger_lines(x: float, y: float, step: int, staff: str, size: int = 60) -> str:
    """Generate ledger lines for notes outside the staff."""
    lines = []
    line_length = size + 15  # Slightly shorter than before
    
    # Adjusted positioning: align with actual note head position
    line_x_offset = -2   # Shift more to the right (was -5)
    line_y_offset = 4    # Shift lower (was +2, now +4)
    
    if staff == 'treble':
        # Treble staff lines are at steps 0,2,4,6,8
        if step < 0:  # Above staff
            # Add ledger lines for steps -2, -4, -6, etc.
            for ledger_step in range(-2, step - 1, -2):
                if ledger_step >= step:
                    ledger_y = y_for_step(staff, ledger_step) + line_y_offset
                    line_x1 = x - line_length//2 + line_x_offset
                    line_x2 = x + line_length//2 + line_x_offset
                    lines.append(f'<line x1="{line_x1}" y1="{ledger_y}" x2="{line_x2}" y2="{ledger_y}" stroke="#000" stroke-width="2"/>')
        elif step > 8:  # Below staff  
            # Add ledger lines for steps 10, 12, 14, etc.
            for ledger_step in range(10, step + 1, 2):
                if ledger_step <= step:
                    ledger_y = y_for_step(staff, ledger_step) + line_y_offset
                    line_x1 = x - line_length//2 + line_x_offset
                    line_x2 = x + line_length//2 + line_x_offset
                    lines.append(f'<line x1="{line_x1}" y1="{ledger_y}" x2="{line_x2}" y2="{ledger_y}" stroke="#000" stroke-width="2"/>')
    else:  # bass
        # Bass staff lines are at steps 0,2,4,6,8
        bass_line_y_offset = line_y_offset - 2  # Move bass ledger lines up 2px total
        if step < 0:  # Above staff
            for ledger_step in range(-2, step - 1, -2):
                if ledger_step >= step:
                    ledger_y = y_for_step(staff, ledger_step) + bass_line_y_offset
                    line_x1 = x - line_length//2 + line_x_offset
                    line_x2 = x + line_length//2 + line_x_offset
                    lines.append(f'<line x1="{line_x1}" y1="{ledger_y}" x2="{line_x2}" y2="{ledger_y}" stroke="#000" stroke-width="2"/>')
        elif step > 8:  # Below staff
            for ledger_step in range(10, step + 1, 2):
                if ledger_step <= step:
                    ledger_y = y_for_step(staff, ledger_step) + bass_line_y_offset
                    line_x1 = x - line_length//2 + line_x_offset
                    line_x2 = x + line_length//2 + line_x_offset
                    lines.append(f'<line x1="{line_x1}" y1="{ledger_y}" x2="{line_x2}" y2="{ledger_y}" stroke="#000" stroke-width="2"/>')
    
    return '\n    '.join(lines)

def generate_octave_marking(x: float, y: float, marking: str, staff: str, stem_direction: str = "up", size: int = 60) -> str:
    """Generate 8va/8vb text and dashed line, positioned to fit in canvas."""
    if not marking:
        return ""
    
    elements = []
    text_size = 18
    text_style = 'font-family="serif" font-weight="bold" font-style="italic"'
    
    if marking == "8va":
        # For high notes, place 8va to the right of the note to save space
        text_x = x + size // 2 + 15
        text_y = y - 5
        
        # Text
        elements.append(f'<text x="{text_x}" y="{text_y}" {text_style} font-size="{text_size}" text-anchor="start" fill="#000">8va</text>')
        
    elif marking == "8vb":
        # For low notes, place 8vb next to the note based on stem direction
        if stem_direction == "up":
            # Stem goes up, place 8vb below/right of note head
            text_x = x + size // 2 + 5  
            text_y = y + size // 2 + 18
        else:
            # Stem goes down, place 8vb to the right
            text_x = x + size // 2 + 15
            text_y = y + size // 4
        
        # Text
        elements.append(f'<text x="{text_x}" y="{text_y}" {text_style} font-size="{text_size}" text-anchor="start" fill="#000">8vb</text>')
    
    return '\n    '.join(elements)

def get_note_duration(abc_note: str) -> Tuple[str, bool]:
    """Extract note duration from ABC notation. Returns (base_type, is_dotted)."""
    # Remove pitch and modifiers, keep only duration
    duration_match = re.search(r'[0-9/]+$', abc_note)
    if duration_match:
        duration = duration_match.group()
        # Map durations relative to L:1/8 unit length
        # F2 = F × 2 × (1/8) = quarter note
        # F3 = F × 3 × (1/8) = dotted quarter (3/8 = 1.5 × 1/4)
        # F4 = F × 4 × (1/8) = half note  
        # F6 = F × 6 × (1/8) = dotted half (3/4 = 1.5 × 1/2)
        # F8 = F × 8 × (1/8) = whole note
        # F12 = F × 12 × (1/8) = dotted whole (3/2 = 1.5 × 1)
        if duration in ['12']:      # Dotted whole note 
            return 'whole', True
        elif duration in ['8']:      # Whole note
            return 'whole', False
        elif duration in ['6']:      # Dotted half note
            return 'half', True
        elif duration in ['4']:      # Half note
            return 'half', False
        elif duration in ['3']:      # Dotted quarter note
            return 'quarter', True
        elif duration in ['2']:      # Quarter note
            return 'quarter', False
        elif duration in ['1', '']: # Eighth note
            return 'eighth', False
        elif duration in ['/2', '1/2']:  # Sixteenth note
            return 'sixteenth', False
    else:
        # No duration number = unit length = eighth note
        return 'eighth', False
    
    # Default to quarter note for unrecognized durations
    return 'quarter', False

def generate_rest_element(x: float, y: float, abc_note: str, size: int = 60) -> str:
    """Generate rest element based on duration."""
    # Get rest type from ABC duration
    rest_type, is_dotted = get_note_duration(abc_note)
    
    # Map to rest glyph IDs and their proper viewbox dimensions
    rest_configs = {
        'whole': ('rest-whole', 30, 15),
        'half': ('rest-half', 30, 15), 
        'quarter': ('rest-quarter', 17.61, 53.12),  # Updated to match proper quarter rest
        'eighth': ('rest-eighth', 16, 30)
    }
    
    glyph_id, vb_width, vb_height = rest_configs.get(rest_type, ('rest-quarter', 20, 40))
    
    # Calculate proper display dimensions to span staff properly  
    # Quarter rest should extend from halfway into top space to halfway into bottom space
    # That's about 6 staff steps: step 1 to step 7 = 6 × (STAFF_SPACE/2) = 120px
    display_height = 120  # Proper staff-spanning height
    display_width = int((vb_width / vb_height) * display_height)
    
    # Rest positioning - center on the staff position
    rest_element = f'<use xlink:href="#{glyph_id}" href="#{glyph_id}" x="{x-display_width//2}" y="{y-display_height//2}" width="{display_width}" height="{display_height}"/>'
    
    # Add dot for dotted rests
    if is_dotted:
        dot_x = x + 35  # Same spacing as notes for consistency
        dot_y = y - 16  # Same spacing as notes for consistency
        dot_element = f'<use xlink:href="#dot" href="#dot" x="{dot_x}" y="{dot_y}" width="12" height="12"/>'
        return rest_element + '\n    ' + dot_element
    
    return rest_element

def generate_note_element(x: float, y: float, abc_note: str, stem_direction: str = "up", size: int = 60) -> str:
    """Generate simple SVG use element for note placement."""
    # Get note type from ABC duration
    note_type, is_dotted = get_note_duration(abc_note)
    
    # Build glyph ID
    if note_type == 'whole':
        glyph_id = 'whole'  # No stem
    else:
        glyph_id = f'{note_type}-{stem_direction}'
    
    # Head center coordinates in glyph space - NORMALIZED X POSITIONS
    # All note types aligned to same X coordinate for consistent horizontal positioning
    head_centers = {
        'quarter-up': (13.5, 68.46),     # Reference position
        'quarter-down': (13.5, 15.16 - 8),   # Same X as quarter-up
        'half-up': (14.5, 61.0 + 8 - 0.75),  # Nudged 0.5px more down for ledger alignment 
        'half-down': (14.5, 22.0 - 12 - 0.75), # Nudged 0.5px more down for ledger alignment
        'eighth-up': (13.5, 60.0 + 8.5),     # Nudged down 0.5px more (was 60.0 + 9)
        'eighth-down': (13.5, 20.0 - 9.5),   # Nudged down 0.5px more (was 20.0 - 9)
        'sixteenth-up': (13.5, 68.0),        # Estimate - similar to quarter-up
        'sixteenth-down': (13.5, 15.0),      # Estimate - similar to quarter-down
        'whole': (13.5, 12.02 - 2),          # Normalized to 13.5 (was 16.67)
    }
    
    # Get head center for this glyph type
    head_center_x, head_center_y = head_centers.get(glyph_id, (13.5, 15.16))
    
    # Calculate viewBox dimensions for scaling
    viewboxes = {
        'quarter-up': (27.06, 83.62),
        'quarter-down': (27.06, 83.62),
        'half-up': (28.42, 83.76),
        'half-down': (28.42, 83.76),
        'eighth-up': (52.58, 83.76),
        'eighth-down': (30.7, 83.68),
        'sixteenth-up': (53.34, 83.72),
        'sixteenth-down': (29.68, 83.72),
        'whole': (33.34, 24.03),
    }
    
    vb_width, vb_height = viewboxes.get(glyph_id, (27.06, 83.62))
    
    # Calculate actual display size maintaining aspect ratio  
    if note_type == 'whole':
        # Whole notes should be smaller (just the oval)
        display_height = int(size * 0.6)  # Much smaller for whole notes
        display_width = int((vb_width / vb_height) * display_height)
    else:
        # Regular notes with stems
        display_height = int(size * 2.5)
        display_width = int((vb_width / vb_height) * display_height)
    
    # Calculate where to place the glyph so the head center lands at (x,y)
    scale_factor = display_height / vb_height
    offset_x = x - (head_center_x * scale_factor)
    offset_y = y - (head_center_y * scale_factor) - 5  # Nudge up by 5px
    
    note_element = f'<use xlink:href="#{glyph_id}" href="#{glyph_id}" x="{offset_x:.1f}" y="{offset_y:.1f}" width="{display_width}" height="{display_height}"/>'
    
    # Add dot for dotted notes
    if is_dotted:
        # Position dot to the right of note head (final positioning - bigger and further)
        dot_x = x + 35  # Much further right of note head
        dot_y = y - 16  # Much higher up from note center
        dot_element = f'<use xlink:href="#dot" href="#dot" x="{dot_x}" y="{dot_y}" width="12" height="12"/>'
        return note_element + '\n    ' + dot_element
    
    return note_element

def parse_abc_file(filepath: str) -> Dict[str, List[str]]:
    """
    Parse ABC file and extract notes by voice.
    Returns dict like {'treble': ['F', 'G', ...], 'bass': ['G,,', 'B,,']}
    """
    voices = {'treble': [], 'bass': []}
    current_voice = None
    
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            
            # Voice headers (can be mid-line)
            if 'V:1' in line:
                current_voice = 'treble'
                # Extract any notes after the voice marker
                line = line.split('V:1')[-1].strip()
                if not line or 'clef=' in line or 'name=' in line:
                    continue
            elif 'V:2' in line:
                current_voice = 'bass'
                # Extract any notes after the voice marker
                line = line.split('V:2')[-1].strip()
                if not line or 'clef=' in line or 'name=' in line:
                    continue
            elif line.startswith('%%score'):
                continue
            elif line.startswith(('X:', 'T:', 'C:', 'M:', 'L:', 'Q:', 'K:', '%')) or 'clef=' in line or 'name=' in line:
                continue
                
            # Skip empty lines, non-note lines, or if no voice is set
            if not line or current_voice is None:
                continue
                
            # Only process lines that look like musical notation (contain | or notes)
            if not ('|' in line or re.search(r'[A-Ga-g]', line)):
                continue
                
            # Extract notes from the line
            # Split by spaces and bars, extract note patterns
            parts = re.split(r'[|\s]+', line)
            for part in parts:
                if not part:
                    continue
                    
                # Find all note patterns (letter + optional modifiers + optional duration)
                # Also include rests (z)
                notes = re.findall(r"[A-Ga-gz][',]*[0-9/]*", part)
                voices[current_voice].extend(notes)
    
    return voices

def generate_svg(treble_notes: List[str], bass_notes: List[str], beat_index: int = 0) -> str:
    """Generate SVG for specific beat (default first beat)."""
    
    # Get the specific beat notes (or empty if not enough notes)
    treble_note = treble_notes[beat_index] if beat_index < len(treble_notes) else None
    bass_note = bass_notes[beat_index] if beat_index < len(bass_notes) else None
    
    # Generate note elements, ledger lines, and octave markings
    note_elements = []
    ledger_elements = []
    octave_elements = []
    
    if treble_note:
        if treble_note.startswith('z'):
            # Handle rest - place in middle of treble staff
            rest_element = generate_rest_element(NOTE_X, y_for_step('treble', 4), treble_note)
            note_elements.append(f'    {rest_element}')
        else:
            step = pitch_to_step('treble', treble_note)
            y = y_for_step('treble', step)
            
            # Apply 8va/8vb transposition if needed
            y, octave_marking, final_step = apply_octave_transposition(y, step, 'treble')
            
            # Determine stem direction
            stem_direction = get_stem_direction(final_step, 'treble')
            
            note_element = generate_note_element(NOTE_X, y, treble_note, stem_direction)
            note_elements.append(f'    {note_element}')
            
            # Add ledger lines if needed (use final step after transposition)
            ledger_lines = generate_ledger_lines(NOTE_X, y, final_step, 'treble')
            if ledger_lines:
                ledger_elements.append(f'    {ledger_lines}')
                
            # Add octave marking if needed
            if octave_marking:
                octave_mark = generate_octave_marking(NOTE_X, y, octave_marking, 'treble', stem_direction)
                if octave_mark:
                    octave_elements.append(f'    {octave_mark}')
        
    if bass_note:
        if bass_note.startswith('z'):
            # Handle rest - place in middle of bass staff
            rest_element = generate_rest_element(NOTE_X, y_for_step('bass', 4), bass_note)
            note_elements.append(f'    {rest_element}')
        else:
            step = pitch_to_step('bass', bass_note)
            y = y_for_step('bass', step)
            
            # Apply 8va/8vb transposition if needed
            y, octave_marking, final_step = apply_octave_transposition(y, step, 'bass')
            
            # Determine stem direction
            stem_direction = get_stem_direction(final_step, 'bass')
            
            note_element = generate_note_element(NOTE_X, y, bass_note, stem_direction)
            note_elements.append(f'    {note_element}')
            
            # Add ledger lines if needed (use final step after transposition)
            ledger_lines = generate_ledger_lines(NOTE_X, y, final_step, 'bass')
            if ledger_lines:
                ledger_elements.append(f'    {ledger_lines}')
                
            # Add octave marking if needed
            if octave_marking:
                octave_mark = generate_octave_marking(NOTE_X, y, octave_marking, 'bass', stem_direction)
                if octave_mark:
                    octave_elements.append(f'    {octave_mark}')
    
    notes_svg = '\n'.join(note_elements) if note_elements else '    <!-- No notes for this beat -->'
    ledger_svg = '\n'.join(ledger_elements) if ledger_elements else ''
    octave_svg = '\n'.join(octave_elements) if octave_elements else ''
    
    # SVG template with our canonical layout
    svg = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="600" height="600" viewBox="0 0 600 600">
  <defs>
    <!-- Quarter notes -->
    <symbol id="quarter-up" viewBox="0 0 27.06 83.62">
      <path fill="currentColor" d="M27.06,68.46h0V.55c0-.3-.25-.55-.55-.55h-2.43c-.3,0-.55.25-.55.55v62.39c-3.59-1.78-9.07-1.46-14.24,1.23-7.18,3.73-11,10.59-8.55,15.31,2.46,4.72,10.26,5.53,17.44,1.79,5.99-3.11,8.9-8.42,8.87-12.81Z"/>
    </symbol>
    <symbol id="quarter-down" viewBox="0 0 27.06 83.62">
      <path fill="currentColor" d="M0,15.16H0v67.91c0,.3.25.55.55.55h2.43c.3,0,.55-.25.55-.55V20.68c3.59,1.78,9.07,1.46,14.24-1.23,7.18-3.73,11-10.59,8.55-15.31C23.86-.58,16.05-1.38,8.87,2.35,2.88,5.46-.03,10.77,0,15.16Z"/>
    </symbol>
    
    <!-- Half notes -->
    <symbol id="half-up" viewBox="0 0 28.42 83.76">
      <path fill="currentColor" d="M27.89,0h-2.56c-.29,0-.53.24-.53.53l-.03,61.18c-.33-.22-.64-.41-.91-.52-3.92-1.83-9.44-1.36-14.41,1.23-7.56,3.93-11.32,11.19-8.55,16.52,1.4,2.69,4.19,4.38,7.86,4.75.51.05,1.03.08,1.55.08,2.93,0,6.08-.81,9.02-2.34,5.85-3.04,8.67-8.21,8.52-13.01l.04-.03L28.42.53c0-.29-.24-.53-.53-.53ZM17.43,77.75c-2.76,1.43-5.68,2.08-8.24,1.82-1.3-.13-3.62-.64-4.6-2.54-1.64-3.16,1.46-8.16,6.78-10.93,2.36-1.23,4.88-1.87,7.11-1.87,1.36,0,2.61.24,3.65.73h.03c.08.05,1.83.91,2.46,3.46.18,3.16-2.82,7.06-7.19,9.33Z"/>
    </symbol>
    <symbol id="half-down" viewBox="0 0 28.42 83.76">
      <path fill="currentColor" d="M.53,83.76h2.56c.29,0,.53-.24.53-.53l.03-61.18c.33.22.64.41.91.52,3.92,1.83,9.44,1.36,14.41-1.23,7.56-3.93,11.32-11.19,8.55-16.52C26.11,2.14,23.32.46,19.65.08c-.51-.05-1.03-.08-1.55-.08-2.93,0-6.08.81-9.02,2.34C3.23,5.38.41,10.55.56,15.35l-.04.03L0,83.23c0,.29.24.53.53.53ZM10.99,6.02c2.76-1.43,5.69-2.08,8.24-1.82,1.3.13,3.62.64,4.6,2.54,1.64,3.16-1.46,8.16-6.78,10.93-2.36,1.23-4.88,1.87-7.11,1.87-1.36,0-2.61-.24-3.65-.73h-.03c-.08-.05-1.83-.91-2.46-3.46-.18-3.16,2.82-7.06,7.19-9.33Z"/>
    </symbol>
    
    <!-- Eighth notes -->
    <symbol id="eighth-up" viewBox="0 0 52.58 83.76">
      <path fill="currentColor" d="M34.13,18.39c-2.85-1.39-4.69-4.07-5.71-7-.42-1.22-.71-2.47-.9-3.75-.08-.57-.12-4.42-.16-5-.03-.47.01-1.03-.15-1.48-.31-.85-2.11-1.35-2.95-1.1-.65.19-.65,1.03-.62,1.57.06.83.06,4.94.06,5.78,0,1.69-.01,3.38-.02,5.07,0,2.21-.02,4.42-.02,6.63,0,2.55-.02,5.09-.03,7.64,0,2.7-.02,5.4-.03,8.1,0,2.67-.02,5.33-.03,8,0,2.45-.02,4.9-.03,7.35,0,2.05-.01,4.1-.02,6.15,0,1.47-.01,2.93-.01,4.4,0,.7,0,1.4,0,2.1,0,0,0,.1,0,.1-3.59-1.78-9.07-1.46-14.24,1.23-7.18,3.73-11,10.59-8.55,15.31,2.46,4.72,8.66,5.76,15.84,2.02,5.99-3.11,9.92-8.42,9.89-12.81V25.62c8.76-.27,16.88,10.33,16.88,10.33,8.18,14.4-5.08,28.74-5.08,28.74-.88,2.72.92,2.15.92,2.15,4.69-2.83,10.14-11.74,10.14-11.74,12.54-20.95-15.2-36.71-15.2-36.71Z"/>
    </symbol>
    <symbol id="eighth-down" viewBox="0 0 30.7 83.68">
      <path fill="currentColor" d="M27.66,29.75c-1.04-2.52-2.32-4.96-3.82-7.24-.21-.31-1.46-2.61-1.89-2.61-3.19,0,.21,5.32,.21,5.32,6.17,13.18,3.47,25.91,3.47,25.91-1.5,9.93-8.13,14.07-18.04,17.32-2.69.88-3.54.55-4.72,1.78l.1-49.39c3.59,1.78,9.07,1.29,14.24-1.39,7.18-3.73,11-10.59,8.55-15.31C23.29-.58,15.48-1.38,8.31,2.35,2.32,5.46-.01,10.61.01,15v65.95c0,.49-.01.98-.01,1.39,0,.62-.03,1.07.62,1.26.76.22,2.21.05,2.71-.63,0,0,0,0,0,.01,0,0,0-.02,0-.03.05-.06.09-.13.12-.2.12-.34.2-.73.25-1.11,1.61-5.15,4.07-6.03,9.53-9.41,6.82-4.24,13.25-9.97,15.9-17.73.1-.3.2-.61.29-.92,2.32-7.8,1.3-16.4-1.77-23.83Z"/>
    </symbol>
    
    <!-- Sixteenth notes -->
    <symbol id="sixteenth-up" viewBox="0 0 53.34 83.72">
      <path fill="currentColor" d="M52.54,39.17c-.16-.51-.35-1.02-.56-1.52,1.79-4.71.8-8.47.8-8.47-2.38-7.44-9.28-13.61-15.91-17.73-5.45-3.38-7.91-4.26-9.53-9.41-.05-.38-.12-.76-.25-1.11-.03-.07-.08-.14-.12-.2,0,0,0-.02,0-.03,0,0,0,0,0,.01-.49-.67-1.94-.85-2.71-.63-.65.19-.62.96-.62,1.57,0,.13,0,.27,0,.41l-.13,60.81c-3.59-1.78-9.07-1.29-14.24,1.39-7.18,3.73-11,10.59-8.55,15.31,2.46,4.72,10.26,5.53,17.44,1.79,5.99-3.11,8.32-8.26,8.29-12.65V22.81c1.69,1,1.86,1.19,4.51,2.41,9.48,4.34,20.55,15.96,16.69,26.44-.51,1.39-2.1,4.02-2.79,5.33-1.58,2.98,2.5,2.17,4.13-.23,3.64-5.36,5.48-11.49,3.53-17.59ZM36.64,21.44c-3.26-2.02-6.59-4.49-9.19-7.27.84.42,1.82.42,3.78,1.06,9.91,3.25,16.54,7.39,18.04,17.32,0,0,0,.09.01.26-3.26-4.61-8.01-8.49-12.65-11.37Z"/>
    </symbol>
    <symbol id="sixteenth-down" viewBox="0 0 29.68 83.72">
      <path fill="currentColor" d="M28.89,44.56c1.95-6.1.11-12.23-3.53-17.59-1.63-2.4-5.71-3.21-4.13-.23.69,1.31,2.28,3.94,2.79,5.33,3.86,10.48-7.21,22.09-16.69,26.44-2.61,1.2-2.81,1.41-4.44,2.37l.08-40.03c3.59,1.78,9.07,1.29,14.24-1.39,7.18-3.73,11-10.59,8.55-15.31C23.31-.58,15.5-1.38,8.32,2.35,2.33,5.46,0,10.61.03,15v64.49h0c0,.84-.03,1.73-.03,2.57,0,.62-.03,1.38.62,1.57.76.22,2.21.05,2.71-.63,0,0,0,0,0,.01,0,0,0-.02,0-.03.05-.06.09-.13.12-.2.13-.34.2-.73.25-1.11,1.61-5.15,4.07-6.03,9.53-9.41,6.63-4.12,13.52-10.29,15.91-17.73,0,0,.98-3.77-.8-8.47.21-.5.4-1.01.56-1.52ZM25.62,51.17c-1.5,9.93-8.13,14.07-18.04,17.32-1.96.64-2.94.64-3.78,1.06,2.6-2.79,5.93-5.25,9.19-7.27,4.63-2.87,9.39-6.76,12.65-11.37,0,.16-.01.26-.01.26Z"/>
    </symbol>
    
    <!-- Whole note (no stem) -->
    <symbol id="whole" viewBox="0 0 33.34 24.03">
      <path fill="currentColor" d="M16.67,24.03C7.32,24.03,0,18.76,0,12.02S7.32,0,16.67,0s16.67,5.28,16.67,12.02-7.32,12.02-16.67,12.02ZM16.67,4.15c-6.79,0-12.52,3.6-12.52,7.87s5.74,7.87,12.52,7.87,12.52-3.6,12.52-7.87-5.74-7.87-12.52-7.87Z"/>
    </symbol>
    
    <!-- Rest symbols -->
    <symbol id="rest-whole" viewBox="0 0 30 15">
      <rect x="5" y="8" width="20" height="7" fill="currentColor"/>
    </symbol>
    <symbol id="rest-half" viewBox="0 0 30 15">
      <rect x="5" y="0" width="20" height="7" fill="currentColor"/>
    </symbol>
    <symbol id="rest-quarter" viewBox="0 0 17.61 53.12">
      <path fill="currentColor" d="M6.37.37c1.26.81,2.37,1.83,3.28,3.03,0,0,6.56,8.62,6.65,8.73.71.94,1.91,1.85.93,3.12-.46.6-1.15,1.02-1.66,1.6-.46.53-.91,1.07-1.34,1.62-1.02,1.29-2.04,2.65-2.74,4.15-.26.55-.31,1.08-.46,1.65-.33,1.19-.41,2.5-.33,3.72.07,1.11.29,2.24.74,3.26.44.99,1.24,1.83,1.88,2.69.6.79,1.21,1.58,1.81,2.38.44.58.89,1.17,1.33,1.75.33.43,1.07,1.09,1.15,1.64.02.13,0,.26-.03.39-.19.87-.86,1.57-1.73,1.76-.06.01-.12.02-.18,0-.06-.02-.1-.06-.14-.09-1.79-1.58-4.43-2.86-6.88-2.45-.91.15-1.42.99-1.81,1.75-.87,1.68-.66,3.69.01,5.4.73,1.86,1.95,3.6,2.95,5.34.03.06.07.11.07.18.08.61-1.2,1.02-1.62,1.1-.41.09-1.01-.63-1.3-.88-.47-.4-.92-.8-1.37-1.22-.87-.82-1.7-1.69-2.47-2.61-1.39-1.66-2.86-3.59-3.05-5.83-.07-.88-.08-1.89.07-2.77.25-1.47.9-2.87,2.02-3.87.72-.64,1.59-1.1,2.51-1.36.46-.13.94-.22,1.42-.25.7-.05,1.23.05,1.91.21.53.12,1.46.22,1.58-.49.12-.66-.44-1.45-.77-1.96-1.17-1.92-2.44-3.8-3.8-5.59-.53-.7-1.08-1.39-1.68-2.04-.53-.57-1.05-1.19-1.77-1.52-.15-.07-.32-.12-.46-.22-.51-.33-.32-1.26-.2-1.76.15-.6.51-1.08.97-1.47,1.88-1.59,3.65-3.4,5.11-5.37,1.11-1.49,2.65-3.66,1.74-5.6-.96-2.02-2.2-4.07-3.65-5.77-.3-.35-.61-.68-.93-1-.36-.35-.02-1.03.29-1.34.53-.54,1.21-.43,1.83-.09l.12.08Z"/>
    </symbol>
    <symbol id="rest-eighth" viewBox="0 0 16 30">
      <path fill="currentColor" d="M12,0 L12,20 C10,20 7,24 5,28 L7,30 C10,26 12,22 14,20 L14,0 Z"/>
      <circle cx="8" cy="25" r="2" fill="currentColor"/>
    </symbol>
    
    <!-- Dot for dotted notes -->
    <symbol id="dot" viewBox="0 0 10 10">
      <circle cx="5" cy="5" r="4" fill="currentColor"/>
    </symbol>
  </defs>

  <rect x="0" y="0" width="600" height="600" fill="#fff"/>

  <!-- Staves -->
  <g stroke="#000" fill="none" stroke-linecap="round">
    <g stroke-width="6">
      <line x1="100" y1="80"  x2="500" y2="80"  />
      <line x1="100" y1="120" x2="500" y2="120" />
      <line x1="100" y1="160" x2="500" y2="160" />
      <line x1="100" y1="200" x2="500" y2="200" />
      <line x1="100" y1="240" x2="500" y2="240" />
      <line x1="100" y1="68"  x2="100" y2="252" stroke-width="14"/>
    </g>
    <g stroke-width="6">
      <line x1="100" y1="320" x2="500" y2="320" />
      <line x1="100" y1="360" x2="500" y2="360" />
      <line x1="100" y1="400" x2="500" y2="400" />
      <line x1="100" y1="440" x2="500" y2="440" />
      <line x1="100" y1="480" x2="500" y2="480" />
      <line x1="100" y1="308" x2="100" y2="492" stroke-width="14"/>
    </g>
  </g>

  <!-- Clefs: restore to exact Illustrator coordinates -->
  <g fill="#000">
    <path d="M214.79,173.49c-5.14-3.98-13.67-5.63-19.91-5.93-3.28-.16-3.68.51-5.3-1.87-1.5-2.21-1.54-7.47-2.1-10.13-1.4-6.73-2.79-13.46-4.19-20.19,14.82-9.15,25.92-24.14,30.37-40.97,4.45-16.84,2.19-35.35-6.17-50.63-2.67-4.87-6.93-9.94-12.47-9.63-4.15.23-7.47,3.46-10,6.76-8.02,10.45-12.21,23.48-13.48,36.58-1.27,13.11.26,26.34,2.79,39.26.24,1.23.49,2.53.08,3.72-.44,1.29-1.57,2.19-2.65,3.02-15.61,12.05-32.42,24.2-40.68,42.12-4.9,10.63-6.37,22.81-4.13,34.3,2.3,11.84,8.81,23.17,19,29.62,6.68,4.23,14.53,6.19,22.33,7.44,9.88,1.57,20.1,2.08,29.8-.34,1.12,5.91,2.07,11.84,2.8,17.81.58,4.71,1.16,9.5,1.38,14.27.07,1.52-.05,3.01-.05,4.53-.31,3.11-1.52,6.18-3.2,8.81-.75,1.17-1.6,2.27-2.56,3.27-2.89,3.05-6.52,5.31-10.35,6.99-2.73,1.19-5.67,1.92-8.64,2.06-1.5.07-3,0-4.48-.25-.12-.02-.26-.04-.39-.06,5.92-3.2,9.98-9.38,9.98-16.57,0-10.44-8.46-18.91-18.91-18.91s-18.91,8.46-18.91,18.91c0,3.17.85,6.1,2.23,8.72l-.11-.03c.27.52.59.96.88,1.45.12.18.21.38.34.56,9.91,15.65,31.63,14.79,31.63,14.79,2.65.12,5.45-.44,7.99-1.09,5.68-1.46,11.01-4.3,15.12-8.51,1.96-2.01,3.63-4.3,4.99-6.75,1.11-2.01,2.1-4.12,2.62-6.38.72-3.13.49-6.32.19-9.48-.7-7.34-2.06-14.59-3.51-21.84-.34-1.71-.69-3.43-1.03-5.14-.61-3.06-1.22-6.12-1.84-9.18-.03-.15-.06-.31-.09-.46,0,0,18.19-5.31,21.98-21.22,0,0,7.2-25.01-11.37-39.41ZM182.2,60.02c7.42-10,23.45-5.56,24.6,6.84,0,0,2.26,17.78-13.23,35.39-2.52,3.43-7.87,8.66-14.11,14.29l-1.86-8.84c-.13-.65-.22-2.3-.32-2.96-1.65-10.6-1.92-25.8-.92-31.68,1.32-7.8,5.85-13.03,5.85-13.03ZM152.16,222.81c-7.74-6.57-13.37-16.02-13.86-26.16-.56-11.65,5.54-22.61,12.84-31.7,7.42-9.24,16.29-17.31,26.18-23.82,1.7,7.35,3.4,14.7,5.09,22.05.36,1.55.7,3.23.04,4.67-.72,1.57-2.42,2.4-3.95,3.23-11.17,6.09-18.02,18.31-18.25,30.92-.09,4.76.63,9.69,3.16,13.72,2.53,4.03,7.18,6.97,11.91,6.46-2.03.22-5.29-8.57-5.74-10.06-1.26-4.17-1.52-8.67-.72-12.96,1.69-9.09,8.58-15.34,17.88-16.2,3.34,15.07,7.22,32.96,10.37,48.65.02.08.03.15.05.23-15.22,4.85-32.83,1.32-45.01-9.01ZM202.96,228.99l-1.31-6.86c-.03-.19-.03-.38-.07-.57l-8.18-38.84c5.21.28,19.78,2.82,23.55,22.33,0,0,3.24,14.68-13.99,23.94Z"/>
    <g>
      <circle cx="258.66" cy="349.3" r="12.94"/>
      <circle cx="258.66" cy="405.14" r="12.94"/>
    </g>
    <path d="M214.06,340.15c-8.33-9.26-18.45-14.9-29.31-17.36-2.36-.53-5.99-.96-9.15-.95-.08,0-.16,0-.25,0,0,0-.01,0-.02,0-.97,0-1.94.1-2.91.21-.01,0-.03,0-.04,0,0,0,0,0,0,0-.21.02-.43.05-.64.07-2.92.32-5.82.84-8.66,1.6-.65.17-1.3.36-1.94.56-1.68.52-3.33,1.13-4.95,1.81-12.09,5.09-24.25,15.41-28.44,34.5,0,0-1.99,10.95,6.81,19.6,5.43,5.53,13.86,7.52,21.44,4.33,9.91-4.17,14.57-15.59,10.39-25.51-3.01-7.15-9.8-11.5-17.06-11.84,3.35-3.41,7.43-6.05,11.82-7.92,3.5-1.49,7.2-2.5,10.96-3.09.39-.06.81-.08,1.22-.11,21.05,0,37.36,24.42,35.07,44.26-.49,4.23-1.27,8.42-2.3,12.55-4.34,17.33-12.38,34.28-25.13,46.93-4.35,4.32-9.46,7.23-14.9,9.79-2.49,1.17-5.08,2.22-7.44,3.64-3.23,1.95-6.16,7.86-.43,8.76,1.1.17,2.2,0,3.27-.3,6.83-1.95,13.03-5.5,18.84-9.5,1.82-1.25,3.6-2.55,5.35-3.90,20.4-15.67,36.92-38.53,39.73-64.65,1.68-15.56-.45-31.4-11.34-43.5Z"/>
  </g>

  <!-- Ledger lines (drawn before notes so notes appear on top) -->
  <g stroke="#000" fill="none">
{ledger_svg}
  </g>

  <!-- Octave markings (8va/8vb) -->
  <g>
{octave_svg}
  </g>

  <!-- Notes -->
  <g style="color:#111; fill:currentColor">
{notes_svg}
  </g>
</svg>'''
    
    return svg

def parse_single_beat_file(filepath: str) -> Tuple[Optional[str], Optional[str]]:
    """Parse a single beat ABC file and return (treble_note, bass_note)."""
    voices = parse_abc_file(filepath)
    treble_note = voices['treble'][0] if voices['treble'] else None
    bass_note = voices['bass'][0] if voices['bass'] else None
    return treble_note, bass_note

def main():
    """Generate individual SVGs for all beats in the combined sequence."""
    import os
    import datetime
    
    abc_file_path = '/Users/jonathanmann/SongADAO Dropbox/Jonathan Mann/projects/THE-LONG-SONG/algo-testing***/outputs/blockchain_simulation_20250927_183233/combined_sequence.abc'
    
    # Create timestamped output folder
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_base = 'outputs'
    output_folder = f'{output_base}/abc_svg_batch_{timestamp}'
    
    # Create directories if they don't exist
    os.makedirs(output_folder, exist_ok=True)
    
    print(f"Processing ABC file: {abc_file_path}")
    print(f"Output folder: {output_folder}")
    
    # Parse the ABC file
    voices = parse_abc_file(abc_file_path)
    
    print(f"\nParsed ABC file:")
    print(f"  Treble notes: {len(voices['treble'])} notes")
    print(f"  Bass notes: {len(voices['bass'])} notes")
    print(f"  Sample treble: {voices['treble'][:5]}{'...' if len(voices['treble']) > 5 else ''}")
    print(f"  Sample bass: {voices['bass'][:5]}{'...' if len(voices['bass']) > 5 else ''}")
    
    # Generate SVG for each beat
    max_beats = max(len(voices['treble']), len(voices['bass']))
    print(f"\nGenerating {max_beats} individual beat SVGs...")
    
    for beat_index in range(max_beats):
        # Generate SVG for this beat
        svg_content = generate_svg(voices['treble'], voices['bass'], beat_index)
        
        # Create descriptive filename
        output_file = f'{output_folder}/beat_{beat_index:04d}.svg'
        
        with open(output_file, 'w') as f:
            f.write(svg_content)
        
        # Show progress and beat info
        treble_note = voices['treble'][beat_index] if beat_index < len(voices['treble']) else None
        bass_note = voices['bass'][beat_index] if beat_index < len(voices['bass']) else None
        
        beat_info = []
        if treble_note:
            beat_info.append(f"T:{treble_note}")
        if bass_note:
            beat_info.append(f"B:{bass_note}")
        
        if beat_index % 50 == 0 or beat_index < 10:  # Show first 10 and every 50th
            print(f"  Beat {beat_index:4d}: {' + '.join(beat_info) if beat_info else 'empty'}")
    
    print(f"\n✓ Generated {max_beats} SVG files in: {output_folder}")
    print(f"  Files: beat_0000.svg through beat_{max_beats-1:04d}.svg")

if __name__ == '__main__':
    main()
