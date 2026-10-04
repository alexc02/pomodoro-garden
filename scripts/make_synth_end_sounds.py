#!/usr/bin/env python3
"""Writes the synthesised end-of-session sounds: wind chime, soft bell, singing
bowl and ocean wave.

Birdsong is a field recording now (`make_recorded_sounds.py`); the synth
version is kept here but not written. Only
`lib/src/feedback/end_sound_player.dart` refers to these files.

Two copies of each:

  assets/audio/end/<name>.wav                  16-bit mono PCM. Foreground
                                               playback, and copied to iOS
                                               Library/Sounds, which won't
                                               take AAC.
  android/app/src/main/res/raw/<name>.m4a      AAC, for the Android
                                               notification channel (needs a
                                               resource, not an asset).

See `docs/ambience.md` for the size budget.

Needs `ffmpeg` on PATH:

    python3 scripts/make_synth_end_sounds.py
"""

from __future__ import annotations

import math
import pathlib
import random
import shutil
import struct
import subprocess
import wave

# 22.05 kHz to fit the 8 MB audio budget (see `docs/ambience.md`). Highest
# partial is the chime's 9.3 kHz, so nothing is lost.
SAMPLE_RATE = 22_050

# Same peak for every sound, with headroom so nothing startles. Peak rather
# than RMS since RMS doesn't match perceived loudness across such different
# lengths either.
PEAK_DBFS = -9.0

AAC_BITRATE = '96k'


def wind_chime() -> list[float]:
    """The default: five struck tubes.

    Partial ratios 1 : 2.76 : 5.40 : 8.93 are measured values for an aluminium
    tube (not harmonics).
    """
    partials = ((1.0, 1.0), (2.76, 0.55), (5.40, 0.25), (8.93, 0.1))
    # D major pentatonic, out of order: (frequency, onset, strength).
    strikes = (
        (587.33, 0.00, 1.00),  # D5
        (880.00, 0.29, 0.80),  # A5
        (659.25, 0.63, 0.70),  # E5
        (1046.50, 1.04, 0.55),  # C6
        (783.99, 1.62, 0.45),  # G5
    )
    # Seconds to 1/e.
    decay = 1.5
    # Much shorter clicks, much longer sounds bowed.
    attack = 0.006

    samples = _silence(4.0)
    for frequency, onset, strength in strikes:
        _strike(samples, frequency, onset, strength, partials, decay, attack)
    return samples


def soft_bell() -> list[float]:
    """One small bell, struck once. Tierce is a minor third; the hum below
    the prime is what makes it sound like a bell.
    """
    partials = (
        (0.50, 0.60),  # hum
        (1.00, 1.00),  # prime
        (1.19, 0.45),  # tierce
        (1.50, 0.30),  # quint
        (2.00, 0.35),  # nominal
        (2.50, 0.12),
        (3.01, 0.08),
    )
    samples = _silence(4.0)
    _strike(samples, 659.25, 0.0, 1.0, partials, decay=1.9, attack=0.004)
    # Prime again, 0.5 Hz off, for a slow beat.
    _strike(
        samples,
        659.25 + 0.5,
        0.0,
        0.5,
        ((1.0, 1.0),),
        decay=1.9,
        attack=0.004,
    )
    return samples


def birdsong() -> list[float]:
    """Two phrases of swept chirps with a gap between. Unused; birdsong is
    recorded now.
    """
    # (onset, length, from Hz, to Hz, strength)
    chirps = (
        (0.00, 0.09, 2400, 3800, 0.85),
        (0.14, 0.07, 3600, 2900, 0.70),
        (0.26, 0.11, 2600, 4300, 1.00),
        (0.42, 0.08, 4100, 3200, 0.65),
        (1.15, 0.10, 2500, 4000, 0.90),
        (1.30, 0.07, 3800, 3100, 0.60),
        (1.41, 0.13, 2700, 4600, 0.95),
        (1.62, 0.09, 4300, 3300, 0.55),
    )
    samples = _silence(3.0)
    for onset, length, start, end, strength in chirps:
        first = int(onset * SAMPLE_RATE)
        count = int(length * SAMPLE_RATE)
        phase = 0.0
        for index in range(count):
            through = index / count
            # Raised cosine so edges don't click.
            envelope = 0.5 - 0.5 * math.cos(2 * math.pi * through)
            frequency = start + (end - start) * through
            # Slight vibrato.
            frequency *= 1.0 + 0.02 * math.sin(2 * math.pi * 28.0 * through * length)
            phase += 2 * math.pi * frequency / SAMPLE_RATE
            # Quiet second harmonic.
            value = math.sin(phase) + 0.25 * math.sin(2 * phase)
            samples[first + index] += strength * envelope * value
    return samples


def singing_bowl() -> list[float]:
    """A struck bowl. Each mode is doubled and slightly detuned (real rims
    aren't perfectly round), which gives the beating wobble.
    """
    partials = ((1.00, 1.00), (2.71, 0.40), (5.18, 0.15), (8.16, 0.06))
    samples = _silence(5.0)
    # Slow 40 ms attack, long decay.
    _strike(samples, 311.13, 0.0, 1.0, partials, decay=3.4, attack=0.040)
    beating = tuple((ratio * 1.0035, weight * 0.8) for ratio, weight in partials)
    _strike(samples, 311.13, 0.0, 1.0, beating, decay=3.4, attack=0.040)
    return samples


def ocean_wave() -> list[float]:
    """One wave: seeded noise with a lowpass cutoff that follows the swell,
    so it brightens as it breaks instead of just getting louder.
    """
    length = 3.0
    count = int(SAMPLE_RATE * length)
    noise = random.Random(20260829)
    samples = [0.0] * count

    # One-pole lowpass, state carried across the loop.
    filtered = 0.0
    for index in range(count):
        through = index / count
        # Rises over the first 40%, falls over the rest.
        if through < 0.4:
            swell = math.sin(math.pi * through / 0.8)
        else:
            swell = math.cos(math.pi * (through - 0.4) / 1.2) ** 1.5
        swell = max(swell, 0.0)

        # 300 Hz at the troughs, 3.5 kHz at the crest.
        cutoff = 300.0 + 3200.0 * swell
        alpha = 1.0 - math.exp(-2 * math.pi * cutoff / SAMPLE_RATE)
        filtered += alpha * (noise.uniform(-1.0, 1.0) - filtered)
        samples[index] = swell * filtered

    return samples


# File stems. `EndSound.none` has no file (see `endSoundAsset`).
SOUNDS = {
    'wind_chime': wind_chime,
    'soft_bell': soft_bell,
    'birdsong': birdsong,
    'singing_bowl': singing_bowl,
    'ocean_wave': ocean_wave,
}


def _silence(seconds: float) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * seconds)


def _strike(
    samples: list[float],
    frequency: float,
    onset: float,
    strength: float,
    partials: tuple[tuple[float, float], ...],
    decay: float,
    attack: float,
) -> None:
    """Adds a struck resonator into [samples] in place. Higher partials
    decay faster than the fundamental.
    """
    start = int(onset * SAMPLE_RATE)
    for index in range(start, len(samples)):
        since = (index - start) / SAMPLE_RATE
        envelope = min(since / attack, 1.0) * math.exp(-since / decay)
        # Only after the attack: the envelope starts at zero, so checking
        # earlier would break on the first sample.
        if since > attack and envelope < 1e-4:
            break

        value = 0.0
        for ratio, weight in partials:
            value += weight * math.exp(-since * ratio / decay) * math.sin(
                2 * math.pi * frequency * ratio * since
            )
        samples[index] += strength * envelope * value


def normalised(samples: list[float]) -> list[int]:
    """[samples] scaled to [PEAK_DBFS] and rounded to 16-bit."""
    peak = max(abs(sample) for sample in samples) or 1.0
    ceiling = 32_767 * (10 ** (PEAK_DBFS / 20))
    return [int(sample / peak * ceiling) for sample in samples]


def write_wav(path: pathlib.Path, samples: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SAMPLE_RATE)
        out.writeframes(struct.pack(f'<{len(samples)}h', *samples))
    print(f'wrote {path} ({path.stat().st_size / 1024:.0f} KB)')


def write_aac(source: pathlib.Path, path: pathlib.Path) -> None:
    """Encodes [source] to AAC at [path], overwriting."""
    path.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            'ffmpeg', '-loglevel', 'error', '-y',
            '-i', str(source),
            '-c:a', 'aac', '-b:a', AAC_BITRATE, '-ac', '1',
            str(path),
        ],
        check=True,
    )
    print(f'wrote {path} ({path.stat().st_size / 1024:.0f} KB)')


def main() -> None:
    if shutil.which('ffmpeg') is None:
        raise SystemExit(
            'ffmpeg is not on PATH, and the Android copy of each sound is AAC. '
            'Install ffmpeg and run this again.'
        )

    root = pathlib.Path(__file__).resolve().parent.parent
    total = 0
    for name, synthesise in SOUNDS.items():
        # Recorded, not synthesised: see make_recorded_sounds.py.
        if name == 'birdsong':
            continue
        asset = root / 'assets' / 'audio' / 'end' / f'{name}.wav'
        write_wav(asset, normalised(synthesise()))

        raw = root / 'android/app/src/main/res/raw' / f'{name}.m4a'
        write_aac(asset, raw)

        total += asset.stat().st_size + raw.stat().st_size

    print(f'{total / 1024 / 1024:.2f} MB of end sounds, both copies counted. '
          'All app audio is capped at 8 MB; '
          'test/ambience/bundled_audio_test.dart is what fails if it goes '
          'over.')


if __name__ == '__main__':
    main()
