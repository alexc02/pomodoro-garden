#!/usr/bin/env python3
"""Writes the UI micro-sounds.

Only `lib/src/feedback/micro_sounds.dart` refers to these files.

    Soil settle      0.5s   a seed landing in soft earth
    Growth shimmer   0.8s   soft rising chime when a plant reaches a stage
    Button tap       0.05s  soft wooden click
    Unlock           1.2s   three rising notes for a milestone

One AAC copy each. Unlike the end sounds these never go to a notification,
so iOS's no-AAC rule doesn't apply (see `docs/ambience.md`).

All well below the end sounds' -9 dBFS peak; they accompany things rather
than announce them.

Needs `ffmpeg` on PATH:

    python3 scripts/make_synth_micro_sounds.py
"""

from __future__ import annotations

import math
import pathlib
import random
import shutil
import struct
import subprocess
import tempfile
import wave

# Full rate: these are compressed, so there's no size reason to halve it.
SAMPLE_RATE = 44_100

AAC_BITRATE = '64k'


def _biquad(samples: list[float], kind: str, freq: float, q: float = 0.707) -> list[float]:
    """RBJ biquad: 'lp', 'hp' or 'bp' (constant peak gain)."""
    w = 2 * math.pi * freq / SAMPLE_RATE
    cw, sw = math.cos(w), math.sin(w)
    alpha = sw / (2 * q)
    if kind == 'lp':
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == 'hp':
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:
        b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * cw, 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in samples:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def soil_settle() -> tuple[list[float], float]:
    """Muffled pat, a few crumbs, short room. -11 dBFS.

    Pitchless on purpose so it can't clash with the bed (a pitched version
    sounded like a cartoon bloop). Band-passed noise at 420 Hz, crumbs around
    1.1 kHz, four early reflections.
    """
    grit = random.Random(1)
    count = int(0.42 * SAMPLE_RATE)

    body = _biquad(
        _biquad([grit.uniform(-1, 1) for _ in range(count)], 'bp', 420, 0.9),
        'lp',
        1_800,
    )
    samples = [
        3.0 * x * min(1.0, (i / SAMPLE_RATE) / 0.003)
        * math.exp(-(i / SAMPLE_RATE) / 0.045)
        for i, x in enumerate(body)
    ]

    # Five crumbs, each quieter.
    for crumb in range(5):
        at = int((0.06 + 0.05 * crumb + grit.uniform(0, 0.02)) * SAMPLE_RATE)
        span = int(0.012 * SAMPLE_RATE)
        grain = _biquad(
            _biquad([grit.uniform(-1, 1) for _ in range(span)], 'bp', 1_100, 1.2),
            'lp',
            2_500,
        )
        strength = 0.55 * 0.7**crumb
        for i in range(span):
            if at + i < count:
                samples[at + i] += (
                    grain[i] * strength * math.exp(-i / (0.004 * SAMPLE_RATE))
                )

    # Early reflections, with padding for them to ring out.
    roomed = samples + [0.0] * int(0.06 * SAMPLE_RATE)
    for delay, gain in ((0.011, 0.22), (0.019, 0.15), (0.031, 0.09), (0.047, 0.05)):
        offset = int(delay * SAMPLE_RATE)
        for i, x in enumerate(samples):
            roomed[i + offset] += x * gain

    return roomed, -11.0


def growth_shimmer() -> tuple[list[float], float]:
    """Four overlapping high notes, each a slightly detuned pair. D major
    pentatonic an octave above the wind chime so they don't sound alike.
    -15 dBFS.
    """
    length = 0.8
    count = int(SAMPLE_RATE * length)
    samples = [0.0] * count

    # (frequency, onset, strength)
    notes = (
        (1174.66, 0.00, 1.00),  # D6
        (1567.98, 0.09, 0.85),  # G6
        (1760.00, 0.18, 0.70),  # A6
        (2349.32, 0.28, 0.55),  # D7
    )

    for frequency, onset, strength in notes:
        start = int(onset * SAMPLE_RATE)
        for index in range(start, count):
            since = (index - start) / SAMPLE_RATE
            envelope = (1 - math.exp(-since / 0.004)) * math.exp(-since / 0.16)
            if since > 0.004 and envelope < 1e-4:
                break
            # Two sines ~4 cents apart plus a quiet octave.
            value = (
                math.sin(2 * math.pi * frequency * since)
                + math.sin(2 * math.pi * frequency * 1.0023 * since)
                + 0.18 * math.sin(2 * math.pi * frequency * 2 * since)
            )
            samples[index] += strength * envelope * value

    return samples, -15.0


def button_tap() -> tuple[list[float], float]:
    """Soft wooden click. -13 dBFS; it fires the most, so keep it subtle.

    Partials sit where phone speakers are loud (lower ones got lost), and the
    trailing silence stops AAC priming from eating the click.
    """
    length = 0.08
    count = int(SAMPLE_RATE * length)
    samples = [0.0] * count

    for index in range(count):
        since = index / SAMPLE_RATE
        # 14 ms decay; longer turns into a bloop.
        envelope = (1 - math.exp(-since / 0.0008)) * math.exp(-since / 0.014)
        # Inharmonic second mode, like a struck block.
        samples[index] = envelope * (
            math.sin(2 * math.pi * 950.0 * since)
            + 0.45 * math.sin(2 * math.pi * 2_330.0 * since)
        )

    return samples, -13.0


def unlock() -> tuple[list[float], float]:
    """Rising D major triad on the wind chime's tube partials. -12 dBFS.
    Milestones are rare and `MilestoneKeeper` waits for quiet first.
    """
    length = 1.2
    count = int(SAMPLE_RATE * length)
    samples = [0.0] * count

    partials = ((1.0, 1.0), (2.76, 0.38), (5.40, 0.14))
    # D5, F#5, A5
    notes = ((587.33, 0.00, 0.80), (739.99, 0.13, 0.90), (880.00, 0.27, 1.00))

    for frequency, onset, strength in notes:
        start = int(onset * SAMPLE_RATE)
        for index in range(start, count):
            since = (index - start) / SAMPLE_RATE
            envelope = min(since / 0.004, 1.0) * math.exp(-since / 0.42)
            if since > 0.004 and envelope < 1e-4:
                break
            value = 0.0
            for ratio, weight in partials:
                value += weight * math.exp(-since * ratio / 0.42) * math.sin(
                    2 * math.pi * frequency * ratio * since
                )
            samples[index] += strength * envelope * value

    return samples, -12.0


# Must match `MicroSound` in lib/src/feedback/micro_sounds.dart
# (checked by test/feedback/micro_sounds_test.dart).
SOUNDS = {
    'soil_settle': soil_settle,
    'growth_shimmer': growth_shimmer,
    'button_tap': button_tap,
    'unlock': unlock,
}


def normalised(samples: list[float], peak_dbfs: float) -> list[int]:
    """[samples] scaled to [peak_dbfs] and rounded to 16-bit."""
    peak = max(abs(sample) for sample in samples) or 1.0
    ceiling = 32_767 * (10 ** (peak_dbfs / 20))
    return [int(sample / peak * ceiling) for sample in samples]


def write_aac(path: pathlib.Path, samples: list[int]) -> None:
    """Encodes to AAC via a temporary WAV."""
    path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.TemporaryDirectory() as scratch:
        source = pathlib.Path(scratch) / 'source.wav'
        with wave.open(str(source), 'wb') as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(SAMPLE_RATE)
            out.writeframes(struct.pack(f'<{len(samples)}h', *samples))

        subprocess.run(
            [
                'ffmpeg', '-loglevel', 'error', '-y',
                '-i', str(source),
                '-c:a', 'aac', '-b:a', AAC_BITRATE, '-ac', '1',
                str(path),
            ],
            check=True,
        )

    print(f'wrote {path} ({path.stat().st_size / 1024:.1f} KB)')


def main() -> None:
    if shutil.which('ffmpeg') is None:
        raise SystemExit(
            'ffmpeg is not on PATH, and these ship as AAC. Install ffmpeg and '
            'run this again.'
        )

    root = pathlib.Path(__file__).resolve().parent.parent
    total = 0
    for stem, synthesise in SOUNDS.items():
        samples, peak_dbfs = synthesise()
        destination = root / 'assets' / 'audio' / 'micro' / f'{stem}.m4a'
        write_aac(destination, normalised(samples, peak_dbfs))
        total += destination.stat().st_size

    print(f'{total / 1024:.1f} KB of micro-sounds. All app audio is capped '
          'at 8 MB; test/ambience/bundled_audio_test.dart is what fails if it '
          'goes over.')


if __name__ == '__main__':
    main()
