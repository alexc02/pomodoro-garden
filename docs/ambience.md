# The ambient beds

REQ-012's six options — Rain, Forest, Ocean, Café, White Noise and Silence — and the two
things about them that are not obvious from the code: what format the audio has to be in,
and what about this ticket a workstation cannot check.

The decisions about the *audio session* are in
`docs/adr/0009-one-audio-session-with-two-uses.md`. This file is about the files.

> **PRD v2.2, ticket 37: these are the final sounds, and there is no sound designer.**
> Rain, ocean and white noise, the four chimes and the micro-sounds are synthesised
> (`scripts/make_synth_beds.py`, `make_synth_end_sounds.py`, `make_synth_micro_sounds.py`).
> **Forest, café and birdsong come from public-domain field recordings**
> (`scripts/make_recorded_sounds.py`, sources and checksums in ticket 29): the script finds
> the calmest stretch of each recording by measurement, nudges the loop's join to where the
> level is flat on both sides of it, folds the tail over the head as the synthesised beds
> do, and levels it with the other beds. Birdsong is a **blackbird**, not the robin §5.4
> named; the only CC0 robin was an unusable phonograph transfer.
>
> **The beds stay 15-second WAV, not the 20-second FLAC recommended below.** The seam tests
> in `test/ambience/bundled_audio_test.dart` read the beds as PCM to prove there is no click,
> gap or level step at the join; FLAC would need a decoder in the tests or tests that skip
> on a machine without ffmpeg. Five seconds of loop length was judged not worth either. If a
> bed sounds repetitive to a listener, the fallback is two layers of coprime length (PRD
> §5.4), not a longer file.

Where this file says "placeholder" below, read "synthesised": the analysis of formats,
seams and budget is unchanged.

## The seam is a property of the format, not of the player

PRD §5.4 specs the beds as "AAC, 60s loop" and §4.4 budgets the loop join at **under five
milliseconds**. Those two cannot both be met.

Every lossy codec pads what it encodes. AAC prepends encoder delay — 2112 samples for the
usual encoders, about **48 ms** at 44.1 kHz — and appends whatever it takes to fill the
final block. A decoder can skip the padding only if the container carries gapless metadata
*and* the player reads it. iTunes-style gapless atoms, Ogg's granule positions and
Android's `AAC` variants are three different mechanisms, and AVPlayer and ExoPlayer do not
agree on any of them. So an AAC loop under `LoopMode.one` joins itself with tens of
milliseconds of silence — roughly ten times the budget, and audible as a tick once a
minute for two hours.

**Uncompressed PCM has nothing to pad.** A WAV file's last sample is followed immediately
by its first, sample-accurately, on both platforms. So the loops ship as 16-bit mono WAV,
and that is why `ambientLoopAsset` says so in as many words.

The consequence for PRD §14's sound designer: **the real recordings must be delivered
lossless.** WAV or FLAC, mono, 44.1 kHz. Handing back AAC and expecting the app to loop it
seamlessly is asking for something neither platform does. How long they may be is decided
by the budget, and the arithmetic is below.

### What "seamless" is being checked against

`test/ambience/bundled_audio_test.dart` measures the join rather than trusting it. A seam
is one of three things, and all three are arithmetic:

| | What it sounds like | How it is measured |
|---|---|---|
| A discontinuity in the waveform | a click | the step from the last sample to the first, against the 99.9th percentile of the file's own neighbour steps |
| A fade at either end | a gap | the RMS of the first and last 50 ms, against the file's own RMS |
| A level difference across the join | a pulse once a loop | the RMS of the first 50 ms against the last 50 ms, in decibels |

What no test can check is whether the *material* is noticeably repetitive — a bird that
sings on the same beat every fifteen seconds is a loop the ear finds without any of the
above going wrong. That is a judgement about the recording, and it is the one thing the
placeholder loops are least likely to survive contact with a listener.

## The placeholders, and the budget

`scripts/make_synth_beds.py` synthesises the five, the same bargain the wind
chime and the plant sprites strike: something of the right shape behind the seam the real
asset arrives through. They are seeded, so regenerating them is byte-identical and a diff
means the synthesis changed.

Each is built a crossfade longer than it needs to be and folded back over its own head
with an equal-power crossfade — which is what makes the join continuous by construction
rather than by luck. Anything with slow movement in it (the ocean's swell, the forest's
gusting) moves in a **whole number of cycles per loop**, so it meets the fold at the phase
it started in.

§5.4 caps *all* the app's audio at 8 MB, and PCM is what makes that a live constraint:

| | |
|---|---|
| five beds, 15 s each, 16-bit mono 44.1 kHz | 6.31 MB |
| REQ-031's five end sounds, as Flutter assets — 16-bit mono 22.05 kHz | 0.80 MB |
| the same five again, as Android raw resources — AAC | 0.16 MB |
| §9.2's four UI micro-sounds — AAC, once each | 0.02 MB |
| **total** | **7.29 MB** |

The Android copies are counted because they ship: a notification channel's sound cannot
come from a Flutter asset. `LOOP_SECONDS` in the script is the dial that trades loop length
against this number, and `test/ambience/bundled_audio_test.dart` is what fails when it has
been turned too far.

### §5.4's sixty seconds and §5.4's 8 MB cannot both hold

This is worth stating plainly rather than leaving for whoever commissions the recordings,
because it is arithmetic and it does not improve. The budget leaves **7.3 MB** for five
loops once the chime's two copies are paid for — 1.46 MB each. At mono 44.1 kHz that buys:

| Format | Per second | Longest loop that fits |
|---|---|---|
| PCM, 16-bit | 88 kB | **16 s** |
| FLAC, 16-bit | ~66 kB (noise compresses badly — 75 % is optimistic) | **22 s** |
| PCM, 16-bit, 22.05 kHz | 44 kB | 33 s, at the cost of everything above 11 kHz |
| AAC, 128 kbps | 16 kB | 90 s — and a seam ten times over budget |

So the §5.4 row that says "AAC, 60s loop" is asking for the one thing that cannot loop
seamlessly, and every format that *can* is somewhere between three and four times the
budget at sixty seconds. **Loop length is what gives**, because it is the only one of the
three that is not a numbered requirement: §4.4 budgets the seam and §5.4 budgets the size,
and neither §5.4 nor any REQ specifies sixty seconds as a requirement — the number appears
once, in a table of source material.

The recommendation for the real assets, then: **FLAC, mono, 44.1 kHz, twenty seconds a
bed**, designed to loop — which is a longer and far better-sounding loop than what ships
today, inside the same budget. Anything longer needs the budget moved, and moving it is a
§5.4 decision rather than a sound-design one.

## The end sounds are not beds, and iOS is why they are still PCM

REQ-031's five one-shots share the budget above and share almost none of the reasoning.
**None of the seam argument applies to them.** A chime has no loop point — nothing joins it
to itself — so a codec's encoder delay lands harmlessly in a silence nobody hears, and
§5.4's "AAC" is the right answer rather than the impossible one it is for a loop.
`test/ambience/bundled_audio_test.dart`'s PCM assertion is written against
`AmbientSound.values` deliberately, and widening it to cover these would be spending the
beds' headroom to enforce a rule they are not subject to.

So the honest thing would be to ship them as AAC, and half of each one is:

| Copy | What it is for | Format |
|---|---|---|
| `assets/audio/end/<name>.wav` | played in the foreground, **and** copied into iOS's `Library/Sounds` | 16-bit mono PCM, 22.05 kHz |
| `android/app/src/main/res/raw/<name>.m4a` | the Android notification channel's sound | AAC, 96 kbps mono |

The asymmetry is iOS's rule, not a preference. **`UNNotificationSound` reads Linear PCM,
IMA/ADPCM, µLaw and aLaw, in WAV, AIFF or CAF, and nothing else** — an AAC file in
`Library/Sounds` is not rejected loudly, it is ignored, and the system default plays
instead. That is the sort of failure nobody finds from a desk: the sound is right in the
app and wrong on the notification, which is the half of REQ-031 a user only meets when they
are away from their phone. Android has no such rule, so the copy that can be compressed is.

The 22.05 kHz on the asset is the other half of the trade, and it is forced rather than
chosen: five one-shots at 44.1 kHz PCM put the bundle over §5.4's 8 MB on their own, in
every arrangement of the two copies. Nothing synthesised here has anything above 11 kHz to
lose — the highest partial in the set is the wind chime's, at 9.3 kHz.

**The consequence for §9.2's sound designer**, alongside the beds' one: the end sounds may
be delivered in any lossless format, but what ships as the Flutter asset has to end up
PCM in a WAV, mono, at 22.05 kHz or below unless the audio budget moves. Ship a stereo
44.1 kHz master by all means; the app needs the small mono one beside it.

## The micro-sounds are the easy case

§9.2's four UI micro-sounds — soil settle, growth shimmer, button tap, unlock, of which
§5.4 specs the first two — have neither
problem. They do not loop, so there is no seam; they never reach a notification, so
`UNNotificationSound` never sees them; and none of them is a user's choice, so there is no
row to store and no fallback to get right. **AAC, one copy each, 44.1 kHz, and all four
together are 25 kB** — which is a rounding error against a single bed and the reason they
are last in the budget table and first out of the argument.

`scripts/make_synth_micro_sounds.py` synthesises them. The one thing in there that is
a decision rather than arithmetic is the **loudness ramp**: they are peaked at −20, −16,
−15 and −12 dBFS, from the button tap up to the unlock, where the end sounds are all at −9.
A sound that accompanies something should sit under the thing it accompanies, and the tap
is the one that fires most often — a tap the user notices is a tap they will come to
resent.

**The consequence for §9.2's sound designer** is the mildest of the three: deliver these
however is convenient, mono, at or under the durations §5.4 names, and mixed well below the
end sounds. Nothing else about them is constrained.

## What a workstation cannot verify

This machine has no iOS device, no Android device and no emulator. Everything below is
asserted as far as Dart can assert it and is **unwitnessed on a phone**.

| | Asserted here | Unwitnessed |
|---|---|---|
| Playback behind a locked screen | `UIBackgroundModes: audio` and the `playback` category, in `test/platform/background_audio_test.dart` | that iOS honours them for the length of a two-hour session |
| The loop seam | click, gap and level, against the files | that a listener does not hear the loop |
| A phone call | every decision, in `test/ambience/audio_interruptions_test.dart` | that the platform sends the interruption events at all |
| Headphones unplugged | the same | that `becomingNoisy` fires on both platforms for a Bluetooth disconnect as well as a jack |
| The chime over the bed | that the bed is stopped at the same moment the chime plays | that the fade is enough to hear it over |
| REQ-031's choice on the notification | which channel, which resource and which iOS file each sound is posted with, in `test/notifications/completion_details_test.dart` | that Android creates a channel per sound and keeps each one's, and that iOS finds the WAV in `Library/Sounds` |
| **None** being silent | that neither platform is handed a sound, and that the notice is still posted at the same importance | that a silent channel still shows the notification |

**Android has one gap of its own.** Nothing keeps the process alive for the bed. iOS gets
that from the background mode; on Android what keeps a backgrounded app running is ticket
08's foreground service, which is on by default but which the user can turn off with
REQ-033's switch. A user who turns off the lock-screen surface *and* backgrounds a session
with a bed under it is relying on Android not reclaiming the process — which it usually
does not for an app holding audio focus and playing, but which it does not promise.
Closing that properly means either tying the bed to the foreground service — coupling two
features the user is offered separately — or adding `just_audio_background` and its second
notification. Neither is this ticket's call to make; it is recorded here for whoever owns
ticket 24.
