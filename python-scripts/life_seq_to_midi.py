#!/usr/bin/env python3
"""
Extract the Life lens lead/bass sequences from OUTPUTS/life_lens_tone_token_1.html
and export them as a simple two-track MIDI file.

Usage:
    python3 python-scripts/life_seq_to_midi.py \
        --html OUTPUTS/life_lens_tone_token_1.html \
        --out OUTPUTS/life_lens_tone_token_1.mid
"""

import argparse
import json
import re
from pathlib import Path
from typing import List, Tuple


TPQ = 480  # matches durations produced by SongAlgorithm


def read_sequences(html_path: Path) -> Tuple[List[Tuple[int, int]], List[Tuple[int, int]]]:
    text = html_path.read_text()
    pattern = re.compile(r"const (base(?:Lead|Bass)Seq)=\[(.*?)\];", re.DOTALL)
    raw = {}
    for match in pattern.finditer(text):
        key = match.group(1)
        body = match.group(2)
        body = body.replace("p:", '"p":').replace("d:", '"d":')
        raw[key] = json.loads(f"[{body}]")

    if "baseLeadSeq" not in raw or "baseBassSeq" not in raw:
        raise RuntimeError("Could not find baseLeadSeq/baseBassSeq in HTML.")

    lead = [(int(evt["p"]), int(evt["d"])) for evt in raw["baseLeadSeq"]]
    bass = [(int(evt["p"]), int(evt["d"])) for evt in raw["baseBassSeq"]]
    return lead, bass


def encode_var_len(value: int) -> bytes:
    """Standard variable-length quantity encoding (big endian, 7 bits per byte)."""
    buffer = value & 0x7F
    value >>= 7
    out = bytearray([buffer])
    while value:
        buffer = value & 0x7F
        value >>= 7
        out.insert(0, buffer | 0x80)
    return bytes(out)


def build_track(events: List[Tuple[int, int]], channel: int) -> bytes:
    data = bytearray()
    rest = 0
    for pitch, duration in events:
        if pitch < 0:
            rest += duration
            continue

        data.extend(encode_var_len(rest))
        data.extend(bytes([0x90 | channel, pitch, 0x50]))
        data.extend(encode_var_len(duration))
        data.extend(bytes([0x80 | channel, pitch, 0x00]))
        rest = 0

    data.extend(encode_var_len(rest))
    data.extend(b"\xFF\x2F\x00")
    return b"MTrk" + len(data).to_bytes(4, "big") + data


def build_header(num_tracks: int) -> bytes:
    return (
        b"MThd"
        + (6).to_bytes(4, "big")
        + (1).to_bytes(2, "big")  # format 1
        + (num_tracks).to_bytes(2, "big")
        + TPQ.to_bytes(2, "big")
    )


def build_tempo_track(bpm: int = 120) -> bytes:
    micros = int(60_000_000 / bpm)
    data = bytearray()
    data.extend(b"\x00\xFF\x51\x03" + micros.to_bytes(3, "big"))  # tempo
    data.extend(b"\x00\xFF\x58\x04\x04\x02\x18\x08")  # 4/4
    data.extend(b"\x00\xFF\x2F\x00")
    return b"MTrk" + len(data).to_bytes(4, "big") + data


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert Life lens sequences to MIDI.")
    parser.add_argument("--html", default="OUTPUTS/life_lens_tone_token_1.html", type=Path, help="Path to generated HTML file.")
    parser.add_argument("--out", default="OUTPUTS/life_lens_tone_token_1.mid", type=Path, help="Destination MIDI file.")
    args = parser.parse_args()

    lead, bass = read_sequences(args.html)
    header = build_header(3)
    tempo = build_tempo_track()
    lead_track = build_track(lead, channel=0)
    bass_track = build_track(bass, channel=1)

    midi_bytes = header + tempo + lead_track + bass_track
    args.out.write_bytes(midi_bytes)
    print(f"Wrote MIDI with {len(lead)} lead notes and {len(bass)} bass notes to {args.out}")


if __name__ == "__main__":
    main()
