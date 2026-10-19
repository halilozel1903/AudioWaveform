#!/usr/bin/env python3
"""Generates the demo audio bundled with the example apps.

Everything is synthesized here from sine waves, so the files contain no recordings and no samples
from anywhere else. They are written as Core Audio Format (.caf) files with 16-bit little-endian
linear PCM, mono, 22,050 Hz, which AVAudioFile and AVAudioPlayer read directly.

Usage: python3 scripts/generate-demo-audio.py [output directory]
The default output directory is Example/Shared/DemoAudio. Only the Python standard library is used,
and a fixed random seed keeps the output the same from run to run.

Tracks:
  chord-progression.caf  28 s  I-V-vi-IV in C: a soft pad, a plucked arpeggio and a kick pulse, with an
                                intro, a break and a fade out, so the waveform has quiet and loud parts.
  arpeggio.caf           16 s  Plucked notes from the A minor pentatonic scale with accents and rests:
                                sharp attacks and decays.
  swells.caf             14 s  Slow tone swells with a little tremolo: smooth, rounded shapes.
"""

import math
import os
import random
import struct
import sys

SAMPLE_RATE = 22050
TWO_PI = 2.0 * math.pi


def midi_to_hz(note):
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


def silence(seconds):
    return [0.0] * int(round(seconds * SAMPLE_RATE))


def add_into(buffer, start_seconds, samples):
    start = int(round(start_seconds * SAMPLE_RATE))
    end = min(len(buffer), start + len(samples))
    for index in range(start, end):
        buffer[index] += samples[index - start]


def envelope(index, length, attack, release):
    """Linear attack and release in samples, 1 in between."""
    if index < attack:
        return index / attack
    if index > length - release:
        return max(0.0, (length - index) / release)
    return 1.0


def pad(notes, seconds, level):
    """A soft chord: two slightly detuned sines per note and a quieter octave above."""
    length = int(seconds * SAMPLE_RATE)
    attack = int(0.35 * SAMPLE_RATE)
    release = int(0.5 * SAMPLE_RATE)
    frequencies = [midi_to_hz(note) for note in notes]
    out = []
    for index in range(length):
        t = index / SAMPLE_RATE
        value = 0.0
        for frequency in frequencies:
            value += math.sin(TWO_PI * frequency * t)
            value += 0.6 * math.sin(TWO_PI * frequency * 1.004 * t)
            value += 0.2 * math.sin(TWO_PI * frequency * 2.0 * t)
        out.append(level * envelope(index, length, attack, release) * value / (len(frequencies) * 1.8))
    return out


def pluck(note, seconds, level, brightness=0.45):
    """A plucked note: a sine and two harmonics with a short attack and an exponential decay."""
    length = int(seconds * SAMPLE_RATE)
    frequency = midi_to_hz(note)
    attack = int(0.004 * SAMPLE_RATE)
    out = []
    for index in range(length):
        t = index / SAMPLE_RATE
        decay = math.exp(-t * 6.5)
        rise = min(1.0, index / attack) if attack else 1.0
        value = math.sin(TWO_PI * frequency * t)
        value += brightness * math.exp(-t * 9.0) * math.sin(TWO_PI * frequency * 2.0 * t)
        value += 0.5 * brightness * math.exp(-t * 14.0) * math.sin(TWO_PI * frequency * 3.0 * t)
        out.append(level * rise * decay * value / (1.0 + 1.5 * brightness))
    return out


def kick(level):
    """A sine that sweeps from 110 Hz down to 45 Hz and fades within a quarter of a second."""
    length = int(0.28 * SAMPLE_RATE)
    out = []
    phase = 0.0
    for index in range(length):
        t = index / SAMPLE_RATE
        frequency = 45.0 + 65.0 * math.exp(-t * 28.0)
        phase += TWO_PI * frequency / SAMPLE_RATE
        out.append(level * math.exp(-t * 11.0) * math.sin(phase))
    return out


def normalize(buffer, peak):
    top = max(abs(value) for value in buffer) or 1.0
    return [value * peak / top for value in buffer]


def fade(buffer, fade_in, fade_out):
    fade_in_samples = int(fade_in * SAMPLE_RATE)
    fade_out_samples = int(fade_out * SAMPLE_RATE)
    length = len(buffer)
    for index in range(min(fade_in_samples, length)):
        buffer[index] *= index / fade_in_samples
    for offset in range(min(fade_out_samples, length)):
        buffer[length - 1 - offset] *= offset / fade_out_samples
    return buffer


def chord_progression():
    beat = 0.5          # 120 BPM
    bar = 4 * beat
    bars = 14
    buffer = silence(bars * bar)
    # C, G, Am, F; each as a pad voicing and the notes the arpeggio walks through.
    chords = [
        ([48, 55, 60, 64], [60, 64, 67, 72]),
        ([43, 50, 59, 62], [55, 59, 62, 67]),
        ([45, 52, 57, 60], [57, 60, 64, 69]),
        ([41, 48, 57, 60], [53, 57, 60, 65]),
    ]
    for index in range(bars):
        start = index * bar
        pad_notes, arpeggio_notes = chords[index % len(chords)]
        is_break = index == 10
        # Intro (bars 0-1): the pad alone and quiet. Break (bar 10): a quiet pad.
        pad_level = 0.22 if index < 2 or is_break else 0.32
        add_into(buffer, start, pad(pad_notes, bar + 0.4, pad_level))
        if index >= 2 and not is_break:
            # The arpeggio grows louder towards the end.
            loudness = 0.30 + 0.035 * index
            for step in range(8):
                note = arpeggio_notes[[0, 1, 2, 3, 2, 1, 2, 3][step]]
                accent = 1.0 if step % 2 == 0 else 0.7
                add_into(buffer, start + step * beat / 2, pluck(note, 0.45, loudness * accent))
        if 6 <= index and not is_break:
            for step in range(4):
                add_into(buffer, start + step * beat, kick(0.55 if step % 2 == 0 else 0.4))
    return fade(normalize(buffer, 0.89), 0.3, 1.6)


def arpeggio():
    rng = random.Random(1903)
    step = 60.0 / 100.0 / 4.0   # sixteenth notes at 100 BPM
    seconds = 16.0
    buffer = silence(seconds)
    scale = [57, 60, 62, 64, 67, 69, 72, 74, 76, 79]
    steps = int((seconds - 1.0) / step)
    for index in range(steps):
        bar_position = index % 16
        # A rest in every fourth bar's second half, and a few random rests.
        if (index // 16) % 4 == 3 and bar_position >= 8:
            continue
        if rng.random() < 0.12:
            continue
        accent = 1.0 if bar_position % 4 == 0 else rng.uniform(0.35, 0.75)
        note = scale[rng.randrange(len(scale))]
        add_into(buffer, index * step, pluck(note, 0.6, accent, brightness=rng.uniform(0.3, 0.8)))
    return fade(normalize(buffer, 0.9), 0.01, 0.8)


def swells():
    seconds = 14.0
    buffer = silence(seconds)
    # (start, length, notes, peak)
    shapes = [
        (0.2, 3.2, [57, 64], 0.55),
        (3.0, 2.4, [60, 67], 0.85),
        (5.6, 4.0, [53, 60, 69], 1.0),
        (9.4, 1.6, [62, 69], 0.5),
        (10.6, 3.2, [57, 64, 72], 0.75),
    ]
    for start, length, notes, peak in shapes:
        count = int(length * SAMPLE_RATE)
        frequencies = [midi_to_hz(note) for note in notes]
        samples = []
        for index in range(count):
            t = index / SAMPLE_RATE
            # A raised-cosine swell with a gentle 5 Hz tremolo.
            shape = 0.5 - 0.5 * math.cos(TWO_PI * index / count)
            tremolo = 1.0 - 0.18 * (0.5 + 0.5 * math.sin(TWO_PI * 5.0 * t))
            value = sum(math.sin(TWO_PI * frequency * t) for frequency in frequencies) / len(frequencies)
            samples.append(peak * shape * tremolo * value)
        add_into(buffer, start, samples)
    return normalize(buffer, 0.88)


def write_caf(path, samples):
    """Writes mono 16-bit little-endian linear PCM in a Core Audio Format file."""
    frames = bytearray()
    for value in samples:
        clipped = max(-1.0, min(1.0, value))
        frames += struct.pack("<h", int(round(clipped * 32767)))
    with open(path, "wb") as file:
        # File header: 'caff', version 1, flags 0.
        file.write(b"caff" + struct.pack(">HH", 1, 0))
        # Audio description chunk: sample rate, 'lpcm', little-endian integer flags, 2 bytes per packet,
        # 1 frame per packet, 1 channel, 16 bits per channel.
        description = struct.pack(">d4sIIIII", float(SAMPLE_RATE), b"lpcm", 2, 2, 1, 1, 16)
        file.write(b"desc" + struct.pack(">q", len(description)) + description)
        # Audio data chunk: a 4-byte edit count, then the samples.
        file.write(b"data" + struct.pack(">q", len(frames) + 4) + struct.pack(">I", 0))
        file.write(frames)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    output = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "Example", "Shared", "DemoAudio")
    os.makedirs(output, exist_ok=True)
    tracks = [
        ("chord-progression.caf", chord_progression),
        ("arpeggio.caf", arpeggio),
        ("swells.caf", swells),
    ]
    for name, make in tracks:
        samples = make()
        path = os.path.join(output, name)
        write_caf(path, samples)
        print(f"Wrote {path}: {len(samples) / SAMPLE_RATE:.1f} s, {os.path.getsize(path)} bytes")


if __name__ == "__main__":
    main()
