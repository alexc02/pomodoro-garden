#!/usr/bin/env python3
"""Writes the synthesised ambient loops: rain, ocean and white noise.

Forest and cafe are field recordings now (`make_recorded_sounds.py`). Their
synth functions stay so the other beds keep the same seeds. Only
`lib/src/ambience/ambience.dart` refers to these files.

Seamless loop: each bed is rendered one crossfade longer than the loop and
the tail is folded over the head with an equal-power crossfade (see
`wrapped`).

WAV, not AAC: lossy codecs pad the start and end, which adds tens of ms of
silence at the loop point unless encoder and player agree on gapless
metadata (ExoPlayer and AVPlayer don't). PCM loops sample-accurately with
`LoopMode.one`. See `docs/ambience.md`.

Seeded per bed, so output is byte-identical between runs.

    python3 scripts/make_synth_beds.py
"""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

# 44.1 kHz mono, 16-bit. Mono halves the size; all app audio must fit in 8 MB.
SAMPLE_RATE = 44_100

# Five 15 s beds is 6.3 MB of PCM, which leaves room for the end sounds.
LOOP_SECONDS = 15.0

CROSSFADE_SECONDS = 1.0

# Same RMS for every bed so switching doesn't jump in loudness (matching
# peaks wouldn't do that).
TARGET_RMS_DBFS = -20.0

# Stops a stray transient from clipping after RMS normalisation.
PEAK_CEILING_DBFS = -3.0

LOOP_SAMPLES = int(LOOP_SECONDS * SAMPLE_RATE)
CROSSFADE_SAMPLES = int(CROSSFADE_SECONDS * SAMPLE_RATE)
TOTAL_SAMPLES = LOOP_SAMPLES + CROSSFADE_SAMPLES


# ── building blocks ─────────────────────────────────────────────────────────


def white(rng: random.Random, count: int) -> list[float]:
    """`count` samples of white noise in [-1, 1]."""
    return [rng.uniform(-1.0, 1.0) for _ in range(count)]


def _coefficient(cutoff: float) -> float:
    """One-pole coefficient for `cutoff` Hz."""
    return 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)


def low_passed(samples: list[float], cutoff: float) -> list[float]:
    """One-pole low-pass."""
    coefficient = _coefficient(cutoff)
    out = [0.0] * len(samples)
    state = 0.0
    for index, sample in enumerate(samples):
        state += coefficient * (sample - state)
        out[index] = state
    return out


def high_passed(samples: list[float], cutoff: float) -> list[float]:
    """Signal minus its one-pole low-pass."""
    return [
        sample - low
        for sample, low in zip(samples, low_passed(samples, cutoff))
    ]


def scaled(samples: list[float], by: float) -> list[float]:
    return [sample * by for sample in samples]


def mixed(*layers: list[float]) -> list[float]:
    return [sum(values) for values in zip(*layers)]


def cycles(count: int, at: int) -> float:
    """Phase in radians for `count` whole cycles per loop.

    Slow modulation is specified per loop rather than in Hz so it lines up
    across the join.
    """
    return 2.0 * math.pi * count * at / LOOP_SAMPLES


def burst(
    rng: random.Random,
    into: list[float],
    at: int,
    length: int,
    cutoff: float,
    strength: float,
) -> None:
    """Adds a short noise transient (a droplet, a footstep) into `into`."""
    tail = min(length, len(into) - at)
    if tail <= 0:
        return

    grains = high_passed(white(rng, tail), cutoff)
    for index in range(tail):
        into[at + index] += (
            strength * grains[index] * math.exp(-4.0 * index / length)
        )


def ping(
    into: list[float],
    at: int,
    frequency: float,
    seconds: float,
    strength: float,
    bend: float = 1.0,
) -> None:
    """Adds a short tone (a cup, a bird) into `into`. The frequency is
    multiplied by `bend` over the tone's length.
    """
    length = int(seconds * SAMPLE_RATE)
    tail = min(length, len(into) - at)
    phase = 0.0

    for index in range(tail):
        through = index / length
        step = frequency * (bend**through)
        phase += 2.0 * math.pi * step / SAMPLE_RATE
        # Short ramp in to avoid a click, then exponential decay.
        envelope = min(index / 240.0, 1.0) * math.exp(-5.0 * through)
        into[at + index] += strength * envelope * math.sin(phase)


# ── beds ────────────────────────────────────────────────────────────────────


def rain(rng: random.Random) -> list[float]:
    """Steady rain: band-limited hiss with droplets on top."""
    # Low-passed twice to soften, then high-passed to drop the rumble.
    body = high_passed(
        low_passed(low_passed(white(rng, TOTAL_SAMPLES), 3_000.0), 3_000.0),
        400.0,
    )

    # Sparse enough to hear as individual drops.
    drops = [0.0] * TOTAL_SAMPLES
    for _ in range(int(22 * TOTAL_SAMPLES / SAMPLE_RATE)):
        burst(
            rng,
            drops,
            at=rng.randrange(TOTAL_SAMPLES),
            length=int(0.012 * SAMPLE_RATE),
            cutoff=4_000.0,
            strength=rng.uniform(0.4, 1.0),
        )

    return mixed(scaled(body, 1.0), scaled(drops, 0.5))


def forest(rng: random.Random) -> list[float]:
    """Wind through leaves and a few birds. Not shipped."""
    leaves = high_passed(low_passed(white(rng, TOTAL_SAMPLES), 1_400.0), 250.0)

    # Two shallow modulations so there's no obvious pulse to notice.
    gusting = [
        sample
        * (
            0.74
            + 0.16 * math.sin(cycles(2, index))
            + 0.10 * math.sin(cycles(5, index))
        )
        for index, sample in enumerate(leaves)
    ]

    birds = [0.0] * TOTAL_SAMPLES
    # Kept out of the crossfade region, where a chirp would double up.
    for at, frequency, bend in (
        (0.22, 3_100.0, 1.35),
        (0.31, 2_700.0, 0.72),
        (0.58, 3_600.0, 1.20),
        (0.63, 3_500.0, 0.80),
        (0.86, 2_900.0, 1.45),
    ):
        ping(
            birds,
            at=CROSSFADE_SAMPLES + int(at * (LOOP_SAMPLES - CROSSFADE_SAMPLES)),
            frequency=frequency,
            seconds=0.13,
            strength=0.5,
            bend=bend,
        )

    return mixed(scaled(gusting, 1.0), scaled(birds, 0.22))


def ocean(rng: random.Random) -> list[float]:
    """Three waves per loop, so the swell matches across the join."""
    WAVES = 3
    source = white(rng, TOTAL_SAMPLES)

    # Cutoff follows the swell, so this filters inline (coefficient changes
    # per sample).
    swell = [0.0] * TOTAL_SAMPLES
    state = 0.0
    for index, sample in enumerate(source):
        # 0 at trough, 1 at crest; squared so the draw-back is longer.
        height = (0.5 - 0.5 * math.cos(cycles(WAVES, index))) ** 2
        state += _coefficient(500.0 + 3_500.0 * height) * (sample - state)
        swell[index] = state * (0.18 + 0.82 * height)

    # Keep the low end, unlike rain; without it this sounds like wind.
    return high_passed(swell, 90.0)


def cafe(rng: random.Random) -> list[float]:
    """Distant murmur and china. Not shipped."""
    # Band-limited so nothing sounds like words.
    murmur = high_passed(low_passed(white(rng, TOTAL_SAMPLES), 1_100.0), 220.0)
    murmur = [
        sample
        * (
            0.70
            + 0.18 * math.sin(cycles(3, index))
            + 0.12 * math.sin(cycles(7, index) + 1.1)
        )
        for index, sample in enumerate(murmur)
    ]

    # Room tone.
    room = low_passed(white(rng, TOTAL_SAMPLES), 140.0)

    china = [0.0] * TOTAL_SAMPLES
    for at, frequency in (
        (0.17, 2_400.0),
        (0.42, 3_150.0),
        (0.55, 1_900.0),
        (0.79, 2_750.0),
    ):
        ping(
            china,
            at=CROSSFADE_SAMPLES + int(at * (LOOP_SAMPLES - CROSSFADE_SAMPLES)),
            frequency=frequency,
            seconds=0.22,
            strength=0.35,
        )

    return mixed(scaled(murmur, 1.0), scaled(room, 2.2), scaled(china, 0.3))


def white_noise(rng: random.Random) -> list[float]:
    """White noise tilted towards pink; true white is harsh over an hour."""
    source = white(rng, TOTAL_SAMPLES)
    return mixed(
        scaled(low_passed(source, 9_000.0), 0.55),
        scaled(low_passed(source, 1_200.0), 1.6),
    )


# Shipped from recordings instead.
RECORDED = {"forest", "cafe"}

BEDS = {
    "rain": rain,
    "forest": forest,
    "ocean": ocean,
    "cafe": cafe,
    "white_noise": white_noise,
}


# ── loop, level, file ───────────────────────────────────────────────────────


def wrapped(samples: list[float]) -> list[float]:
    """Cuts `samples` to one loop, crossfading the extra tail over the head.

    The tail is the material right after the loop, so the file's last and first
    samples end up adjacent. Equal-power (sin/cos) because a linear crossfade
    of uncorrelated noise dips 3 dB in the middle.
    """
    body = samples[:LOOP_SAMPLES]

    for index in range(CROSSFADE_SAMPLES):
        turn = 0.5 * math.pi * index / CROSSFADE_SAMPLES
        body[index] = (
            body[index] * math.sin(turn)
            + samples[LOOP_SAMPLES + index] * math.cos(turn)
        )

    return body


def normalised(samples: list[float]) -> list[int]:
    """Scales to `TARGET_RMS_DBFS`, capped at the peak ceiling, as 16-bit."""
    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    gain = (10 ** (TARGET_RMS_DBFS / 20)) / (rms or 1.0)

    peak = max(abs(sample) for sample in samples) * gain
    ceiling = 10 ** (PEAK_CEILING_DBFS / 20)
    if peak > ceiling:
        gain *= ceiling / peak

    return [int(max(-32_768, min(32_767, sample * gain * 32_767))) for sample in samples]


def write(path: pathlib.Path, samples: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SAMPLE_RATE)
        out.writeframes(struct.pack(f"<{len(samples)}h", *samples))
    print(f"wrote {path} ({path.stat().st_size / 1024:.0f} KB)")


def main() -> None:
    root = pathlib.Path(__file__).resolve().parent.parent
    written = 0

    for index, (name, bed) in enumerate(BEDS.items()):
        # Skipped inside the loop so the other beds keep their seeds.
        if name in RECORDED:
            continue
        samples = normalised(wrapped(bed(random.Random(0xA1B1E + index))))
        path = root / "assets" / "audio" / f"{name}.wav"
        write(path, samples)
        written += path.stat().st_size

    print(f"\n{written / 1024 / 1024:.2f} MB of ambience, against the 8 MB "
          f"for all the app's audio")


if __name__ == "__main__":
    main()
