"""Generates Masebha's tap sound: a soft, short "bead" tick in the spirit of iOS UI sounds.

Usage: python scripts/sound/make_tap_sound.py <output.wav>

The sound is synthesized (no samples), so it can be re-tuned by editing the constants below:
- a very short, filtered noise transient gives the crisp "tick";
- two damped sine partials give a warm wooden body;
- the peak is kept well below full scale so rapid tapping never feels harsh.
"""
import math
import random
import struct
import sys
import wave

RATE = 44100
DURATION_S = 0.045
PEAK = 0.42  # about -7.5 dBFS

TRANSIENT_HZ = 3600.0   # centre of the band-passed click
TRANSIENT_TAU = 0.0012  # seconds
BODY = [                 # (frequency Hz, decay tau s, relative amplitude)
    (1850.0, 0.0060, 1.00),
    (920.0, 0.0090, 0.45),
]


def bandpass(samples, centre_hz, q):
    """RBJ biquad band-pass (constant 0 dB peak gain)."""
    w0 = 2 * math.pi * centre_hz / RATE
    alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for x in samples:
        y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        out.append(y)
        x2, x1, y2, y1 = x1, x, y1, y
    return out


def main(path):
    random.seed(7)  # deterministic output
    n = int(RATE * DURATION_S)
    noise = [random.uniform(-1, 1) * math.exp(-(i / RATE) / TRANSIENT_TAU) for i in range(n)]
    click = bandpass(noise, TRANSIENT_HZ, q=1.2)

    signal = []
    for i in range(n):
        t = i / RATE
        body = sum(a * math.exp(-t / tau) * math.sin(2 * math.pi * f * t) for f, tau, a in BODY)
        signal.append(0.55 * body + 1.0 * click[i])

    fade_in = int(0.0003 * RATE)
    fade_out = int(0.008 * RATE)
    for i in range(fade_in):
        signal[i] *= i / fade_in
    for i in range(fade_out):
        signal[n - 1 - i] *= i / fade_out

    peak = max(abs(s) for s in signal) or 1.0
    frames = b"".join(struct.pack("<h", int(round(s / peak * PEAK * 32767))) for s in signal)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(frames)


if __name__ == "__main__":
    main(sys.argv[1])
