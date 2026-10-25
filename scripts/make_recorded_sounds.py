#!/usr/bin/env python3
"""Writes the three sounds the app takes from field recordings (ticket 37).

PRD v2.2 §5.4: there is no sound designer. Rain, ocean, white noise and the
chimes are synthesised (`make_synth_beds.py`, `make_synth_end_sounds.py`); the
three that synthesis does badly come from public-domain recordings, chosen and
recorded in ticket 29:

  café     assets/audio/cafe.wav     bed, from "Cafe ambiance.ogg" (CC0)
  forest   assets/audio/forest.wav   bed, from "20090610 0 ambience.ogg" (PD)
  birdsong assets/audio/end/birdsong.wav and
           android/app/src/main/res/raw/birdsong.m4a
                                     end sound, from "Turdus merula 2.ogg" (PD)

Each original is fetched into a cache (`--cache`, default
`~/.cache/pip-garden-sounds`), one empty folder per file, and **refused
unless its SHA-256 matches** the one ticket 29 recorded. The files are
untrusted data: they are decoded by ffmpeg into raw samples and never run.

The beds follow every rule `make_synth_beds.py` follows, because the same tests
hold them to it (`test/ambience/bundled_audio_test.dart`): 44.1 kHz mono 16-bit
PCM, fifteen seconds, a one-second equal-power crossfade folding the material
after the loop back over its head so the join has no click and no gap, and the
same RMS as every other bed. Which fifteen seconds is decided by measurement:
the window whose loudness moves least and whose loudest moment stands least
above its average — the window with the fewest *events*, which is what a loop
the ear does not notice is made of.

Needs `ffmpeg` on PATH. Run from anywhere:

    python3 scripts/make_recorded_sounds.py
"""

from __future__ import annotations

import argparse
import hashlib
import math
import pathlib
import shutil
import struct
import subprocess
import sys
import urllib.request
import wave

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import make_synth_beds as beds  # noqa: E402  (the shared loop rules)

USER_AGENT = "PipGardenSoundSourcing/1.0"

SOURCES = {
    "cafe": (
        "https://upload.wikimedia.org/wikipedia/commons/5/54/Cafe_ambiance.ogg",
        "6360791fdcee1f64638f0fc9abd6d2c7a1aa75fd3d2b80033170a02d025099dc",
    ),
    "forest": (
        "https://upload.wikimedia.org/wikipedia/commons/0/0a/20090610_0_ambience.ogg",
        "43848c3eda5f42829f1033112c2a91ba3e5c91b79a0532fda264c9f59856d431",
    ),
    "blackbird": (
        "https://upload.wikimedia.org/wikipedia/commons/7/7c/Turdus_merula_2.ogg",
        "2e713300a07d50b9cad26bb0f7b5d5bdce148ab062b56922ee3dd95fab54ec9f",
    ),
}

# Where in each recording a loop may be cut from, in seconds. The forest file
# turns to a pulsing crow call after ~45 s (ticket 29); the café is steady for
# its whole twenty minutes.
SEARCH = {"cafe": (0.0, 1195.0), "forest": (0.0, 44.0)}

# How the window search measures a candidate: 100 ms blocks, analysed at 8 kHz
# (fast, and plenty to hear a clink or a call), stepping half a second.
ANALYSIS_RATE = 8_000
BLOCK_SECONDS = 0.1
STEP_SECONDS = 0.5

# Below this the recordings carry only rumble: traffic, handling, wind on the
# microphone.
HIGH_PASS_HZ = {"cafe": 90, "forest": 120, "blackbird": 1_200}

# The end sounds' rules, from `make_synth_end_sounds.py`.
END_RATE = 22_050
END_PEAK_DBFS = -9.0
AAC_BITRATE = "96k"


def fetch(name: str, cache: pathlib.Path) -> pathlib.Path:
    """The original for `name`, downloaded once and checked every time."""
    url, expected = SOURCES[name]
    folder = cache / name
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / url.rsplit("/", 1)[-1]
    if not path.exists():
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=120) as response:
            path.write_bytes(response.read())
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected:
        path.unlink()
        raise SystemExit(
            f"{path.name} does not match the checksum ticket 29 recorded "
            f"({digest} != {expected}). It has been deleted; nothing was written."
        )
    return path


def decode(
    path: pathlib.Path,
    rate: int,
    *,
    start: float = 0.0,
    seconds: float | None = None,
    high_pass: int | None = None,
) -> list[float]:
    """`path` as mono floats at `rate`, optionally a slice of it."""
    command = ["ffmpeg", "-loglevel", "error", "-ss", f"{start}"]
    if seconds is not None:
        command += ["-t", f"{seconds}"]
    command += ["-i", str(path), "-ac", "1", "-ar", str(rate)]
    if high_pass:
        command += ["-af", f"highpass=f={high_pass}"]
    command += ["-f", "s16le", "-"]
    raw = subprocess.run(command, check=True, capture_output=True).stdout
    count = len(raw) // 2
    return [s / 32_768 for s in struct.unpack(f"<{count}h", raw[: count * 2])]


def calmest_window(name: str, path: pathlib.Path) -> float:
    """Where the loop starts: the window with the fewest events in it."""
    lo, hi = SEARCH[name]
    samples = decode(path, ANALYSIS_RATE, start=lo, seconds=hi - lo,
                     high_pass=HIGH_PASS_HZ[name])
    block = int(BLOCK_SECONDS * ANALYSIS_RATE)
    levels = [
        math.sqrt(sum(x * x for x in samples[i:i + block]) / block) + 1e-9
        for i in range(0, len(samples) - block, block)
    ]
    span = int((beds.LOOP_SECONDS + beds.CROSSFADE_SECONDS) / BLOCK_SECONDS)
    step = int(STEP_SECONDS / BLOCK_SECONDS)

    best, best_score = 0, math.inf
    for first in range(0, len(levels) - span, step):
        window = levels[first:first + span]
        mean = sum(window) / len(window)
        # How far the loudest moment stands above the window's own level, and
        # how much the level wanders: an event and a swell, in decibels.
        spike = 20 * math.log10(max(window) / mean)
        wander = 20 * math.log10(
            sorted(window)[int(0.9 * len(window))]
            / sorted(window)[int(0.1 * len(window))]
        )
        score = spike + 0.5 * wander
        if score < best_score:
            best, best_score = first, score

    start = lo + best * BLOCK_SECONDS
    print(f"{name}: loop from {start:.1f} s (event score {best_score:.2f} dB)")
    return start


# How far either way the loop's start may be nudged to find a flat join, and in
# what steps.
NUDGE_SECONDS = 2.0
NUDGE_STEP_SECONDS = 0.01

# The level either side of the join is compared over this long — the same
# window `bundled_audio_test.dart` uses.
JOIN_WINDOW_SECONDS = 0.05


def join_step_db(material: list[float], offset: int) -> float:
    """How far the loop cut from `material` at `offset` would step in level
    across its join, in dB — what `wrapped` would make of it, computed for the
    two short windows either side of the join only.
    """
    n = int(JOIN_WINDOW_SECONDS * beds.SAMPLE_RATE)
    loop, fade = beds.LOOP_SAMPLES, beds.CROSSFADE_SAMPLES

    def rms(values: list[float]) -> float:
        return math.sqrt(sum(v * v for v in values) / len(values)) + 1e-12

    head = []
    for i in range(n):
        turn = 0.5 * math.pi * i / fade
        head.append(
            material[offset + i] * math.sin(turn)
            + material[offset + loop + i] * math.cos(turn)
        )
    tail = material[offset + loop - n:offset + loop]
    return abs(20 * math.log10(rms(head) / rms(tail)))


def softened(samples: list[float], ceiling: float) -> list[float]:
    """`samples` with peaks above `ceiling` rounded off rather than clipped.

    A recording has a crest factor no RMS target bounds: one clink in a café
    would otherwise pull the whole bed's gain down to keep it under the
    ceiling, and leave it quieter than the other four.
    """
    knee = ceiling * 0.6
    out = []
    for x in samples:
        magnitude = abs(x)
        if magnitude > knee:
            over = (magnitude - knee) / (ceiling - knee)
            magnitude = knee + (ceiling - knee) * math.tanh(over)
        out.append(math.copysign(magnitude, x))
    return out


def make_bed(name: str, cache: pathlib.Path, root: pathlib.Path) -> None:
    path = fetch(name, cache)
    start = calmest_window(name, path)
    # The calm window, with room either side to nudge the join into a moment
    # where the level is flat: a murmur rises and falls by a few decibels over
    # a tenth of a second, and a join placed on a rise repeats it as a pulse.
    earliest = max(SEARCH[name][0], start - NUDGE_SECONDS)
    material = decode(
        path,
        beds.SAMPLE_RATE,
        start=earliest,
        seconds=beds.LOOP_SECONDS + beds.CROSSFADE_SECONDS + 2 * NUDGE_SECONDS,
        high_pass=HIGH_PASS_HZ[name],
    )
    step = int(NUDGE_STEP_SECONDS * beds.SAMPLE_RATE)
    offsets = range(0, len(material) - beds.TOTAL_SAMPLES, step)
    if not offsets:
        raise SystemExit(f"{name}: the recording ran out before the loop did")
    offset = min(offsets, key=lambda o: join_step_db(material, o))
    print(f"{name}: join nudged to {earliest + offset / beds.SAMPLE_RATE:.2f} s, "
          f"{join_step_db(material, offset):.2f} dB across it")

    loop = beds.wrapped(material[offset:offset + beds.TOTAL_SAMPLES])
    # Level first, then round off what would cross the ceiling, then level
    # again: the second pass is a fraction of a decibel.
    rms = math.sqrt(sum(x * x for x in loop) / len(loop))
    target = 10 ** (beds.TARGET_RMS_DBFS / 20)
    loop = [x * target / rms for x in loop]
    loop = softened(loop, 10 ** (beds.PEAK_CEILING_DBFS / 20))
    beds.write(root / "assets" / "audio" / f"{name}.wav", beds.normalised(loop))


def make_birdsong(cache: pathlib.Path, root: pathlib.Path) -> None:
    """One blackbird phrase, about three seconds: REQ-031's birdsong."""
    path = fetch("blackbird", cache)
    whole = decode(path, END_RATE, high_pass=HIGH_PASS_HZ["blackbird"])

    # Find the phrase that starts after 13 s (ticket 29: the cleanest of the
    # four), by where the level first rises well above the quiet between them.
    block = int(0.02 * END_RATE)
    levels = [
        math.sqrt(sum(x * x for x in whole[i:i + block]) / block)
        for i in range(0, len(whole) - block, block)
    ]
    quiet = sorted(levels)[len(levels) // 4]
    after = int(13.0 * END_RATE / block)
    onset = next(i for i in range(after, len(levels)) if levels[i] > quiet * 8)

    first = max(0, onset * block - int(0.08 * END_RATE))
    length = int(3.0 * END_RATE)
    phrase = whole[first:first + length]

    # A breath in, and a long fade out: the phrase ends, it is not cut off.
    fade_in = int(0.01 * END_RATE)
    fade_out = int(0.6 * END_RATE)
    shaped = []
    for i, x in enumerate(phrase):
        gain = min(1.0, i / fade_in)
        from_end = len(phrase) - i
        if from_end < fade_out:
            gain *= 0.5 - 0.5 * math.cos(math.pi * from_end / fade_out)
        shaped.append(x * gain)

    peak = max(abs(x) for x in shaped)
    scale = 10 ** (END_PEAK_DBFS / 20) / peak
    pcm = [int(max(-32_768, min(32_767, x * scale * 32_767))) for x in shaped]

    wav = root / "assets" / "audio" / "end" / "birdsong.wav"
    with wave.open(str(wav), "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(END_RATE)
        out.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))
    print(f"wrote {wav} ({wav.stat().st_size / 1024:.0f} KB)")

    m4a = root / "android" / "app" / "src" / "main" / "res" / "raw" / "birdsong.m4a"
    subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y", "-i", str(wav),
         "-c:a", "aac", "-b:a", AAC_BITRATE, "-ac", "1", str(m4a)],
        check=True,
    )
    print(f"wrote {m4a} ({m4a.stat().st_size / 1024:.0f} KB)")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--cache",
        type=pathlib.Path,
        default=pathlib.Path.home() / ".cache" / "pip-garden-sounds",
    )
    args = parser.parse_args()
    if shutil.which("ffmpeg") is None:
        raise SystemExit("ffmpeg is not on PATH; it decodes the recordings.")

    root = pathlib.Path(__file__).resolve().parent.parent
    make_bed("cafe", args.cache, root)
    make_bed("forest", args.cache, root)
    make_birdsong(args.cache, root)


if __name__ == "__main__":
    main()
