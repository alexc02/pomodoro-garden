#!/usr/bin/env python3
"""Writes the UI micro-sounds. PRD v2.2 §5.4: there is no sound designer, so
these are synthesised here and ship as they are.

Nothing in the app names these files except `lib/src/feedback/micro_sounds.dart`.

PRD §9.2's four UI micro-sounds, counted among its fifteen audio assets. §5.4
specs the first two of them — a context, a source and a format each; the button
tap and the unlock are named in §9.2 and nowhere else, so their durations below
are this script's reading rather than the PRD's:

    Soil settle      0.5s   foley — a seed landing, and the grains it throws up
    Growth shimmer   0.8s   a soft rising chime, for a plant reaching a stage
    Button tap       0.05s  the quietest thing here; a soft wooden click
    Unlock           1.2s   three notes up, for a milestone award

**One copy each, and AAC, with nothing to argue about.** The end sounds next
door ship twice and half of that in PCM, because iOS refuses an AAC notification
sound — see `docs/ambience.md`. None of these four ever reaches a notification,
so §5.4's AAC is simply the right answer, and all four together are a few tens
of kilobytes.

**They are quieter than the end sounds, and quieter than each other, on
purpose.** A sound that accompanies something rather than announcing it should
sit under the thing it accompanies, so the peaks below run from a barely-there
button tap up to the unlock — the more the moment is worth, the more of it is
audible. The end sounds peak at -9 dBFS; none of these comes near that.

Needs `ffmpeg` on PATH. Run from anywhere:

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

# 44.1 kHz mono, 16-bit into the encoder. Full rate, unlike the end sounds:
# those are PCM in the bundle and had to give up half their bandwidth to fit
# §5.4's 8 MB, where these are compressed and cost nothing worth trading for.
SAMPLE_RATE = 44_100

# What each is encoded at. Low for material this short — the whole set is a
# rounding error against the beds — and mono, because none of these has a side
# of the screen it belongs to.
AAC_BITRATE = '64k'


def _biquad(samples: list[float], kind: str, freq: float, q: float = 0.707) -> list[float]:
    """An RBJ biquad over [samples]: 'lp', 'hp' or 'bp' (constant peak gain)."""
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
    """A seed landing in soft earth: a muffled pat, a few crumbs falling back,
    and the short warmth of a small space. Peaked at -11 dBFS.

    **No pitch anywhere** — the owner's choice ("A · Soft pat") of three takes
    in ticket 37. The two versions before it were built on a falling sine, which
    reads as a cartoon *bloop*, and the first sat at 140 Hz, below what a phone
    speaker plays. This one is band-passed noise centred on 420 Hz with a fast
    attack and a 45 ms decay; the crumbs are duller noise around 1.1 kHz, each
    quieter than the last; and four early reflections give it a body without an
    echo. Pitchless, it cannot clash with whatever bed is playing under it.
    """
    grit = random.Random(1)
    count = int(0.42 * SAMPLE_RATE)

    # The pat.
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

    # The crumbs: five, falling back after it, each quieter than the last.
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

    # A small space: four early reflections, and room for them to ring out.
    roomed = samples + [0.0] * int(0.06 * SAMPLE_RATE)
    for delay, gain in ((0.011, 0.22), (0.019, 0.15), (0.031, 0.09), (0.047, 0.05)):
        offset = int(delay * SAMPLE_RATE)
        for i, x in enumerate(samples):
            roomed[i + offset] += x * gain

    return roomed, -11.0


def growth_shimmer() -> tuple[list[float], float]:
    """A plant reaching a stage: four high notes rising, each one glassy.

    A shimmer rather than a chime — the notes overlap, they are close together,
    and every one of them is two sines a few cents apart so the pair beats. The
    top of a D major pentatonic, an octave above where the wind chime plays, so
    that the two never sound like the same instrument. Peaked at -15 dBFS.
    """
    length = 0.8
    count = int(SAMPLE_RATE * length)
    samples = [0.0] * count

    # (frequency, when it enters, how loud)
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
            # Fast in, slow out: a shimmer that faded in would be a swell.
            envelope = (1 - math.exp(-since / 0.004)) * math.exp(-since / 0.16)
            if since > 0.004 and envelope < 1e-4:
                break
            # Two sines four cents apart, plus a quiet octave for the glassiness.
            value = (
                math.sin(2 * math.pi * frequency * since)
                + math.sin(2 * math.pi * frequency * 1.0023 * since)
                + 0.18 * math.sin(2 * math.pi * frequency * 2 * since)
            )
            samples[index] += strength * envelope * value

    return samples, -15.0


def button_tap() -> tuple[list[float], float]:
    """A deliberate tap: one soft wooden click, and nothing else.

    Short, no pitch worth naming, and **the quietest of the four** at -13 dBFS.
    This is the one that fires most often, and a tap the user notices is a tap
    they will come to resent — it should read as the button having weight
    rather than as the app saying something.

    **Quiet, not inaudible** (ticket 37, after the owner heard nothing): the
    first version was 320 and 787 Hz at -20 dBFS, below what a phone speaker
    plays well and too faint to register in 9 ms. The partials are now up where
    a small speaker is loud, the decay is a little longer, and the file carries
    trailing silence, so an AAC decoder's priming cannot eat a 50 ms click.
    """
    length = 0.08
    count = int(SAMPLE_RATE * length)
    samples = [0.0] * count

    for index in range(count):
        since = index / SAMPLE_RATE
        # 14 ms and gone. Any longer and it is a bloop.
        envelope = (1 - math.exp(-since / 0.0008)) * math.exp(-since / 0.014)
        # Two partials rather than one, which is what makes it wood rather than
        # a sine: a struck block has an inharmonic second mode.
        samples[index] = envelope * (
            math.sin(2 * math.pi * 950.0 * since)
            + 0.45 * math.sin(2 * math.pi * 2_330.0 * since)
        )

    return samples, -13.0


def unlock() -> tuple[list[float], float]:
    """A milestone award: three notes up, and the last one left ringing.

    The loudest of the four, and it earns it — a milestone is seven-times-in-an
    -app rare, and `MilestoneKeeper` has already waited for the timer to come to
    rest so that this lands in a silence. A major triad, rising, on the same
    struck-tube partials as REQ-008's wind chime so that the app sounds like one
    instrument. Peaked at -12 dBFS.
    """
    length = 1.2
    count = int(SAMPLE_RATE * length)
    samples = [0.0] * count

    partials = ((1.0, 1.0), (2.76, 0.38), (5.40, 0.14))
    # D5, F#5, A5 — up, because the whole message of the sound is *more*.
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


# The four §9.2 names, by the stem each is written under. Kept in step with
# `MicroSound` in lib/src/feedback/micro_sounds.dart, which
# test/feedback/micro_sounds_test.dart checks.
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
    """Encodes [samples] to AAC at [path], through a WAV nobody keeps."""
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

    print(f'{total / 1024:.1f} KB of micro-sounds. §5.4 caps all the app audio '
          'at 8 MB — test/ambience/bundled_audio_test.dart is what fails if it '
          'goes over.')


if __name__ == '__main__':
    main()
