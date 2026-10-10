#!/usr/bin/env python3
"""Writes the synthesised end-of-session sounds: wind chime, soft bell, singing
bowl and ocean wave.

PRD v2.2 §5.4: there is no sound designer, so these four are synthesised here
and ship as they are. Birdsong comes from a field recording of a blackbird,
written by `make_recorded_sounds.py` (ticket 37); this script still knows how
to synthesise one but no longer writes it. Nothing in the app names these files
except `lib/src/feedback/end_sound_player.dart`.

REQ-031 asks for five of them plus None, which is not a file:

    Wind chime      five struck tubes in a pentatonic scale (REQ-008's default)
    Soft bell       one small bell, on its own partials
    Birdsong        two short phrases of glided chirps
    Singing bowl    a slow swell with the beating two close modes make
    Ocean wave      filtered noise, one swell, breaking and receding

Two copies of each are written, and they are deliberately **not** the same
format, because the two copies have two different jobs:

  assets/audio/end/<name>.wav                  16-bit mono PCM. Played in the
                                               foreground, and copied into
                                               iOS's Library/Sounds, which
                                               takes PCM and not AAC.
  android/app/src/main/res/raw/<name>.m4a      AAC. Only ever an Android
                                               notification channel's sound,
                                               and a channel wants a resource
                                               rather than a Flutter asset.

`docs/ambience.md` has the whole argument, including why 22.05 kHz and why the
beds next door cannot be compressed at all. The short of it: iOS refuses an AAC
notification sound, so the asset has to be PCM; §5.4's 8 MB is real, so the
copy that *can* be compressed is.

Needs `ffmpeg` on PATH for the AAC half. Run from anywhere:

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

# 22.05 kHz mono, 16-bit. Half the rate the beds are at, and the reason is
# §5.4's 8 MB rather than taste: five one-shots at 44.1 kHz put the bundle over
# the cap on their own — see the arithmetic in `docs/ambience.md`. Nothing here
# has anything above 11 kHz in it to lose; the highest partial in the file is
# the wind chime's, at 9.3 kHz.
SAMPLE_RATE = 22_050

# Peak level, in dBFS, and the same for every sound. Headroom on purpose: these
# play at the end of a quiet session, and REQ-008's whole point is not to
# startle anyone. Matched on *peak* rather than on RMS, which is the honest
# thing a script can do — a 5-second bowl and a 60-millisecond chirp at the same
# RMS would not be the same loudness either, and which of the five sounds
# loudest is a judgement for §9.2's sound designer rather than for arithmetic.
PEAK_DBFS = -9.0

# What the AAC copy is encoded at. Mono, and generous for material this short:
# the whole set is a quarter of a megabyte.
AAC_BITRATE = '96k'


def wind_chime() -> list[float]:
    """REQ-008's default: five struck tubes, as if a breeze moved through them.

    A tube's partials are not harmonics — 1 : 2.76 : 5.40 : 8.93 are the
    measured ratios for a cylindrical aluminium tube, and they are the whole
    difference between a chime and an organ.
    """
    partials = ((1.0, 1.0), (2.76, 0.55), (5.40, 0.25), (8.93, 0.1))
    # Five notes of a D major pentatonic, struck in the order a breeze would
    # find them rather than up the scale: (frequency, when, how hard).
    strikes = (
        (587.33, 0.00, 1.00),  # D5
        (880.00, 0.29, 0.80),  # A5
        (659.25, 0.63, 0.70),  # E5
        (1046.50, 1.04, 0.55),  # C6
        (783.99, 1.62, 0.45),  # G5
    )
    # How long a struck tube takes to fall to 1/e of its loudness. Long, because
    # a chime that stops abruptly is a beep.
    decay = 1.5
    # The softest attack that still sounds struck. Below a millisecond or two
    # the onset clicks; much above it and the tube sounds bowed.
    attack = 0.006

    samples = _silence(4.0)
    for frequency, onset, strength in strikes:
        _strike(samples, frequency, onset, strength, partials, decay, attack)
    return samples


def soft_bell() -> list[float]:
    """One small bell, struck once.

    A bell's partials are named rather than numbered — hum, prime, tierce,
    quint, nominal — and the tierce is a *minor* third above the prime, which is
    why every bell in the world sounds faintly sad. The hum below the prime is
    what makes it a bell rather than a chime.
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
    # The prime again, half a hertz off, so the two beat once a couple of
    # seconds. A bell whose prime is a single sine is a sine.
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
    """Two short phrases of glided chirps, as a robin puts them.

    Each chirp is a frequency sweep rather than a note: a bird's syrinx slides,
    and a sequence of steady tones sounds like a phone. The phrases are
    separated by a real gap, because that is what makes it birdsong rather than
    an alarm.
    """
    # (start of the chirp, how long, from Hz, to Hz, how loud)
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
            # A raised cosine either side: a chirp with a square edge clicks.
            envelope = 0.5 - 0.5 * math.cos(2 * math.pi * through)
            frequency = start + (end - start) * through
            # A little vibrato, which is most of what makes a sweep sound alive.
            frequency *= 1.0 + 0.02 * math.sin(2 * math.pi * 28.0 * through * length)
            phase += 2 * math.pi * frequency / SAMPLE_RATE
            # The second harmonic, quietly: a bird is not a sine either.
            value = math.sin(phase) + 0.25 * math.sin(2 * phase)
            samples[first + index] += strength * envelope * value
    return samples


def singing_bowl() -> list[float]:
    """A struck bowl: slow to speak, slow to stop, and never quite steady.

    The wobble is the point. A bowl's modes come in close pairs — the rim is
    never perfectly round — so each partial is two frequencies a hertz or so
    apart, and what the ear hears is the two of them beating.
    """
    partials = ((1.00, 1.00), (2.71, 0.40), (5.18, 0.15), (8.16, 0.06))
    samples = _silence(5.0)
    # Struck softly and left to ring: a 40-millisecond attack is the difference
    # between a bowl and a bell, and 3.4 seconds of decay is what fills five.
    _strike(samples, 311.13, 0.0, 1.0, partials, decay=3.4, attack=0.040)
    # The same modes again, detuned, which is what beats against them.
    beating = tuple((ratio * 1.0035, weight * 0.8) for ratio, weight in partials)
    _strike(samples, 311.13, 0.0, 1.0, beating, decay=3.4, attack=0.040)
    return samples


def ocean_wave() -> list[float]:
    """One wave: noise that brightens as it breaks and darkens as it recedes.

    Two filters over the same seeded noise. The amplitude envelope is the swell;
    the filter's cutoff follows it, because a wave gets *brighter* as it breaks
    rather than merely louder, and an envelope on its own sounds like somebody
    turning a knob on a hiss.
    """
    length = 3.0
    count = int(SAMPLE_RATE * length)
    noise = random.Random(20260829)
    samples = [0.0] * count

    # One-pole lowpass, state carried across the loop.
    filtered = 0.0
    for index in range(count):
        through = index / count
        # Rises over the first two fifths, falls over the remaining three: a
        # wave breaks faster than it drains.
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


# Every sound REQ-031 names a file for, by the stem both copies are written
# under. `EndSound.none` is not here, and could not be: it is the absence of a
# file rather than a file of silence — see `endSoundAsset`.
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
    """Adds one struck resonator at [frequency] into [samples], in place.

    Shared by the chime, the bell and the bowl because they are the same
    physics with different partials: something swells over its attack, decays
    from then on, and its higher partials fade faster than its fundamental —
    which is what keeps a tail sweet rather than glassy.
    """
    start = int(onset * SAMPLE_RATE)
    for index in range(start, len(samples)):
        since = (index - start) / SAMPLE_RATE
        envelope = min(since / attack, 1.0) * math.exp(-since / decay)
        # Stop once it has decayed into inaudibility — but only once the attack
        # is behind it. The envelope is *zero* at the strike and climbs from
        # there, so a bare `envelope < 1e-4` breaks out of the loop on the first
        # sample and writes a file of silence. That is what ticket 06's version
        # of this script did, and nothing noticed because no test listened.
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
    """Encodes [source] to AAC at [path], replacing whatever was there."""
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
          '§5.4 caps all the app audio at 8 MB — '
          'test/ambience/bundled_audio_test.dart is what fails if it goes '
          'over.')


if __name__ == '__main__':
    main()
