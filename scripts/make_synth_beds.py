#!/usr/bin/env python3
"""Writes the synthesised ambient loops: rain, ocean and white noise.

PRD v2.2 §5.4: there is no sound designer, so these three beds are synthesised
here and ship as they are. Forest and café come from field recordings, written
by `make_recorded_sounds.py` (ticket 37); this script still knows how to
synthesise them — their seeds keep the other three byte-identical — but no
longer writes them. Nothing in the app names these files except
`lib/src/ambience/ambience.dart`.

Two things about the output are requirements rather than taste.

**The loop has no seam.** REQ-012 asks for beds that loop seamlessly and §4.4
budgets the join at under five milliseconds. That is not something a player can
fix after the fact, so it is built into the file: each bed is synthesised a
crossfade longer than it needs to be, and the tail is folded back over the head
with an equal-power crossfade. The last sample of the file is therefore the
sample immediately before the first one in the material both were cut from —
the waveform is continuous across the join, and the loudness is too, because
`sin² + cos² = 1` holds for the uncorrelated noise these beds are made of.

**They are WAV, not the AAC §5.4 asks for, and that is the whole reason the
join survives.** Every lossy codec pads the start of a stream with encoder
delay and the end with whatever is left of the final block, so a decoder
handed an AAC file loops it with tens of milliseconds of silence spliced in —
about ten times §4.4's budget — unless both the encoder and the player agree on
gapless metadata, which ExoPlayer and AVPlayer do not agree on. PCM has nothing
to pad, so `LoopMode.one` is sample-accurate on both platforms. The real assets
have to be delivered the same way or the seam requirement cannot be met: see
`docs/ambience.md`.

The five are deterministic — seeded per bed — so regenerating them produces
byte-identical files and a diff means somebody changed the synthesis.

Run from anywhere:

    python3 scripts/make_synth_beds.py
"""

from __future__ import annotations

import math
import pathlib
import random
import struct
import wave

# 44.1 kHz mono, 16-bit. Mono because a bed is atmosphere rather than a place —
# there is nothing in rain to point at — and because it halves a budget §5.4
# caps at 8 MB for all the audio in the app.
SAMPLE_RATE = 44_100

# How long one bed runs before it comes round again. Fifteen seconds is short
# for a café and ample for rain, and it is what the budget buys: five beds at
# 15 s is 6.3 MB of PCM, which leaves room for the chime and its Android copy
# under §5.4's 8 MB. The real recordings are specced at 60 s and will need a
# format that is smaller per second than PCM without being lossy.
LOOP_SECONDS = 15.0

# How much material is folded back over the head to hide the join. One second
# is long enough that no bed's slow movement is audible as a double, and short
# enough that a wave swell timed to the loop still lines up with itself.
CROSSFADE_SECONDS = 1.0

# Where every bed is normalised to, in dBFS RMS. The same number for all five
# on purpose: switching bed mid-session must not be a step change in loudness,
# and matching peaks would not achieve that — a café of transients and a wall
# of white noise with the same peak are nowhere near the same loudness.
TARGET_RMS_DBFS = -20.0

# The most any sample may reach after normalisation. Noise has a crest factor
# the RMS target does not bound, so this is what stops a stray droplet from
# clipping.
PEAK_CEILING_DBFS = -3.0

LOOP_SAMPLES = int(LOOP_SECONDS * SAMPLE_RATE)
CROSSFADE_SAMPLES = int(CROSSFADE_SECONDS * SAMPLE_RATE)
TOTAL_SAMPLES = LOOP_SAMPLES + CROSSFADE_SAMPLES


# ── the small pieces every bed is built from ────────────────────────────────


def white(rng: random.Random, count: int) -> list[float]:
    """`count` samples of white noise in [-1, 1]."""
    return [rng.uniform(-1.0, 1.0) for _ in range(count)]


def _coefficient(cutoff: float) -> float:
    """The one-pole coefficient for a filter turning over at `cutoff` Hz."""
    return 1.0 - math.exp(-2.0 * math.pi * cutoff / SAMPLE_RATE)


def low_passed(samples: list[float], cutoff: float) -> list[float]:
    """`samples` with everything above `cutoff` rolled off, one pole."""
    coefficient = _coefficient(cutoff)
    out = [0.0] * len(samples)
    state = 0.0
    for index, sample in enumerate(samples):
        state += coefficient * (sample - state)
        out[index] = state
    return out


def high_passed(samples: list[float], cutoff: float) -> list[float]:
    """`samples` with everything below `cutoff` removed.

    A one-pole low-pass subtracted from the signal, which is the cheapest
    high-pass there is and gentle enough that no bed sounds filtered.
    """
    return [
        sample - low
        for sample, low in zip(samples, low_passed(samples, cutoff))
    ]


def scaled(samples: list[float], by: float) -> list[float]:
    return [sample * by for sample in samples]


def mixed(*layers: list[float]) -> list[float]:
    return [sum(values) for values in zip(*layers)]


def cycles(count: int, at: int) -> float:
    """The phase, in radians, of something that repeats `count` times per loop.

    Every slow movement in these beds — a swell, an ebb in the murmur — is
    asked for in whole cycles per loop rather than in hertz, and that is what
    keeps it lined up with itself across the join. A wave at 0.2 Hz would meet
    the crossfade at whatever phase it happened to be in; three waves per loop
    meet it at the phase they started in.
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
    """Adds one short noise transient — a droplet, a footstep — into `into`."""
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
    """Adds one struck or sung tone — a cup, a bird — into `into`.

    `bend` is what the frequency is multiplied by over the length of the tone,
    which is the difference between a spoon on porcelain and a robin.
    """
    length = int(seconds * SAMPLE_RATE)
    tail = min(length, len(into) - at)
    phase = 0.0

    for index in range(tail):
        through = index / length
        step = frequency * (bend**through)
        phase += 2.0 * math.pi * step / SAMPLE_RATE
        # Fast in, slow out, and no attack transient — the same envelope the
        # wind chime is built from, for the same reason.
        envelope = min(index / 240.0, 1.0) * math.exp(-5.0 * through)
        into[at + index] += strength * envelope * math.sin(phase)


# ── the five beds ───────────────────────────────────────────────────────────


def rain(rng: random.Random) -> list[float]:
    """Steady rain: a band of hiss, with droplets landing on top of it."""
    # The body. Low-passed twice for a soft wall rather than a hiss, then the
    # rumble taken out — rain has no bottom octave, and leaving one in makes a
    # bed that fights every voice in the room.
    body = high_passed(
        low_passed(low_passed(white(rng, TOTAL_SAMPLES), 3_000.0), 3_000.0),
        400.0,
    )

    # Individual drops, close by. Sparse enough to be heard as drops rather
    # than as texture, which is the difference between rain and static.
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
    """Wind through leaves, and a few birds who are not in a hurry."""
    leaves = high_passed(low_passed(white(rng, TOTAL_SAMPLES), 1_400.0), 250.0)

    # The wind breathes. Two slow movements rather than one, so the bed does
    # not pulse at an obvious rate — and shallow, because a gust deep enough to
    # be noticed is a gust the ear starts timing, which is the seam the
    # crossfade cannot hide.
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
    # Placed clear of both ends: a chirp inside the crossfade would be folded
    # onto another one and heard as a stutter rather than a bird.
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
    """Three waves, breaking and drawing back.

    Three rather than a period in seconds: a whole number of waves per loop is
    what puts the swell at the same point in its cycle on both sides of the
    join.
    """
    WAVES = 3
    source = white(rng, TOTAL_SAMPLES)

    # A wave is brighter as it breaks and duller as it draws back, so the
    # cutoff rides the swell instead of standing still. Filtered by hand rather
    # than through `low_passed`, because the coefficient moves per sample.
    swell = [0.0] * TOTAL_SAMPLES
    state = 0.0
    for index, sample in enumerate(source):
        # 0 at the trough, 1 at the crest, squared so the draw-back is longer
        # than the break.
        height = (0.5 - 0.5 * math.cos(cycles(WAVES, index))) ** 2
        state += _coefficient(500.0 + 3_500.0 * height) * (sample - state)
        swell[index] = state * (0.18 + 0.82 * height)

    # The bottom is left in, unlike rain: the weight underneath a wave is most
    # of what makes it read as the sea rather than as wind.
    return high_passed(swell, 90.0)


def cafe(rng: random.Random) -> list[float]:
    """A room of people talking too far away to be understood, and china."""
    # Voices, as a band. Deliberately unintelligible — a bed with words in it
    # is a bed that costs attention rather than covering for it, which is the
    # opposite of what somebody starting a focus session asked for.
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

    # The room itself: the air handling, the traffic outside.
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
    """White noise with the top taken off it.

    Literally white is unpleasant for an hour — the ear hears equal energy per
    hertz as a hiss weighted towards the top of its range — so this is tilted
    towards pink, which is what people mean when they ask for white noise.
    """
    source = white(rng, TOTAL_SAMPLES)
    return mixed(
        scaled(low_passed(source, 9_000.0), 0.55),
        scaled(low_passed(source, 1_200.0), 1.6),
    )


# The beds whose shipped file comes from a recording (ticket 37).
RECORDED = {"forest", "cafe"}

BEDS = {
    "rain": rain,
    "forest": forest,
    "ocean": ocean,
    "cafe": cafe,
    "white_noise": white_noise,
}


# ── the join, the level, and the file ───────────────────────────────────────


def wrapped(samples: list[float]) -> list[float]:
    """`samples` cut to one loop, with the tail folded back over the head.

    The whole seam requirement is this function. `samples` is
    `CROSSFADE_SAMPLES` longer than the loop needs to be; the extra is the
    material immediately *after* the loop, and fading it in under the first
    second while the true first second fades out leaves a file whose last
    sample and first sample were adjacent in the material both came from.

    Equal power rather than equal amplitude — `sin` and `cos` of a quarter turn
    — because two uncorrelated noise signals crossfaded linearly dip by 3 dB in
    the middle, and a bed that ducks once every fifteen seconds has a seam even
    though it has no gap.
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
    """`samples` at `TARGET_RMS_DBFS`, under the ceiling, as 16-bit."""
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
        # Recorded, not synthesised: see make_recorded_sounds.py. Skipped
        # *inside* the loop so every other bed keeps its seed.
        if name in RECORDED:
            continue
        # Seeded per bed and by position, so every run of this script produces
        # the same files and a diff means the synthesis changed.
        samples = normalised(wrapped(bed(random.Random(0xA1B1E + index))))
        path = root / "assets" / "audio" / f"{name}.wav"
        write(path, samples)
        written += path.stat().st_size

    print(f"\n{written / 1024 / 1024:.2f} MB of ambience, against §5.4's 8 MB "
          f"for all the app's audio")


if __name__ == "__main__":
    main()
