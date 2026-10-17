#!/usr/bin/env python3
"""Makes every Zoya7 sound: the lobby music, each game's music and effects, and the shared UI sounds.

Everything is synthesised here (no samples), so all of it is original and can be remade or tuned:

    python3 tools/sounds/make_sounds.py          # needs numpy, scipy and ffmpeg

Effects are written as MP3. Each music loop is written twice: OGG, exactly one loop long (Android
loops it as is), and MP3 with a 1 s wrap-around pad at each end (the web plays the middle,
`Track.loop` seconds from 1 s in, so the MP3 encoder's start delay can't put a gap in the loop).
"""

import os
import re
import subprocess
import tempfile
import wave
from functools import lru_cache

import numpy as np
from scipy import signal as sg

SR = 44100
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..', '..'))
rng = np.random.default_rng(7)


# ── Basics ───────────────────────────────────────────────────────────────────

def ns(d):
    return max(1, int(round(d * SR)))


def tt(d):
    return np.arange(ns(d)) / SR


_NOTE = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5, 'F#': 6, 'Gb': 6,
         'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10, 'B': 11}


def midi(name):
    p, o = re.fullmatch(r'([A-G][b#]?)(-?\d)', name).groups()
    return 12 * (int(o) + 1) + _NOTE[p]


def hz(note):
    m = midi(note) if isinstance(note, str) else note
    return 440.0 * 2 ** ((m - 69) / 12)


def noise(d):
    return rng.standard_normal(ns(d))


def _sos(kind, f, order=2):
    return sg.butter(order, f, kind, fs=SR, output='sos')


def lowpass(x, f, order=2):
    return sg.sosfilt(_sos('lowpass', min(f, SR / 2 - 100), order), x)


def highpass(x, f, order=2):
    return sg.sosfilt(_sos('highpass', f, order), x)


def bandpass(x, lo, hi, order=2):
    return sg.sosfilt(_sos('bandpass', [lo, min(hi, SR / 2 - 100)], order), x)


def sweep_filter(x, f0, f1, kind='bandpass', width=1.0, block=256):
    """A filter whose centre slides from f0 to f1 (exponentially) over the sound."""
    y = np.zeros_like(x)
    n = len(x)
    zi = None
    for i in range(0, n, block):
        f = f0 * (f1 / f0) ** (i / n)
        if kind == 'bandpass':
            b, a = sg.butter(2, [f / (1 + width / 2), min(f * (1 + width / 2), SR / 2 - 100)], 'bandpass', fs=SR)
        else:
            b, a = sg.butter(2, min(f, SR / 2 - 100), kind, fs=SR)
        if zi is None:
            zi = np.zeros(max(len(a), len(b)) - 1)
        y[i:i + block], zi = sg.lfilter(b, a, x[i:i + block], zi=zi)
    return y


def env(total, attack=.005, tau=1.0, gate=None, release=.08, sustain=0.0):
    """Attack, exponential decay towards [sustain]; released at [gate]."""
    t = tt(total)
    e = np.where(t < attack, t / attack, sustain + (1 - sustain) * np.exp(-(t - attack) / tau))
    if gate is not None and gate < total:
        g = ns(gate)
        e[g:] = e[g - 1] * np.exp(-(t[g:] - gate) / max(release / 5, 1e-4))
    return e


def place(buf, at, sig, gain=1.0):
    """Adds [sig] into [buf] starting at sample [at] (clipped to the buffer)."""
    if at >= len(buf):
        return
    end = min(len(buf), at + len(sig))
    buf[at:end] += sig[:end - at] * gain


def mix(*parts):
    n = max(ns(at) + len(p) for at, p in parts)
    out = np.zeros(n)
    for at, p in parts:
        place(out, ns(at), p)
    return out


def reverb_ir(rt=1.6, bright=7000, dark=2500, predelay=.012):
    t = tt(rt * 1.3)
    ir = (lowpass(rng.standard_normal(len(t)), bright) * np.exp(-6.9 * t / (rt * .45))
          + lowpass(rng.standard_normal(len(t)), dark) * np.exp(-6.9 * t / rt))
    ir[:ns(predelay)] = 0
    for d, g in ((.007, .5), (.013, .35), (.021, .3), (.029, .2)):  # early reflections
        ir[ns(predelay + d)] += g * 8
    return ir / np.sqrt(np.sum(ir ** 2))


def reverb(x, wet=.2, **kw):
    w = sg.fftconvolve(x, reverb_ir(**kw))[:len(x)]
    return x * (1 - wet) + w * wet * 1.4


def finish(x, peak):
    """Soft-limits and scales so the loudest moment is at [peak] (0–1)."""
    x = x - np.mean(x)
    x = np.tanh(1.2 * x / (np.max(np.abs(x)) + 1e-9)) / np.tanh(1.2)
    fade = min(len(x), ns(.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * peak


# ── Instruments ──────────────────────────────────────────────────────────────

@lru_cache(maxsize=None)
def ep(f, dur, vel=.8, tine=1.0):
    """Electric piano (FM, with a bell-like tine on the attack)."""
    total = dur + .3
    t = tt(total)
    idx = (1.0 + 2.2 * vel) * np.exp(-t / .3) + .2
    y = np.sin(2 * np.pi * f * t + idx * np.sin(2 * np.pi * f * t))
    y += tine * .22 * vel * np.sin(2 * np.pi * f * 7 * t) * np.exp(-t / .04)
    return y * env(total, .003, 1.5, gate=dur, release=.25) * vel


@lru_cache(maxsize=None)
def vibes(f, dur=1.6, vel=.8):
    t = tt(dur)
    y = (np.sin(2 * np.pi * f * t) + .3 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / .12)
         + .08 * np.sin(2 * np.pi * f * 10 * t) * np.exp(-t / .025))
    trem = 1 - .22 * (1 - np.cos(2 * np.pi * 5.2 * t)) / 2
    return y * trem * env(dur, .002, .8) * vel


@lru_cache(maxsize=None)
def bell(f, dur=1.8, vel=.8, ratio=3.5, index=2.4, tau=1.0):
    t = tt(dur)
    y = np.sin(2 * np.pi * f * t + index * np.exp(-t / (tau * .5)) * np.sin(2 * np.pi * f * ratio * t))
    return y * env(dur, .002, tau) * vel


@lru_cache(maxsize=None)
def marimba(f, dur=.8, vel=.8):
    t = tt(dur)
    y = (np.sin(2 * np.pi * f * t) * np.exp(-t / .3) + .45 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t / .06)
         + .15 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t / .02))
    return y * np.minimum(1, t / .002) * vel


@lru_cache(maxsize=None)
def steel(f, dur=1.0, vel=.8):
    t = tt(dur)
    parts = ((1, 1, .55), (2, .75, .32), (3.01, .3, .18), (4.03, .18, .1), (1.5, .07, .12))
    y = sum(a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / tau) for r, a, tau in parts)
    return y * np.minimum(1, t / .003) * vel


@lru_cache(maxsize=None)
def pluck(f, dur=1.2, vel=.8, bright=.9, tau=.9, bend=0.0):
    """Plucked string (harp, guzheng, koto): harmonics that die away, the high ones first."""
    t = tt(dur)
    fr = f * (1 + bend * np.exp(-t / .07))
    ph = 2 * np.pi * np.cumsum(fr) / SR
    y = np.zeros_like(t)
    k = 1
    while f * k < 9000 and k <= 24:
        a = bright ** (k - 1) / k * (abs(np.sin(np.pi * k * .18)) + .05)
        y += a * np.sin(k * ph) * np.exp(-t * (1 + .5 * k) / tau)
        k += 1
    return y * np.minimum(1, t / .0015) * vel


@lru_cache(maxsize=None)
def organ(f, dur, vel=.6):
    total = dur + .06
    t = tt(total)
    y = sum(a * np.sin(2 * np.pi * f * h * t) for h, a in ((1, 1), (2, .8), (3, .55), (4, .3), (6, .18), (8, .12)))
    y *= 1 + .1 * np.sin(2 * np.pi * 6.4 * t)
    y += .3 * np.sin(2 * np.pi * f * 12 * t) * np.exp(-t / .01)  # key click
    return y * env(total, .004, 99, gate=dur, release=.06, sustain=1) * vel / 3


@lru_cache(maxsize=None)
def brass(f, dur, vel=.8):
    total = dur + .15
    t = tt(total)
    vib = 1 + .005 * np.sin(2 * np.pi * 5.5 * t) * np.clip((t - .15) / .3, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    y = sum(sg.sawtooth(ph * (1 + d) + o) for d, o in ((-.004, 0), (.004, 1.3), (0, 2.1)))
    cut = 900 + 3800 * vel * np.exp(-t / .3) * np.minimum(1, t / .04)
    y = _tv_lowpass(y, cut)
    return y * env(total, .025, 99, gate=dur, release=.12, sustain=1) * vel * .35


def _tv_lowpass(x, cut, block=128):
    y = np.zeros_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), block):
        b, a = sg.butter(2, min(cut[i], SR / 2 - 200), 'lowpass', fs=SR)
        y[i:i + block], zi = sg.lfilter(b, a, x[i:i + block], zi=zi)
    return y


@lru_cache(maxsize=None)
def strings(f, dur, vel=.5, attack=.35, release=.8, cutoff=2600):
    total = dur + release
    t = tt(total)
    vib = 1 + .003 * np.sin(2 * np.pi * 5 * t + f)
    y = np.zeros_like(t)
    for d in (-.005, 0, .006):
        y += sg.sawtooth(2 * np.pi * np.cumsum(f * (1 + d) * vib) / SR + rng.uniform(0, 6.28))
    y = lowpass(y, cutoff)
    return y * env(total, attack, 99, gate=dur, release=release, sustain=1) * vel / 3


@lru_cache(maxsize=None)
def flute(f, dur, vel=.6, bend=0.0):
    total = dur + .15
    t = tt(total)
    vib = 1 + .007 * np.sin(2 * np.pi * 5 * t) * np.clip((t - .25) / .3, 0, 1)
    fr = f * vib * (1 - bend * np.exp(-t / .06))  # scoops up into the note
    ph = 2 * np.pi * np.cumsum(fr) / SR
    y = np.sin(ph) + .16 * np.sin(2 * ph) + .05 * np.sin(3 * ph)
    y += bandpass(noise(total), f * .9, f * 3.5) * .1
    return y * env(total, .06, 99, gate=dur, release=.14, sustain=1) * vel


@lru_cache(maxsize=None)
def upright(f, dur, vel=.8):
    total = dur + .08
    t = tt(total)
    y = (np.sin(2 * np.pi * f * t) + .4 * np.sin(4 * np.pi * f * t) * np.exp(-t / .15)
         + .15 * np.sin(6 * np.pi * f * t) * np.exp(-t / .05))
    y = np.tanh(1.4 * y) + lowpass(noise(total), 400) * np.exp(-t / .015) * .4
    return y * env(total, .005, .8, gate=dur, release=.06) * vel


@lru_cache(maxsize=None)
def synbass(f, dur, vel=.8):
    total = dur + .05
    t = tt(total)
    y = np.tanh(2 * (np.sin(2 * np.pi * f * t) + .3 * sg.sawtooth(2 * np.pi * f * t)))
    y = lowpass(y, 900)
    return y * env(total, .004, .35, gate=dur, release=.05, sustain=.55) * vel


# ── Percussion ───────────────────────────────────────────────────────────────

@lru_cache(maxsize=None)
def kick(vel=1.0, d=.4):
    t = tt(d)
    ph = 2 * np.pi * np.cumsum(46 + 90 * np.exp(-t / .03)) / SR
    y = np.sin(ph) * np.exp(-t / .17) + highpass(noise(d), 2000) * np.exp(-t / .003) * .25
    return y * vel


@lru_cache(maxsize=None)
def snare(vel=1.0):
    d = .25
    t = tt(d)
    y = np.sin(2 * np.pi * 185 * t) * np.exp(-t / .05) * .55 + bandpass(noise(d), 1200, 9000) * np.exp(-t / .07)
    return y * vel


@lru_cache(maxsize=None)
def rim(vel=1.0):
    d = .08
    t = tt(d)
    y = (bandpass(noise(d), 1400, 2600) * np.exp(-t / .006) + np.sin(2 * np.pi * 1700 * t) * np.exp(-t / .012) * .5
         + np.sin(2 * np.pi * 430 * t) * np.exp(-t / .02) * .4)
    return y * vel


@lru_cache(maxsize=None)
def hat(vel=1.0, open_=False):
    d = .35 if open_ else .06
    t = tt(d)
    return highpass(noise(d), 7000, 4) * np.exp(-t / (.11 if open_ else .016)) * vel


@lru_cache(maxsize=None)
def shaker(vel=1.0):
    d = .1
    t = tt(d)
    return bandpass(noise(d), 4000, 10000) * np.minimum(1, t / .012) * np.exp(-t / .03) * vel


@lru_cache(maxsize=None)
def ride(vel=1.0):
    d = 1.3
    t = tt(d)
    y = highpass(noise(d), 5000, 4) * np.exp(-t / .3) * .5
    y += sum(np.sin(2 * np.pi * f * t + rng.uniform(0, 6)) for f in (3150, 4230, 5390, 6950)) * np.exp(-t / .55) * .06
    y += np.sin(2 * np.pi * 2650 * t) * np.exp(-t / .2) * .15
    return y * vel


@lru_cache(maxsize=None)
def brush(vel=1.0, d=.28):
    t = tt(d)
    e = np.minimum(1, t / .05) * np.exp(-np.maximum(0, t - .05) / .08)
    return bandpass(noise(d), 1800, 7500) * e * vel


@lru_cache(maxsize=None)
def clave(vel=1.0):
    d = .1
    t = tt(d)
    return (np.sin(2 * np.pi * 2500 * t) * np.exp(-t / .025) + .3 * np.sin(2 * np.pi * 5100 * t) * np.exp(-t / .01)) * vel


@lru_cache(maxsize=None)
def conga(f=210, vel=1.0, slap=False):
    d = .35
    t = tt(d)
    fr = f * (1 + .3 * np.exp(-t / .01))
    y = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / (.07 if slap else .17))
    y += bandpass(noise(d), 900, 5000) * np.exp(-t / (.012 if slap else .005)) * (.9 if slap else .35)
    return y * vel


@lru_cache(maxsize=None)
def taiko(vel=1.0, f=60, d=1.1):
    t = tt(d)
    fr = f * (1 + .55 * np.exp(-t / .02))
    y = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / .38)
    y += lowpass(noise(d), 500) * np.exp(-t / .07) * .7 + bandpass(noise(d), 1500, 5000) * np.exp(-t / .004) * .3
    return np.tanh(1.5 * y) * vel


@lru_cache(maxsize=None)
def gong(f=98, d=4.5, vel=1.0):
    t = tt(d)
    y = np.zeros_like(t)
    for r, a, tau in ((1, 1, 3.2), (1.52, .6, 2.6), (2.04, .5, 2.2), (2.66, .35, 1.8), (3.15, .3, 1.5),
                      (3.85, .22, 1.2), (4.6, .16, 1.0), (5.3, .12, .8)):
        for det in (0, .0035):
            y += a * np.sin(2 * np.pi * f * r * (1 + det) * t + rng.uniform(0, 6)) * np.exp(-t / tau)
    bloom = np.minimum(1, t / .25)
    y += highpass(noise(d), 3000) * np.exp(-t / .9) * bloom * .25
    return y * np.minimum(1, t / .004) * vel / 4


@lru_cache(maxsize=None)
def crash(vel=1.0, d=2.6):
    t = tt(d)
    y = highpass(noise(d), 3500, 4) * np.exp(-t / .75)
    y += sum(np.sin(2 * np.pi * f * t) for f in (3800, 5150, 6400, 7920)) * np.exp(-t / .9) * .04
    return y * vel


def swell(d=1.2):
    """Reverse cymbal: rises into the next hit."""
    t = tt(d)
    return highpass(noise(d), 4000, 4) * (t / d) ** 2.5


@lru_cache(maxsize=None)
def coin(seed, vel=1.0):
    r = np.random.default_rng(seed)
    f = r.uniform(2400, 4300)
    d = .45
    t = tt(d)
    y = sum(a * np.sin(2 * np.pi * f * k * t + r.uniform(0, 6)) * np.exp(-t / tau)
            for k, a, tau in ((1, 1, .22), (2.71, .55, .11), (5.12, .3, .05), (8.3, .18, .025)))
    y += highpass(noise(d), 6000) * np.exp(-t / .002) * .4
    return y * vel


def coin_shower(d, density=24, seed=1, decay=1.0):
    """Coins pouring for [d] seconds, thinning out."""
    r = np.random.default_rng(seed)
    out = np.zeros(ns(d + .5))
    count = int(density * d)
    for i in range(count):
        at = (r.random() ** (1.3 * decay)) * d
        place(out, ns(at), coin(int(r.integers(0, 60))), r.uniform(.25, .7) * (1 - .6 * at / d))
    return out


def whoosh(d, f0, f1, width=1.2, shape=1.0):
    t = tt(d)
    e = np.sin(np.pi * np.clip(t / d, 0, 1)) ** shape
    return sweep_filter(noise(d), f0, f1, width=width) * e


# ── Music ────────────────────────────────────────────────────────────────────

class Song:
    """A loop of [bars] 4/4 bars at [bpm]. Rendered twice over and the second pass kept, so
    note and reverb tails from the end of the loop ring on at its start."""

    def __init__(self, bpm, bars):
        self.beat = 60 / bpm
        self.loop = ns(bars * 4 * self.beat)
        self.buses = {}

    def at(self, bar, beat):
        return ns((bar * 4 + beat) * self.beat)

    def add(self, bar, beat, sig, gain=1.0, bus='main'):
        self.buses.setdefault(bus, []).append((self.at(bar, beat), sig, gain))

    def render(self, fx):
        """[fx]: bus name → function applied to that bus (e.g. reverb)."""
        total = 2 * self.loop + ns(6)
        out = np.zeros(total)
        for name, events in self.buses.items():
            buf = np.zeros(total)
            for at, sig, gain in events:
                place(buf, at, sig, gain)
                place(buf, at + self.loop, sig, gain)
            out += fx.get(name, lambda x: x)(buf)
        return out[self.loop:2 * self.loop]


def walk(root, nxt, third=3, beats=4):
    """A walking-bass bar: root, third, fifth, then a half step into the next root."""
    approach = nxt - 1 if (nxt - root) % 12 > 6 or nxt == root else nxt + 1
    line = [root, root + third, root + 7, approach]
    return line[:beats] if beats == 4 else [root, approach]


def song_lobby():
    """Gold Lounge: a smooth neo-soul groove in F, the Zoya7 lobby."""
    s = Song(100, 16)
    prog = ['Fmaj9', 'Dm9', 'Gm9', 'C13'] * 2 + ['Bbmaj9', 'Am7', 'Gm9', 'C13'] * 2
    voicing = {
        'Fmaj9': ['A3', 'C4', 'E4', 'G4'], 'Dm9': ['F3', 'A3', 'C4', 'E4'], 'Gm9': ['Bb3', 'D4', 'F4', 'A4'],
        'C13': ['Bb3', 'D4', 'E4', 'A4'], 'Bbmaj9': ['A3', 'C4', 'D4', 'F4'], 'Am7': ['G3', 'C4', 'E4', 'A4'],
    }
    root = {'Fmaj9': 'F2', 'Dm9': 'D2', 'Gm9': 'G2', 'C13': 'C2', 'Bbmaj9': 'Bb1', 'Am7': 'A1'}
    comp = [[(0, 1.4, .75), (1.75, .5, .5), (2.5, 1.3, .65)], [(0, 1.9, .7), (2.5, .4, .45), (3.25, .7, .55)]]
    for bar, ch in enumerate(prog):
        for beat, dur, vel in comp[bar % 2]:
            for i, n in enumerate(voicing[ch]):
                s.add(bar, beat + i * .012, ep(hz(n), dur * s.beat, vel * .9), .32, 'keys')
        for n in voicing[ch]:
            s.add(bar, 0, strings(hz(n) * 2, 4 * s.beat - .1, .5, attack=.8, release=1.2, cutoff=1800), .05, 'pad')
        r = midi(root[ch])
        nxt = midi(root[prog[(bar + 1) % 16]])
        for beat, m, dur, vel in ((0, r, .9, .9), (1.5, r + 12, .35, .55), (2, r + 7, .9, .75),
                                  (3.5, nxt + (1 if (nxt - r) % 12 > 6 else -1), .4, .6)):
            s.add(bar, beat, synbass(hz(m), dur * s.beat, vel), .55, 'bass')
        # Drums: kick, rim on 2 and 4, eighth hats, sixteenth shaker
        for beat in (0, 1.75, 2.5):
            s.add(bar, beat, kick(.9), .55, 'drums')
        for beat in (1, 3):
            s.add(bar, beat, rim(.8), .22, 'drums')
        for i in range(8):
            s.add(bar, i * .5, hat(.6 + (.25 if i % 2 else 0)), .1, 'drums')
        for i in range(16):
            s.add(bar, i * .25, shaker(1 if i % 4 == 2 else .55), .05, 'drums')
        if bar % 2 == 1:
            s.add(bar, 3.5, hat(.7, True), .08, 'drums')
        if bar % 4 == 0:
            s.add(bar, 0, bell(hz('C7'), 2.5, .5, ratio=2.0, index=1.2, tau=1.2), .05, 'lead')
    melody = [
        (4, 0, 'C5', 1), (4, 1, 'A4', .5), (4, 1.5, 'C5', .5), (4, 2, 'D5', 1.5), (5, 0, 'C5', .5), (5, .5, 'A4', .5),
        (5, 1, 'F4', 2), (6, 0, 'G4', .5), (6, .5, 'A4', .5), (6, 1, 'Bb4', .5), (6, 1.5, 'D5', 1), (6, 2.5, 'C5', 1.5),
        (7, 0, 'E5', 1), (7, 1, 'D5', .5), (7, 1.5, 'C5', 2),
        (12, 0, 'F5', 1), (12, 1, 'E5', .5), (12, 1.5, 'D5', .5), (12, 2, 'C5', 1.5), (13, 0, 'E5', .5), (13, .5, 'C5', .5),
        (13, 1, 'A4', 2), (14, 0, 'Bb4', .5), (14, .5, 'D5', .5), (14, 1, 'F5', 1), (14, 2, 'E5', .5), (14, 2.5, 'D5', 1),
        (15, 0, 'C5', .5), (15, .5, 'Bb4', .5), (15, 1, 'G4', .5), (15, 1.5, 'E4', 2),
    ]
    for bar, beat, n, dur in melody:
        s.add(bar, beat, vibes(hz(n), max(1.2, dur * s.beat * 1.6), .8), .26, 'lead')
    return s.render({
        'keys': lambda x: reverb(x, .25, rt=1.8),
        'pad': lambda x: reverb(x, .4, rt=2.5),
        'lead': lambda x: reverb(x, .35, rt=2.2),
        'drums': lambda x: reverb(x, .1, rt=.9),
    }), s.loop


def song_classic():
    """Vegas Nights: a swinging lounge tune in C for Classic 777 (organ, walking bass, vibes, brass)."""
    s = Song(128, 16)
    prog = ['C6', 'A7', 'Dm7', 'G7', 'C6', 'A7', 'Dm7', 'G7', 'F6', 'F#dim7', 'C6', 'A7', 'Dm7', 'G7', 'C6', 'G7']
    voicing = {'C6': ['E3', 'G3', 'A3', 'C4'], 'A7': ['E3', 'G3', 'C#4'], 'Dm7': ['F3', 'A3', 'C4'],
               'G7': ['F3', 'B3', 'D4'], 'F6': ['F3', 'A3', 'D4'], 'F#dim7': ['F#3', 'A3', 'C4', 'D#4']}
    root = {'C6': 'C2', 'A7': 'A1', 'Dm7': 'D2', 'G7': 'G1', 'F6': 'F2', 'F#dim7': 'F#2'}
    third = {'C6': 4, 'A7': 4, 'Dm7': 3, 'G7': 4, 'F6': 4, 'F#dim7': 3}
    sw = 2 / 3  # swung eighth
    for bar, ch in enumerate(prog):
        for beat in (1, 3):
            for n in voicing[ch]:
                s.add(bar, beat, organ(hz(n), .35 * s.beat, .7), .5, 'keys')
        if bar % 2 == 1:
            for n in voicing[ch]:
                s.add(bar, 2 + sw, organ(hz(n), .3 * s.beat, .6), .35, 'keys')
        r = midi(root[ch])
        nxt = midi(root[prog[(bar + 1) % 16]])
        for i, m in enumerate(walk(r, nxt, third[ch])):
            s.add(bar, i, upright(hz(m), .85 * s.beat, .85 if i % 2 == 0 else .7), .7, 'bass')
        for beat in (0, 1, 1 + sw, 2, 3, 3 + sw):
            s.add(bar, beat, ride(.55 if beat % 1 else .8), .12, 'drums')
        for beat in (1, 3):
            s.add(bar, beat, hat(.7), .12, 'drums')
        for beat in range(4):
            s.add(bar, beat, kick(.5), .25, 'drums')
        if bar % 4 == 3:
            s.add(bar, 3 + sw, snare(.6), .18, 'drums')
        if bar >= 8:
            for n in voicing[ch]:
                s.add(bar, 0, brass(hz(n) * 2, .45 * s.beat, .6), .1, 'brass')
                s.add(bar, 2 + sw, brass(hz(n) * 2, 1.1 * s.beat, .55), .09, 'brass')
    melody = [
        (0, 0, 'E5', sw), (0, sw, 'G5', 1 - sw), (0, 1, 'A5', 1), (0, 2, 'G5', 1), (0, 3, 'E5', 1),
        (1, 0, 'C#5', sw), (1, sw, 'E5', 1 - sw), (1, 1, 'G5', 2), (1, 3, 'E5', 1),
        (2, 0, 'F5', sw), (2, sw, 'A5', 1 - sw), (2, 1, 'C6', 1.5), (2, 2 + sw, 'A5', 1 - sw), (2, 3, 'F5', 1),
        (3, 0, 'D5', sw), (3, sw, 'F5', 1 - sw), (3, 1, 'B4', 1), (3, 2, 'G4', 2),
        (4, 0, 'E5', sw), (4, sw, 'G5', 1 - sw), (4, 1, 'A5', 1), (4, 2, 'G5', 1), (4, 3, 'E5', 1),
        (5, 0, 'C#5', sw), (5, sw, 'E5', 1 - sw), (5, 1, 'G5', 2), (5, 3, 'E5', 1),
        (6, 0, 'F5', sw), (6, sw, 'A5', 1 - sw), (6, 1, 'C6', 1.5), (6, 2 + sw, 'A5', 1 - sw), (6, 3, 'F5', 1),
        (7, 0, 'B4', sw), (7, sw, 'D5', 1 - sw), (7, 1, 'F5', sw), (7, 1 + sw, 'E5', 1 - sw), (7, 2, 'D5', 2),
        (8, 0, 'A5', 1), (8, 1, 'G5', sw), (8, 1 + sw, 'F5', 1 - sw), (8, 2, 'A5', 2),
        (9, 0, 'A5', 1), (9, 1, 'C6', 2), (10, 0, 'G5', 1), (10, 1, 'E5', sw), (10, 1 + sw, 'C5', 1 - sw), (10, 2, 'E5', 2),
        (11, 0, 'C#5', sw), (11, sw, 'E5', 1 - sw), (11, 1, 'G5', 1), (11, 2, 'A5', 2),
        (12, 0, 'F5', 1), (12, 1, 'A5', 1), (12, 2, 'D6', 2), (13, 0, 'B5', 1), (13, 1, 'G5', 1), (13, 2, 'F5', 1),
        (13, 3, 'D5', 1), (14, 0, 'C5', 1), (14, 1, 'E5', sw), (14, 1 + sw, 'G5', 1 - sw), (14, 2, 'C6', 2),
        (15, 0, 'B5', sw), (15, sw, 'A5', 1 - sw), (15, 1, 'G5', 1), (15, 2, 'F5', sw), (15, 2 + sw, 'D5', 1.3),
    ]
    for bar, beat, n, dur in melody:
        s.add(bar, beat, vibes(hz(n), max(1.0, dur * s.beat * 1.8), .85), .28, 'lead')
    return s.render({
        'keys': lambda x: reverb(x, .2, rt=1.4),
        'lead': lambda x: reverb(x, .3, rt=1.8),
        'brass': lambda x: reverb(x, .3, rt=1.6),
        'drums': lambda x: reverb(x, .12, rt=1.0),
        'bass': lambda x: reverb(x, .05, rt=.8),
    }), s.loop


def song_fruit():
    """Island Spin: a sunny calypso in G for Fruit Spin (steel drum, marimba, congas, shaker)."""
    s = Song(112, 16)
    prog = ['G', 'C', 'D7', 'G', 'G', 'C', 'D7', 'G', 'Em', 'C', 'D', 'G', 'Em', 'Am7|D7', 'G', 'D7']
    tones = {'G': ['G', 'B', 'D'], 'C': ['C', 'E', 'G'], 'D7': ['D', 'F#', 'C'], 'D': ['D', 'F#', 'A'],
             'Em': ['E', 'G', 'B'], 'Am7': ['A', 'C', 'E']}
    root = {'G': 'G2', 'C': 'C2', 'D7': 'D2', 'D': 'D2', 'Em': 'E2', 'Am7': 'A2'}
    for bar, spec in enumerate(prog):
        halves = spec.split('|')
        for hi, ch in enumerate(halves):
            span = 4 / len(halves)
            start = hi * span
            # marimba arpeggio in eighths
            notes = [f'{tones[ch][0]}4', f'{tones[ch][1]}4', f'{tones[ch][2]}4', f'{tones[ch][1]}4']
            for i in range(int(span * 2)):
                s.add(bar, start + i * .5, marimba(hz(notes[i % 4]), .6, .7 if i % 2 == 0 else .5), .22, 'keys')
            r = midi(root[ch])
            pattern = ((0, r, .7, .9), (1.5, r + 7, .45, .7), (2, r, .45, .75), (3, r + 12, .45, .65), (3.5, r + 7, .4, .6))
            for beat, m, dur, vel in pattern:
                if beat < span:
                    s.add(bar, start + beat, synbass(hz(m), dur * s.beat, vel), .5, 'bass')
        for beat in (0, 2):
            s.add(bar, beat, kick(.8), .45, 'drums')
        for beat in ((0, 1.5, 3) if bar % 2 == 0 else (1, 2)):  # 3-2 son clave
            s.add(bar, beat, clave(.8), .12, 'drums')
        for i in range(16):
            s.add(bar, i * .25, shaker(1 if i % 2 else .5), .07, 'drums')
        for beat, f, slap in ((1.5, 300, True), (2.5, 220, False), (3, 210, False), (3.5, 300, False)):
            s.add(bar, beat, conga(f, .8, slap), .2, 'drums')
    melody = [
        (0, 0, 'B4', .5), (0, .5, 'D5', .5), (0, 1, 'G5', .75), (0, 1.75, 'E5', .75), (0, 2.5, 'D5', 1.5),
        (1, 0, 'E5', .5), (1, .5, 'G5', .5), (1, 1, 'C6', .75), (1, 1.75, 'B5', .75), (1, 2.5, 'G5', 1.5),
        (2, 0, 'A5', .5), (2, .5, 'F#5', .5), (2, 1, 'D5', .75), (2, 1.75, 'E5', .75), (2, 2.5, 'F#5', 1.5),
        (3, 0, 'G5', 1.5), (3, 1.5, 'D5', .5), (3, 2, 'B4', 2),
        (4, 0, 'B4', .5), (4, .5, 'D5', .5), (4, 1, 'G5', .75), (4, 1.75, 'E5', .75), (4, 2.5, 'D5', 1.5),
        (5, 0, 'E5', .5), (5, .5, 'G5', .5), (5, 1, 'C6', .75), (5, 1.75, 'B5', .75), (5, 2.5, 'G5', 1.5),
        (6, 0, 'A5', .5), (6, .5, 'F#5', .5), (6, 1, 'D5', .75), (6, 1.75, 'E5', .75), (6, 2.5, 'F#5', 1.5),
        (7, 0, 'G5', .5), (7, .5, 'A5', .5), (7, 1, 'B5', 1), (7, 2, 'G5', 2),
        (8, 0, 'B5', .75), (8, .75, 'G5', .75), (8, 1.5, 'E5', .5), (8, 2, 'G5', 2),
        (9, 0, 'C6', .75), (9, .75, 'G5', .75), (9, 1.5, 'E5', .5), (9, 2, 'C5', 2),
        (10, 0, 'D5', .5), (10, .5, 'F#5', .5), (10, 1, 'A5', .75), (10, 1.75, 'C6', .75), (10, 2.5, 'B5', 1.5),
        (11, 0, 'G5', 2), (11, 2.5, 'B4', .5), (11, 3, 'D5', 1),
        (12, 0, 'E5', .75), (12, .75, 'G5', .75), (12, 1.5, 'B5', .5), (12, 2, 'E6', 2),
        (13, 0, 'C6', .5), (13, .5, 'A5', .5), (13, 1, 'E5', 1), (13, 2, 'F#5', .5), (13, 2.5, 'A5', .5), (13, 3, 'C6', 1),
        (14, 0, 'B5', 1), (14, 1, 'A5', .5), (14, 1.5, 'G5', 2.5),
        (15, 0, 'A5', .5), (15, .5, 'F#5', .5), (15, 1, 'D5', 1), (15, 2, 'C5', .5), (15, 2.5, 'A4', 1.5),
    ]
    for bar, beat, n, dur in melody:
        if dur >= 1.5:  # long notes are rolled, as a pan player would
            k = int(dur * 4)
            for i in range(k):
                s.add(bar, beat + i * .25, steel(hz(n), .5, .75 if i == 0 else .4 * (1 - i / k / 2)), .3, 'lead')
        else:
            s.add(bar, beat, steel(hz(n), 1.0, .8), .3, 'lead')
    return s.render({
        'keys': lambda x: reverb(x, .2, rt=1.2),
        'lead': lambda x: reverb(x, .25, rt=1.5),
        'drums': lambda x: reverb(x, .12, rt=.8),
    }), s.loop


def song_phoenix():
    """Fire Temple: a slow, epic tune in D for Phoenix Ruby (taiko, guzheng, flute, gong, strings)."""
    s = Song(92, 16)
    prog = ['Dm', 'Dm', 'Bb', 'C', 'Dm', 'Dm', 'Gm', 'A', 'Bb', 'C', 'Dm', 'Dm', 'Bb', 'Gm', 'A', 'A']
    tones = {'Dm': ['D', 'F', 'A'], 'Bb': ['Bb', 'D', 'F'], 'C': ['C', 'E', 'G'], 'Gm': ['G', 'Bb', 'D'],
             'A': ['A', 'C#', 'E']}
    for bar, ch in enumerate(prog):
        r, t3, t5 = tones[ch]
        # guzheng ostinato: root, fifth, octave, fifth, third, fifth, octave, fifth
        line = [f'{r}4', f'{t5}4', f'{r}5', f'{t5}4', f'{t3}4', f'{t5}4', f'{r}5', f'{t5}4']
        for i, n in enumerate(line):
            m = midi(n)
            if m > midi('E5'):
                m -= 12
            s.add(bar, i * .5, pluck(hz(m), 1.4, .75 if i % 4 == 0 else .55, bright=.85, tau=1.1, bend=.01), .3, 'keys')
        for n in (f'{r}3', f'{t3}3', f'{t5}3'):
            s.add(bar, 0, strings(hz(n), 4 * s.beat - .05, .55, attack=.6, release=1.0, cutoff=1600), .11, 'pad')
        s.add(bar, 0, strings(hz('D2'), 4 * s.beat - .05, .6, attack=.6, release=1.0, cutoff=700), .12, 'pad')
        # taiko groove
        for beat, vel, f in ((0, 1, 58), (1.5, .55, 70), (2.5, .8, 58), (3, .5, 76), (3.5, .45, 76)):
            s.add(bar, beat, taiko(vel, f), .55, 'drums')
        if bar % 4 == 3:
            for i in range(4):
                s.add(bar, 3 + i * .25, taiko(.35 + i * .12, 82), .45, 'drums')
        for beat in (1, 3):
            s.add(bar, beat, rim(.6), .08, 'drums')
        for i in range(8):
            s.add(bar, i * .5, shaker(.6), .05, 'drums')
        if bar % 8 == 0:
            s.add(bar, 0, gong(98, 5.0), .55, 'gong')
    melody = [
        (4, 0, 'A4', 1.5), (4, 1.5, 'C5', .5), (4, 2, 'D5', 2), (5, 0, 'F5', 1), (5, 1, 'E5', .5), (5, 1.5, 'D5', .5),
        (5, 2, 'C5', 1), (5, 3, 'A4', 1), (6, 0, 'Bb4', 1.5), (6, 1.5, 'D5', .5), (6, 2, 'G5', 2),
        (7, 0, 'F5', .5), (7, .5, 'E5', .5), (7, 1, 'C#5', 1), (7, 2, 'A4', 2),
        (8, 0, 'D5', 1), (8, 1, 'F5', 1), (8, 2, 'A5', 2), (9, 0, 'G5', 1), (9, 1, 'E5', 1), (9, 2, 'C5', 2),
        (10, 0, 'D5', .5), (10, .5, 'E5', .5), (10, 1, 'F5', 1), (10, 2, 'A5', 1), (10, 3, 'G5', 1), (11, 0, 'F5', 1),
        (11, 1, 'D5', 3), (12, 0, 'Bb5', 1.5), (12, 1.5, 'A5', .5), (12, 2, 'F5', 2), (13, 0, 'G5', 1), (13, 1, 'Bb5', 1),
        (13, 2, 'D6', 2), (14, 0, 'C#6', 1), (14, 1, 'A5', 1), (14, 2, 'E5', 1), (14, 3, 'G5', 1),
        (15, 0, 'F5', .5), (15, .5, 'E5', .5), (15, 1, 'C#5', 1), (15, 2, 'A4', 2),
    ]
    for bar, beat, n, dur in melody:
        s.add(bar, beat, flute(hz(n), dur * s.beat * .95, .7, bend=.03 if dur >= 1 else 0), .2, 'lead')
    return s.render({
        'keys': lambda x: reverb(x, .25, rt=2.0),
        'pad': lambda x: reverb(x, .4, rt=3.0),
        'lead': lambda x: reverb(x, .4, rt=2.6),
        'drums': lambda x: reverb(x, .2, rt=1.8),
        'gong': lambda x: reverb(x, .3, rt=3.0),
    }), s.loop


def song_blackjack():
    """Velvet Table: a soft swing tune in Bb for blackjack (piano, upright bass, brushes, vibes)."""
    s = Song(96, 16)
    prog = ['Cm7', 'F7', 'Bbmaj7', 'Gm7', 'Cm7', 'F7', 'Bbmaj7', 'G7', 'Ebmaj7', 'Ab7', 'Dm7', 'G7', 'Cm7', 'F7',
            'Bbmaj7|G7', 'Cm7|F7']
    voicing = {'Cm7': ['Eb3', 'G3', 'Bb3', 'D4'], 'F7': ['Eb3', 'A3', 'D4'], 'Bbmaj7': ['D3', 'F3', 'A3', 'C4'],
               'Gm7': ['F3', 'Bb3', 'D4'], 'G7': ['F3', 'B3', 'E4'], 'Ebmaj7': ['G3', 'Bb3', 'D4'],
               'Ab7': ['Gb3', 'C4', 'F4'], 'Dm7': ['F3', 'A3', 'C4']}
    root = {'Cm7': 'C2', 'F7': 'F1', 'Bbmaj7': 'Bb1', 'Gm7': 'G1', 'G7': 'G1', 'Ebmaj7': 'Eb2', 'Ab7': 'Ab1', 'Dm7': 'D2'}
    third = {k: (3 if 'm7' in k and 'maj' not in k else 4) for k in root}
    sw = 2 / 3
    first = [p.split('|')[0] for p in prog]
    for bar, spec in enumerate(prog):
        halves = spec.split('|')
        nxt_bar = midi(root[first[(bar + 1) % 16]])
        if len(halves) == 1:
            ch = halves[0]
            for beat, dur, vel in ((0, .5, .55), (1 + sw, .6, .5)):
                for i, n in enumerate(voicing[ch]):
                    s.add(bar, beat + i * .01, ep(hz(n), dur * s.beat, vel, tine=.4), .35, 'keys')
            for i, m in enumerate(walk(midi(root[ch]), nxt_bar, third[ch])):
                s.add(bar, i, upright(hz(m), .9 * s.beat, .85 if i % 2 == 0 else .7), .75, 'bass')
        else:
            for hi, ch in enumerate(halves):
                for i, n in enumerate(voicing[ch]):
                    s.add(bar, hi * 2 + i * .01, ep(hz(n), .7 * s.beat, .5, tine=.4), .35, 'keys')
                nxt = midi(root[halves[1]]) if hi == 0 else nxt_bar
                for i, m in enumerate(walk(midi(root[ch]), nxt, beats=2)):
                    s.add(bar, hi * 2 + i, upright(hz(m), .9 * s.beat, .8), .75, 'bass')
        for beat in range(4):
            s.add(bar, beat, brush(.8 if beat % 2 else .5), .16, 'drums')
        for beat in (0, 1, 1 + sw, 2, 3, 3 + sw):
            s.add(bar, beat, ride(.45 if beat % 1 else .65), .07, 'drums')
        for beat in (1, 3):
            s.add(bar, beat, hat(.6), .08, 'drums')
        s.add(bar, 0, kick(.4), .2, 'drums')
    melody = [
        (0, 0, 'G4', sw), (0, sw, 'Bb4', 1 - sw), (0, 1, 'D5', 1), (0, 2, 'C5', 2),
        (1, 0, 'A4', sw), (1, sw, 'C5', 1 - sw), (1, 1, 'Eb5', 1), (1, 2, 'D5', 2), (2, 0, 'D5', 3), (2, 3, 'F5', 1),
        (3, 0, 'Bb4', 2), (3, 2, 'G4', 2),
        (4, 0, 'G5', 1), (4, 1, 'Eb5', sw), (4, 1 + sw, 'C5', 1 - sw), (4, 2, 'D5', 2),
        (5, 0, 'C5', 1), (5, 1, 'A4', sw), (5, 1 + sw, 'F4', 1 - sw), (5, 2, 'A4', 2),
        (6, 0, 'Bb4', 1), (6, 1, 'D5', 1), (6, 2, 'F5', 2), (7, 0, 'F5', sw), (7, sw, 'D5', 1 - sw), (7, 1, 'B4', 1),
        (7, 2, 'G4', 2), (8, 0, 'G5', 1.5), (8, 1 + sw, 'F5', 1 - sw), (8, 2, 'D5', 2),
        (9, 0, 'C5', 1), (9, 1, 'Eb5', 1), (9, 2, 'Gb5', 2), (10, 0, 'F5', 1), (10, 1, 'D5', 1), (10, 2, 'A4', 2),
        (11, 0, 'B4', 1), (11, 1, 'D5', 1), (11, 2, 'F5', 2), (12, 0, 'Eb5', 1), (12, 1, 'G5', 1), (12, 2, 'Bb5', 2),
        (13, 0, 'A5', 1), (13, 1, 'F5', sw), (13, 1 + sw, 'Eb5', 1 - sw), (13, 2, 'C5', 2),
        (14, 0, 'D5', 2), (14, 2, 'B4', 2), (15, 0, 'C5', 1), (15, 1, 'Eb5', 1), (15, 2, 'A4', 2),
    ]
    for bar, beat, n, dur in melody:
        s.add(bar, beat, vibes(hz(n), max(1.0, dur * s.beat * 1.7), .7), .24, 'lead')
    return s.render({
        'keys': lambda x: reverb(x, .25, rt=1.6),
        'lead': lambda x: reverb(x, .35, rt=2.0),
        'drums': lambda x: reverb(x, .15, rt=1.0),
        'bass': lambda x: reverb(x, .06, rt=.8),
    }), s.loop


# ── Effects ──────────────────────────────────────────────────────────────────

def arp(inst, notes, step, d, vel=.8, **kw):
    return mix(*[(i * step, inst(hz(n), d, vel, **kw)) for i, n in enumerate(notes)])


def fx_tap():
    t = tt(.05)
    y = np.sin(2 * np.pi * 1900 * t) * np.exp(-t / .006) + .4 * np.sin(2 * np.pi * 950 * t) * np.exp(-t / .01)
    return y + highpass(noise(.05), 5000) * np.exp(-t / .0015) * .3


def fx_coins():
    return reverb(coin_shower(1.1, 22, seed=3), .2, rt=1.0)


def fx_classic():
    spin_d = 1.3
    t = tt(spin_d)
    clicks = np.zeros(ns(spin_d))
    at, gap = 0.0, .085
    while at < spin_d - .05:
        place(clicks, ns(at), rim(.8)[:ns(.03)] * (1 - at / spin_d * .5), .5)
        at += gap
        gap = max(.032, gap * .9)
    spin = clicks + whoosh(spin_d, 300, 2500, 1.0, 1.4) * .5 + bandpass(noise(spin_d), 80, 300) * np.sin(np.pi * t / spin_d) * .3
    stop_t = tt(.3)
    stop = np.sin(2 * np.pi * np.cumsum(90 + 80 * np.exp(-stop_t / .02)) / SR) * np.exp(-stop_t / .07)
    place(stop, 0, rim(1), .6)
    stop += np.sin(2 * np.pi * 1250 * stop_t) * np.exp(-stop_t / .05) * .2
    small = reverb(arp(vibes, ['C5', 'E5', 'G5', 'C6'], .075, 1.0, .85), .25, rt=1.4)
    big = mix(
        (0, swell(.4) * .4),
        (.0, arp(brass, ['G4', 'G4', 'G4'], .13, .1, .85)),
        (.4, sum(brass(hz(n), 1.0, .9) for n in ('C4', 'E4', 'G4', 'C5'))),
        (.4, crash(.6)), (.4, kick(1)),
        (1.4, sum(brass(hz(n), 1.2, .9) for n in ('E4', 'G4', 'C5', 'E5'))),
        (1.4, kick(1)), (1.4, crash(.4)),
        (.4, coin_shower(2.2, 20, seed=5) * .8),
        (.45, arp(vibes, ['C6', 'E6', 'G6', 'C7', 'G6', 'C7'], .09, 1.2, .5)),
    )
    jackpot = mix(
        (0, swell(1.0) * .5),
        (0, arp(vibes, ['C5', 'E5', 'G5', 'C6', 'E6', 'G6', 'C7'], .1, 1.0, .6)),
        (1.0, sum(brass(hz(n), .5, .9) for n in ('F4', 'A4', 'C5'))), (1.0, kick(1)), (1.0, crash(.5)),
        (1.6, sum(brass(hz(n), .5, .9) for n in ('G4', 'B4', 'D5'))), (1.6, kick(1)),
        (2.2, sum(brass(hz(n), 2.2, 1.0) for n in ('C4', 'E4', 'G4', 'C5', 'E5'))), (2.2, kick(1)), (2.2, crash(1)),
        (2.2, sum(bell(hz(n), 2.5, .5, ratio=2.0, index=1.2, tau=1.0) for n in ('C6', 'G6', 'C7'))),
        (1.0, coin_shower(4.0, 26, seed=8)),
    )
    return {'spin': (spin, .55), 'reel_stop': (stop, .7), 'win_small': (small, .65),
            'win_big': (reverb(big, .25, rt=1.6), .89), 'jackpot': (reverb(jackpot, .25, rt=2.0), .89)}


def fx_fruit():
    spin_d = 1.2
    blips = mix(*[(i * .055, marimba(hz(n), .25, .6)) for i, n in
                  enumerate(['G4', 'A4', 'B4', 'D5', 'E5', 'G5', 'A5', 'B5', 'D6', 'E6', 'G6'])])
    spin = mix((0, blips), (0, whoosh(spin_d, 1500, 7000, 1.0, 1.2) * .35),
               *[(i * .11, shaker(.8)) for i in range(10)])
    stop = mix((0, marimba(hz('G3'), .35, 1.0)), (0, clave(.7)), (0, conga(180, .6)))
    small = reverb(arp(steel, ['G5', 'B5', 'D6', 'G6'], .08, 1.0, .85), .2, rt=1.2)
    big = mix(
        (0, arp(steel, ['G5', 'B5', 'D6', 'G6', 'D6', 'G6', 'B6'], .1, 1.0, .85)),
        *[(i * .08, conga(300 if i % 2 else 220, .7, i % 3 == 0)) for i in range(10)],
        (.75, sum(steel(hz(n), 1.6, .8) for n in ('G5', 'B5', 'D6'))), (.75, kick(1)),
        (.75, arp(marimba, ['G4', 'B4', 'D5', 'G5', 'B5', 'D6', 'G6'], .06, .6, .6)),
        (.8, coin_shower(2.0, 20, seed=11) * .8),
    )
    jackpot = mix(
        (0, swell(.8) * .4),
        (0, arp(marimba, ['G4', 'A4', 'B4', 'D5', 'E5', 'G5', 'A5', 'B5', 'D6', 'E6', 'G6'], .07, .6, .65)),
        *[(.8 + i * .5, sum(steel(hz(n), 1.2, .85) for n in ch)) for i, ch in
          enumerate((('C5', 'E5', 'G5'), ('D5', 'F#5', 'A5'), ('G5', 'B5', 'D6', 'G6')))],
        (.8, kick(1)), (1.3, kick(1)), (1.8, kick(1)), (1.8, crash(.6)),
        *[(.8 + i * .1, conga(300 if i % 2 else 220, .7, i % 3 == 0)) for i in range(20)],
        (1.8, arp(steel, ['G6', 'D6', 'B5', 'G6', 'D6', 'B6'], .12, 1.2, .5)),
        (.8, coin_shower(4.0, 26, seed=12)),
    )
    return {'spin': (spin, .55), 'reel_stop': (stop, .7), 'win_small': (small, .65),
            'win_big': (reverb(big, .2, rt=1.4), .89), 'jackpot': (reverb(jackpot, .22, rt=1.8), .89)}


def fx_phoenix():
    spin_d = 1.35
    t = tt(spin_d)
    crackle = np.zeros(ns(spin_d))
    r = np.random.default_rng(4)
    for _ in range(70):
        place(crackle, ns(r.random() * spin_d), highpass(noise(.01), 3000) * np.exp(-tt(.01) / .002), r.uniform(.1, .5))
    spin = mix((0, taiko(.9, 62)), (0, whoosh(spin_d, 200, 3000, 1.6, 1.0) * .8), (0, crackle * np.sin(np.pi * t / spin_d)))
    stop = mix((0, taiko(.8, 75, .36)), (0, bell(hz('A6'), .36, .25, ratio=2.76, index=1.4, tau=.12)))
    small = reverb(arp(pluck, ['D5', 'F5', 'G5', 'A5', 'C6', 'D6'], .06, 1.2, .85, bright=.85, tau=.9), .3, rt=1.8)
    big = mix(
        (0, gong(98, 3.5) * 1.5),
        *[(i * .09, taiko(.5 + i * .05, 70)) for i in range(8)],
        (.75, taiko(1, 55)),
        (.75, sum(strings(hz(n), 1.6, .8, attack=.05, release=.8) for n in ('D4', 'F4', 'A4', 'D5'))),
        (.75, flute(hz('A5'), .25, .7)), (1.0, flute(hz('C6'), .25, .7)), (1.25, flute(hz('D6'), 1.0, .8, bend=.04)),
        (.8, coin_shower(2.0, 18, seed=21) * .7),
    )
    jackpot = mix(
        (0, swell(1.0) * .5),
        *[(i * .1, taiko(.4 + i * .06, 68)) for i in range(10)],
        (1.0, gong(87, 5.0) * 1.8), (1.0, taiko(1, 52)),
        *[(1.0 + i * .55, sum(brass(hz(n), .5 if i < 2 else 2.4, .9) for n in ch)) for i, ch in
          enumerate((('Bb3', 'D4', 'F4'), ('C4', 'E4', 'G4'), ('D4', 'F#4', 'A4', 'D5')))],
        (2.1, taiko(1, 52)), (2.1, crash(.5)),
        (2.1, arp(pluck, ['D5', 'F#5', 'A5', 'D6', 'F#6', 'A6'], .07, 1.6, .6, bright=.9, tau=1.2)),
        (1.0, coin_shower(4.0, 24, seed=22)),
    )
    return {'spin': (spin, .55), 'reel_stop': (stop, .5), 'win_small': (small, .65),
            'win_big': (reverb(big, .3, rt=2.2), .89), 'jackpot': (reverb(jackpot, .3, rt=2.6), .89)}


def fx_blackjack():
    def clack(seed):
        r = np.random.default_rng(seed)
        d = .06
        t = tt(d)
        return (bandpass(noise(d), 2500, 6000) * np.exp(-t / .004)
                + sum(np.sin(2 * np.pi * f * t) * np.exp(-t / .012) for f in (r.uniform(3200, 3600), r.uniform(4700, 5200))) * .3)
    chip = mix((0, clack(1)), (.045, clack(2) * .6), (.075, clack(3) * .3))
    d = .16
    t = tt(d)
    card = sweep_filter(noise(d), 1500, 6000, width=1.4) * np.sin(np.pi * np.minimum(1, t / d)) ** 2
    card = mix((0, card * .8), (.11, bandpass(noise(.03), 1000, 4000) * np.exp(-tt(.03) / .005)))
    shuffle = np.zeros(ns(1.3))
    at, gap = 0.0, .012
    r = np.random.default_rng(9)
    while at < 1.0:
        place(shuffle, ns(at), bandpass(noise(.01), 1500, 7000) * np.exp(-tt(.01) / .0015), r.uniform(.3, .7))
        at += gap * r.uniform(.6, 1.4)
        gap *= 1.006
    place(shuffle, ns(1.05), card, .9)
    win = reverb(arp(ep, ['Bb4', 'D5', 'F5', 'Bb5'], .07, .6, .7), .25, rt=1.5)
    bj = reverb(mix(
        (0, arp(vibes, ['F5', 'Bb5', 'D6', 'F6'], .06, 1.2, .7)),
        (.25, sum(brass(hz(n), .9, .8) for n in ('D4', 'F4', 'A4', 'C5'))),
        (.25, coin_shower(1.2, 16, seed=31) * .6),
    ), .25, rt=1.6)
    lose = reverb(mix((0, sum(ep(hz(n), .35, .5, tine=.2) for n in ('D4', 'F4'))),
                      (.28, sum(ep(hz(n), .6, .45, tine=.2) for n in ('C4', 'Eb4')))), .25, rt=1.4)
    push = reverb(sum(ep(hz(n), .5, .5, tine=.3) for n in ('F4', 'Bb4', 'D5')), .25, rt=1.4)
    return {'chip': (chip, .6), 'card': (card, .5), 'shuffle': (shuffle, .6), 'win': (win, .65),
            'blackjack': (bj, .85), 'lose': (lose, .45), 'push': (push, .45)}


# ── Output ───────────────────────────────────────────────────────────────────

def write_wav(path, x):
    pcm = np.clip(x, -1, 1)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((pcm * 32767).astype('<i2').tobytes())


def encode(x, out, args):
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, 'in.wav')
        write_wav(src, x)
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', src, *args, out], check=True)


def save_effect(folder, name, x, peak):
    os.makedirs(folder, exist_ok=True)
    encode(finish(x, peak), os.path.join(folder, f'{name}.mp3'), ['-ac', '1', '-codec:a', 'libmp3lame', '-b:a', '96k'])


def save_music(folder, name, song):
    x, loop = song
    x = x - np.mean(x)
    x = np.tanh(1.1 * x / np.max(np.abs(x))) / np.tanh(1.1) * .7
    os.makedirs(folder, exist_ok=True)
    encode(x, os.path.join(folder, f'{name}.ogg'), ['-ac', '1', '-codec:a', 'libvorbis', '-q:a', '3'])
    padded = np.concatenate([x[-SR:], x, x[:SR]])
    encode(padded, os.path.join(folder, f'{name}.mp3'), ['-ac', '1', '-codec:a', 'libmp3lame', '-b:a', '80k'])
    print(f'{folder}/{name}: loop {loop} samples = {loop / SR:.6f} s')


def main():
    shared = os.path.join(ROOT, 'assets', 'sounds')
    save_effect(shared, 'tap', fx_tap(), .3)
    save_effect(shared, 'coins', fx_coins(), .7)
    save_music(shared, 'lobby', song_lobby())
    for game, fx, song in (('gold', fx_classic, song_classic), ('fruit', fx_fruit, song_fruit),
                           ('phoenix', fx_phoenix, song_phoenix), ('blackjack', fx_blackjack, song_blackjack)):
        folder = os.path.join(ROOT, 'assets', 'games', game, 'sounds')
        for name, (x, peak) in fx().items():
            save_effect(folder, name, x, peak)
        save_music(folder, 'music', song())


if __name__ == '__main__':
    main()
