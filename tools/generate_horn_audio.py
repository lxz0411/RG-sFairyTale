"""Render the two original, mellow horn cues used by level one (NumPy)."""
from pathlib import Path
import wave

import numpy as np


RATE = 44100
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "level1"


def render(name: str, frequency: float, duration: float) -> None:
    t = np.arange(round(duration * RATE)) / RATE
    attack = np.clip(t / 0.09, 0, 1)
    release = np.clip((duration - t) / 0.28, 0, 1)
    envelope = np.sin(attack * np.pi / 2) ** 2
    envelope *= np.sin(release * np.pi / 2) ** 2
    envelope *= 0.8 + 0.2 * np.exp(-t * 4)
    # A rounded onset and low harmonics avoid the old buzzer-like edge.
    cents = -9 * np.exp(-t / 0.045) + 2.2 * np.sin(2 * np.pi * 4.7 * t)
    phase = 2 * np.pi * np.cumsum(frequency * 2 ** (cents / 1200)) / RATE
    tone = np.zeros_like(t)
    for harmonic, gain in enumerate([1, 0.28, 0.12, 0.045, 0.018, 0.006], 1):
        tone += gain * np.sin(harmonic * phase) * (0.8 + 0.2 * attack ** harmonic)
    rng = np.random.default_rng(42)
    breath = np.convolve(rng.normal(0, 1, len(t)), np.ones(45) / 45, mode="same")
    dry = (tone + breath * 0.012) * envelope
    # Quiet, staggered room reflections; leave time for the tail to fade.
    stereo = np.zeros((len(t) + round(RATE * 0.25), 2))
    stereo[:len(t), :] = dry[:, None]
    for channel in range(2):
        for delay, gain in [(0.041, 0.10), (0.079, 0.055), (0.137, 0.025)]:
            offset = round((delay + channel * 0.006) * RATE)
            stereo[offset:offset + len(t), channel] += dry * gain
    stereo *= 0.42 / np.max(np.abs(stereo))
    with wave.open(str(OUTPUT / name), "wb") as audio:
        audio.setparams((2, 2, RATE, 0, "NONE", "not compressed"))
        audio.writeframes(np.round(stereo * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    render("horn_blow.wav", 261.6256, 0.82)
    render("horn_low.wav", 196.0, 1.05)
