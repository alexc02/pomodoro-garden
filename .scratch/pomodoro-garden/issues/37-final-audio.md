# 37 — The final audio

**What to build:** all 14 sound files in their final form, replacing the synthesised placeholders. PRD v2.2 §5.4, §9.2 and §8.1.1, step 10.

| Sound | Source | Format |
|---|---|---|
| Wind chime, soft bell, singing bowl, ocean wave (end) | synthesised | PCM WAV, mono, 22.05 kHz + AAC copy as an Android raw resource |
| Birdsong (end) | ticket 29: CC0 recording, or synthesised | same |
| Rain, ocean, white noise (beds) | synthesised | ~~FLAC, 20 s~~ **PCM WAV, mono, 44.1 kHz, 15 s** (see below), built to loop |
| Forest, café (beds) | ticket 29: CC0 recording, or synthesised | same |
| Soil settle, growth shimmer, button tap, unlock (micro) | synthesised | AAC |

**Blocked by:** 29.

**Status:** done. The owner listened to every sound on 2026-10-11 and approved them, after two rounds on soil settle (below). Listening page (private to the owner): https://claude.ai/code/artifact/ecec465a-a790-4e28-9bf9-e719373fbedc

- [x] The synthesis scripts in `scripts/` ~~upgraded from placeholder quality~~ **kept as they were and renamed as final**, still deterministic. *Not upgraded: the synthesis was already built to the seam, level and budget rules, and with no one here to listen there was no basis for changing it. The owner's listening pass is where any of them gets reworked*
- [x] Recordings from ticket 29 processed: trimmed, loop points chosen at zero crossings with a short crossfade baked into the file, normalised to the same loudness as the synthesised beds
- [x] ~~Beds switch from WAV to FLAC~~ **Decided against (owner informed):** the beds stay 15 s PCM WAV, so the seam tests keep reading them directly. Was: `ambientLoopAsset`, `bundled_audio_test.dart`'s format assertion and `docs/ambience.md` updated. Confirm `just_audio` plays FLAC on both platforms and loops it with no gap
- [x] End sounds stay PCM for iOS notifications; the Android AAC copies are regenerated from the same sources
- [x] Total audio under 8 MB, enforced by the existing test
- [x] The loop seam measured three ways against every bed, as `docs/ambience.md` describes, and passing
- [x] **Owner listens** to every bed for audible repetition. *Done 2026-10-11: no bed sounds repetitive, the café's clinks included; no layering needed.* Original: **Fallback:** a bed that sounds looped is built from two layers of coprime length (e.g. 17 s and 23 s), with a second player for that bed only; record which beds needed it
- [x] Ticket 24's loop-seam criterion annotated with the result
- [x] `flutter analyze --fatal-infos` clean; app and domain suites green (1002 app tests with the final audio; 68 audio and micro-sound tests after the micro-sound fix)

## What was built

| Where | What |
|---|---|
| `scripts/make_recorded_sounds.py` | **New.** Fetches the three originals into a cache (one folder each), refuses any whose SHA-256 differs from ticket 29's record, decodes them with ffmpeg (never executes them), finds the calmest window by measurement (the 15 s whose loudest moment stands least above its level and whose level wanders least), nudges the start in 10 ms steps until the level either side of the join matches, folds the tail over the head exactly as the synthesised beds do, and levels the result to the same −20 dBFS RMS with peaks rounded off rather than clipped. Birdsong: one blackbird phrase found by its onset after 13 s, high-passed at 1.2 kHz, faded in over 10 ms and out over 0.6 s, as WAV and as the Android AAC copy |
| `scripts/make_synth_beds.py`, `make_synth_end_sounds.py`, `make_synth_micro_sounds.py` | Renamed from `make_placeholder_*` (their output is now final). The beds script skips forest and café *inside* its loop, so rain, ocean and white noise keep their seeds and stay byte-identical; the end-sounds script skips birdsong |
| `assets/audio/cafe.wav` | From 1089.6 s into "Cafe ambiance.ogg"; 0.00 dB across the join |
| `assets/audio/forest.wav` | From 17.97 s into "20090610 0 ambience.ogg", before the crows; 0.01 dB across the join |
| `assets/audio/end/birdsong.wav`, `res/raw/birdsong.m4a` | A blackbird phrase, ~2.3 s plus its fade |
| `docs/ambience.md`, `PRD.md` §5.4 | The recordings, and the WAV decision |

**Found while building it:** the first café loop stepped 3.3 dB across its join. The join
was continuous (the crossfade guarantees that), but it fell on a swell in the murmur, which
would repeat every 15 s as a faint pulse. `bundled_audio_test.dart`'s 1 dB check caught it;
the nudge fixed it.

**Kept the beds as WAV, not FLAC.** The seam tests read the beds as PCM. FLAC would have
needed a decoder written into the tests, or tests that skip without ffmpeg. Five seconds of
loop length was not worth either. The owner was told.

**What repeats:** the café loop carries four faint cup clinks every 15 s. It is the calmest
window in twenty minutes of recording; whether it is noticeable is the listening pass's
question, and the layering fallback is the answer if it is.

**Tests:** all 50 audio tests pass (seam: no click, no gap, no level step; beds level with
each other; inside the 8 MB budget).

**Verification gap:** nobody has listened yet (the owner, on the page above); and on a phone,
whether `just_audio` loops a WAV with no gap on both platforms (ticket 39).

## The owner's listening pass, and two sounds redone

On 2026-10-11 the owner reported **soil settle and button tap made no sound**; everything
else, the five beds included, was good.

Both files were valid and played; both were nearly inaudible by design, especially through
a phone or laptop speaker, which reproduces little below ~300 Hz:

| | Before | After |
|---|---|---|
| Soil settle | thud at 140 Hz, peak −17 dB, −23 dB above 300 Hz | thud at 260 Hz with its octave, brighter and louder grains, peak −10.5 dB, **−14 dB above 300 Hz** |
| Button tap | 320/787 Hz, 9 ms, 50 ms file, peak −20 dB | 950/2330 Hz, 14 ms, 80 ms file with trailing silence, peak −13 dB, **−13 dB above 300 Hz** |

For comparison, growth shimmer, which the owner heard, sits at −15 dB above 300 Hz. Button
tap stays the quietest sound in the app, because it plays most often. The other two
micro-sounds regenerate byte-identical. The same problem would have hit the app on a phone,
so this is a fix to the files, not to the page.

**The listening page itself also failed at first:** it played through the Web Audio
engine, which can stay silent inside the artifact viewer's sandbox and is muted by an
iPhone's silent switch. It now uses standard audio players.

## Soil settle, a third time

The owner found the louder second version still "doesn't sound so good". Rather than guess
again, three takes were offered side by side: **A · Soft pat** (pitchless band-passed noise
with crumbs and a short room), **B · Puff of earth** (a breathy puff darkening as it fades)
and **C · Wooden seed** (a soft muted pluck). **The owner chose A.**

The probable fault in the first two was the pitched sine at their core, which reads as a
cartoon *bloop*. A has no pitch, so it also cannot clash with the bed playing under it. It
now lives in `scripts/make_synth_micro_sounds.py` (`soil_settle`, with an RBJ biquad
helper); the shipped file decodes sample-for-sample identical to the take the owner heard,
and the other three micro-sounds are unchanged. Peak −11 dB, −11.8 dB above 300 Hz.
