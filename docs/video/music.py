import numpy as np, wave, sys
SR = 44100; BPM = 96; BEAT = 60 / BPM; BAR = 4 * BEAT; BARS = 19
N = int(SR * BAR * BARS) + SR
out = np.zeros(N); pad_bus = np.zeros(N)
rng = np.random.default_rng(7)

def at(t): return int(t * SR)
def add(buf, t, sig):
    i = at(t); j = min(N, i + len(sig)); buf[i:j] += sig[: j - i]
def env(dur, a=0.005, d=None):
    n = int(dur * SR); t = np.arange(n) / SR
    e = np.minimum(1, t / a) if a > 0 else np.ones(n)
    return e * (np.exp(-t / d) if d else 1)
def tone(freq, dur, harm=1, detune=0.0):
    t = np.arange(int(dur * SR)) / SR; s = np.zeros_like(t)
    for h in range(1, harm + 1):
        for dt in ([-detune, detune] if detune else [0]):
            s += np.sin(2 * np.pi * freq * h * (1 + dt) * t + rng.random() * 6.28) / h
    return s
def hp_noise(dur):
    return np.diff(rng.standard_normal(int(dur * SR) + 1))

def kick(t, g=1.0):
    d = 0.32; tt = np.arange(int(d * SR)) / SR
    f = 45 + 75 * np.exp(-tt / 0.03)
    add(out, t, g * 0.9 * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.12))
def clap(t, g=1.0): add(out, t, g * 0.18 * hp_noise(0.18) * env(0.18, 0.001, 0.05))
def hat(t, g=1.0, open_=False):
    d = 0.2 if open_ else 0.05
    add(out, t, g * 0.07 * np.diff(hp_noise(d + 1 / SR)) * env(d, 0.001, 0.06 if open_ else 0.012))

notes = {"D": 73.42, "F": 87.31, "A": 110.0, "Bb": 116.54, "C": 65.41, "E": 82.41, "G": 98.0}
chords = [("D", [146.83, 174.61, 220.0]), ("Bb", [116.54, 146.83, 174.61]), ("F", [174.61, 220.0, 261.63]), ("C", [130.81, 164.81, 196.0])]

def section(b):
    if b == 0: return "intro"
    if b == 11: return "break"
    if b in (12, 13): return "drop"
    if b >= 17: return "outro"
    if b >= 5: return "full"
    return "groove"

for b in range(BARS):
    t0 = b * BAR; root, chord = chords[b % 4]; sec = section(b)
    # pad: soft detuned chord, ducked after kicks later
    if sec != "outro" or b == 17:
        for f in chord:
            s = tone(f, BAR + 0.3, harm=5, detune=0.004) * env(BAR + 0.3, 0.25) * 0.05
            s *= np.linspace(1, 0.7, len(s))
            add(pad_bus, t0, s)
    if b == 18:
        for f in chords[0][1] + [293.66]:
            add(pad_bus, t0, tone(f, BAR + 1, harm=4, detune=0.004) * env(BAR + 1, 0.05, 1.2) * 0.06)
    if sec in ("intro", "break"):
        # riser
        d = BAR; tt = np.arange(int(d * SR)) / SR
        rise = hp_noise(d) * (tt / d) ** 2 * 0.09
        sweep = np.sin(2 * np.pi * np.cumsum(200 + 1800 * (tt / d) ** 2) / SR) * (tt / d) ** 3 * 0.05
        add(out, t0, rise + sweep)
        continue
    if sec == "outro":
        if b == 17:
            kick(t0); clap(t0 + BEAT); kick(t0 + 2 * BEAT)
        continue
    for beat in range(4):
        tb = t0 + beat * BEAT
        kick(tb, 1.0 if beat in (0, 2) else (0.8 if sec == "drop" else 0.0)) if beat in (0, 2) or sec == "drop" else None
        if beat in (1, 3): clap(tb)
        for k in range(4 if sec == "drop" else 2):
            sub = BEAT / (4 if sec == "drop" else 2)
            swing = 0.035 if k % 2 == 1 else 0
            hat(tb + k * sub + swing, 0.6 if k % 2 else 1.0, open_=(sec != "groove" and k == 2 and beat == 3))
    if sec != "groove" or b >= 3:
        kick(t0 + 2.5 * BEAT, 0.6)
    # bass
    bf = notes[root]
    for pos, dur in [(0, 1.4), (1.5, 0.45), (2.5, 0.9), (3.5, 0.45)]:
        add(out, t0 + pos * BEAT, tone(bf, dur * BEAT, harm=4) * env(dur * BEAT, 0.004, 0.35) * 0.22)
    # arp plinks
    if sec in ("full", "drop"):
        tones = [c * 2 for c in chord] + [chord[0] * 4]
        for k in range(16):
            f = tones[[0, 1, 2, 3, 2, 1, 0, 2][k % 8]]
            add(out, t0 + k * BEAT / 4, tone(f, 0.25, harm=2) * env(0.25, 0.002, 0.07) * (0.05 if sec == "full" else 0.065))
    if sec == "drop":
        for pos in (0, 1.5, 3):
            for f in chord:
                add(out, t0 + pos * BEAT, tone(f * 2, 0.3, harm=6) * env(0.3, 0.002, 0.09) * 0.05)

# sidechain pump on the pad
tt = np.arange(N) / SR
phase = (tt % BEAT) / BEAT
duck = 0.45 + 0.55 * np.minimum(1, phase / 0.45)
mix = out + pad_bus * duck
# vinyl: hiss and crackle
mix += rng.standard_normal(N) * 0.004
cr = np.zeros(N); idx = rng.integers(0, N, size=int(BARS * BAR * 9)); cr[idx] = rng.standard_normal(len(idx)) * 0.12
mix += np.convolve(cr, np.exp(-np.arange(40) / 6), mode="same")
# tape saturation, fade out
mix = np.tanh(mix * 1.6) / np.tanh(1.6)
end = int(BARS * BAR * SR); fade = int(1.5 * SR)
mix[end - fade:end] *= np.linspace(1, 0, fade); mix[end:] = 0
mix = mix[: end] / np.max(np.abs(mix[: end])) * 0.89
st = np.stack([mix, np.roll(mix, 220) * 0.96 + mix * 0.04], axis=1)
with wave.open(sys.argv[1], "w") as w:
    w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR)
    w.writeframes((st * 32767).astype(np.int16).tobytes())
print("seconds", end / SR)
