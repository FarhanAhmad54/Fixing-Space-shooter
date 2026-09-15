#!/usr/bin/env python3
"""Synthesize production-grade sound effects and looping synthwave music for Starfall Vengeance.
Generates 16-bit 44.1kHz audio and uses ffmpeg to encode directly to OGG Vorbis.
"""

import os
import wave
import struct
import math
import random
import subprocess

SOUNDS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "sounds")
os.makedirs(SOUNDS_DIR, exist_ok=True)
SAMPLE_RATE = 44100

def write_wav(filename, samples):
    """Write float samples in [-1.0, 1.0] to a temporary 16-bit mono WAV file."""
    wav_path = os.path.join(SOUNDS_DIR, filename)
    with wave.open(wav_path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        data = bytearray()
        for s in samples:
            val = max(-1.0, min(1.0, s))
            data.extend(struct.pack("<h", int(val * 32767)))
        w.writeframes(data)
    return wav_path

def convert_to_ogg(wav_path, ogg_path):
    """Encode WAV to OGG Vorbis using ffmpeg."""
    cmd = [
        "ffmpeg", "-y", "-i", wav_path,
        "-c:a", "libvorbis", "-qscale:a", "5",
        ogg_path
    ]
    subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    if os.path.exists(wav_path):
        os.remove(wav_path)

def synth_laser(duration=0.14, start_freq=900, end_freq=100, wave_type="saw"):
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(num_samples):
        t = i / num_samples
        freq = start_freq * ((end_freq / start_freq) ** t)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        env = (1.0 - t) ** 1.5
        if wave_type == "saw":
            val = (2.0 * (phase / (2 * math.pi) % 1.0) - 1.0) * 0.7 + math.sin(phase) * 0.3
        else:
            val = math.sin(phase)
        samples.append(val * env * 0.8)
    return samples

def synth_hit(duration=0.08):
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(num_samples):
        t = i / num_samples
        env = (1.0 - t) ** 2.0
        noise = (random.random() * 2.0 - 1.0) * 0.5
        phase += 2 * math.pi * 220 / SAMPLE_RATE
        click = math.sin(phase) * 0.5
        samples.append((noise + click) * env * 0.85)
    return samples

def synth_explosion(duration=0.6, sub_freq=120):
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    last_noise = 0.0
    for i in range(num_samples):
        t = i / num_samples
        env = (1.0 - t) ** 1.8
        freq = max(28, sub_freq * (1.0 - t * 0.85))
        phase += 2 * math.pi * freq / SAMPLE_RATE
        # Brown noise approximation
        white = random.random() * 2.0 - 1.0
        last_noise = (last_noise + 0.08 * white) / 1.08
        sub = math.sin(phase) * 0.6
        val = (sub + last_noise * 3.5) * env * 0.95
        samples.append(max(-1.0, min(1.0, val)))
    return samples

def synth_fanfare(arpeggio=[523.25, 659.25, 783.99, 1046.50], note_dur=0.09, tail=0.35):
    samples = []
    for idx, freq in enumerate(arpeggio):
        is_last = (idx == len(arpeggio) - 1)
        dur = note_dur + (tail if is_last else 0.0)
        num = int(SAMPLE_RATE * dur)
        phase = 0.0
        for i in range(num):
            t = i / num
            env = math.exp(-3.0 * t) if is_last else (1.0 - t)
            phase += 2 * math.pi * freq / SAMPLE_RATE
            # Warm harmonics
            val = (math.sin(phase) * 0.7 + math.sin(phase * 2) * 0.25 + math.sin(phase * 3) * 0.1) * env * 0.8
            samples.append(val)
    return samples

def synth_dash(duration=0.22):
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    filtered = 0.0
    for i in range(num_samples):
        t = i / num_samples
        # Lowpass filter frequency sweep
        alpha = 0.05 + 0.35 * math.sin(t * math.pi)
        noise = random.random() * 2.0 - 1.0
        filtered += alpha * (noise - filtered)
        env = math.sin(t * math.pi)
        samples.append(filtered * env * 0.9)
    return samples

def synth_playerhit(duration=0.32):
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(num_samples):
        t = i / num_samples
        env = (1.0 - t) ** 2.2
        phase += 2 * math.pi * (160 - t * 80) / SAMPLE_RATE
        noise = (random.random() * 2.0 - 1.0) * 0.35
        val = (math.sin(phase) * 0.7 + noise) * env * 0.95
        samples.append(val)
    return samples

def synth_boss_alarm(duration=1.2):
    num_samples = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Siren wobble
        freq = 380 + 140 * math.sin(t * math.pi * 5)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        env = min(1.0, i / 2000.0) * max(0.0, 1.0 - (i / num_samples) ** 3)
        val = math.sin(phase) * env * 0.85
        samples.append(val)
    return samples

def synth_synthwave_music(bpm=124, num_bars=8):
    """Synthesize an authentic looping 8-bar 124 BPM retro synthwave track."""
    beat_dur = 60.0 / bpm
    bar_dur = beat_dur * 4
    total_dur = bar_dur * num_bars
    total_samples = int(SAMPLE_RATE * total_dur)
    mix = [0.0] * total_samples

    def add_sound(samples, start_sec, volume=1.0):
        start_idx = int(start_sec * SAMPLE_RATE)
        for i, s in enumerate(samples):
            idx = start_idx + i
            if idx < total_samples:
                mix[idx] += s * volume

    # 1. Kick Drum (Every beat)
    kick_samples = synth_laser(duration=0.12, start_freq=140, end_freq=38, wave_type="sine")
    for beat in range(num_bars * 4):
        add_sound(kick_samples, beat * beat_dur, volume=0.85)

    # 2. Snare / Clap (Beats 2 and 4 of each bar)
    snare_samples = synth_hit(duration=0.16)
    for bar in range(num_bars):
        add_sound(snare_samples, (bar * 4 + 1) * beat_dur, volume=0.6)
        add_sound(snare_samples, (bar * 4 + 3) * beat_dur, volume=0.6)

    # 3. Rolling 16th-note Synth Bass (Progression: Em, G, D, C)
    # Frequencies: E2=82.41, G2=98.00, D2=73.42, C2=65.41
    chords_bass = [82.41, 82.41, 98.00, 98.00, 73.42, 73.42, 65.41, 65.41]
    step_dur = beat_dur / 4
    for bar_idx, root_f in enumerate(chords_bass):
        bar_start = bar_idx * bar_dur
        for step in range(16):
            f = root_f if (step % 4 != 3) else root_f * 2
            note_samps = synth_laser(duration=step_dur * 0.9, start_freq=f * 1.5, end_freq=f, wave_type="saw")
            add_sound(note_samps, bar_start + step * step_dur, volume=0.45)

    # 4. Lead Arpeggio Melody
    melody_notes = [
        # Bar 1-2 (Em)
        329.63, 392.00, 493.88, 587.33, 493.88, 392.00, 329.63, 392.00,
        329.63, 392.00, 493.88, 659.25, 587.33, 493.88, 392.00, 493.88,
        # Bar 3-4 (G)
        392.00, 493.88, 587.33, 783.99, 587.33, 493.88, 392.00, 493.88,
        392.00, 493.88, 587.33, 783.99, 659.25, 587.33, 493.88, 587.33,
        # Bar 5-6 (D)
        293.66, 369.99, 440.00, 587.33, 440.00, 369.99, 293.66, 369.99,
        293.66, 369.99, 440.00, 587.33, 493.88, 440.00, 369.99, 440.00,
        # Bar 7-8 (C)
        261.63, 329.63, 392.00, 523.25, 392.00, 329.63, 261.63, 329.63,
        261.63, 329.63, 392.00, 523.25, 493.88, 392.00, 329.63, 392.00,
    ]
    arp_step = beat_dur / 2
    for n_idx, freq in enumerate(melody_notes):
        note_samps = synth_laser(duration=arp_step * 0.85, start_freq=freq, end_freq=freq * 0.98, wave_type="sine")
        add_sound(note_samps, n_idx * arp_step, volume=0.35)

    # Normalize mix to avoid clipping
    peak = max(abs(s) for s in mix) if mix else 1.0
    if peak > 0.95:
        mix = [s * (0.92 / peak) for s in mix]
    return mix

def main():
    print("Generating Starfall Vengeance production audio suite...")

    sfx = {
        "laser-1.ogg": synth_laser(0.12, 920, 110, "saw"),
        "laser-2.ogg": synth_laser(0.14, 1150, 140, "saw"),
        "laser-3.ogg": synth_laser(0.16, 750, 90, "saw"),
        "hit.ogg": synth_hit(0.08),
        "explosion.ogg": synth_explosion(0.65, 130),
        "powerup.ogg": synth_fanfare([440.0, 554.37, 659.25, 880.0], 0.08, 0.25),
        "levelup.ogg": synth_fanfare([523.25, 659.25, 783.99, 1046.50, 1318.51], 0.10, 0.40),
        "dash.ogg": synth_dash(0.20),
        "playerhit.ogg": synth_playerhit(0.35),
        "boss.ogg": synth_boss_alarm(1.2),
        "music.ogg": synth_synthwave_music(124, 8),
    }

    for filename, samples in sfx.items():
        wav_name = filename.replace(".ogg", ".wav")
        wav_path = write_wav(wav_name, samples)
        ogg_path = os.path.join(SOUNDS_DIR, filename)
        convert_to_ogg(wav_path, ogg_path)
        print(f"  [+] {filename} ({len(samples)} samples)")

    print(f"Successfully generated {len(sfx)} audio tracks in {SOUNDS_DIR}")

if __name__ == "__main__":
    main()
