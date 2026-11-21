"""Makes the game's short sound effects (assets/audio/sfx/ui/*.wav, mono, 16 bit), synthesised from sine waves and noise, so they are the game's own (see Sfx):

    click.wav         a button is pressed: a short, soft tick
    confirm.wav       the game starts: two rising notes

Usage (from the repo root; needs numpy):
    python tools/art/generate_sfx.py
"""
import os
import wave

import numpy as np

import art_lib

OUT = os.path.join(art_lib.ROOT, "assets", "audio", "sfx", "ui")
RATE = 44100                    # samples per second


def t_axis(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def envelope(n, attack, release):
    """A fade in over `attack` seconds and out over `release` seconds."""
    env = np.ones(n)
    a, r = int(RATE * attack), int(RATE * release)
    if a:
        env[:a] = np.linspace(0.0, 1.0, a)
    if r:
        env[-r:] = np.minimum(env[-r:], np.linspace(1.0, 0.0, r))
    return env


def tone(freq, seconds, decay):
    t = t_axis(seconds)
    wave_ = np.sin(2 * np.pi * freq * t) + 0.3 * np.sin(2 * np.pi * freq * 2 * t)
    return wave_ * np.exp(-t * decay) * envelope(len(t), 0.004, 0.02)


def click():
    t = t_axis(0.07)
    sweep = np.sin(2 * np.pi * (1500 * t - 9000 * t * t))          # a quick downward chirp
    return sweep * np.exp(-t * 55) * 0.8


def confirm():
    first, second = tone(560, 0.16, 9.0), tone(840, 0.34, 6.0)
    out = np.zeros(len(first) + len(second) - int(RATE * 0.04))
    out[:len(first)] += first
    out[len(first) - int(RATE * 0.04):] += second
    return out * 0.7


def save(name, samples):
    peak = max(1e-9, float(np.max(np.abs(samples))))
    data = (samples / peak * 0.85 * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    save("click", click())
    save("confirm", confirm())
    print("done")


if __name__ == "__main__":
    main()
