# Audio notes

Six ambient options: Rain, Forest, Ocean, Café, White Noise and Silence. Rain, ocean,
white noise, the end chimes and the UI micro-sounds are synthesised by the scripts in
`scripts/`. Forest, café and birdsong come from public-domain field recordings
(`scripts/make_recorded_sounds.py` has the sources and checksums). The script picks the
calmest stretch of each recording, moves the loop point to where the level is flat, and
crossfades the tail into the head. The birdsong is a blackbird.

## Why the loops are WAV

Every lossy codec pads the audio. AAC adds about 2112 samples of encoder delay (~48 ms at
44.1 kHz) plus padding at the end. Gapless playback needs metadata in the container and a
player that reads it, and AVPlayer and ExoPlayer don't agree on any format for that. An
AAC loop under `LoopMode.one` ends up with a few tens of ms of silence at the join, which
you hear as a tick every loop.

PCM has no padding, so the loops are 16-bit mono 44.1 kHz WAV. Any replacement recordings
need to be lossless too.

`test/ambience/bundled_audio_test.dart` checks each join for:

- a click: the step from last sample to first, against the file's own 99.9th percentile
- a gap: RMS of the first and last 50 ms against the whole file
- a level jump: RMS of the first 50 ms vs the last 50 ms

It can't tell you whether a loop sounds repetitive. That needs a listen.

The synthesised beds are seeded, so regenerating them gives identical bytes. Each one is
rendered a crossfade longer than needed and folded back over its own start with an
equal-power crossfade. Anything slow (ocean swell, wind) completes a whole number of
cycles per loop so it meets the join in phase.

## Size budget

All audio has to fit in 8 MB, which is what limits loop length:

| | |
|---|---|
| five beds, 15 s, 16-bit mono 44.1 kHz | 6.31 MB |
| five end sounds as Flutter assets, 16-bit mono 22.05 kHz | 0.80 MB |
| the same five as Android raw resources, AAC | 0.16 MB |
| four UI micro-sounds, AAC | 0.02 MB |
| total | 7.29 MB |

`LOOP_SECONDS` in `make_synth_beds.py` sets the loop length, and the audio test fails if
it pushes the total over budget. For reference, at 1.46 MB per bed:

| Format | Longest loop |
|---|---|
| PCM 16-bit 44.1 kHz | ~16 s |
| FLAC | ~22 s |
| PCM 22.05 kHz | ~33 s (loses everything above 11 kHz) |
| AAC 128 kbps | ~90 s, but won't loop cleanly |

FLAC at 20 s would be nicer, but the seam tests read PCM directly and I didn't want them
to depend on ffmpeg. If a bed starts to sound repetitive, layering two loops of coprime
lengths is probably a better fix than a longer file.

## End sounds

The end-of-session chimes don't loop, so encoder delay doesn't matter for them. There are
two copies of each:

| File | Used for | Format |
|---|---|---|
| `assets/audio/end/<name>.wav` | in-app playback, and copied to iOS `Library/Sounds` | 16-bit mono PCM, 22.05 kHz |
| `android/app/src/main/res/raw/<name>.m4a` | Android notification channel sound | AAC 96 kbps mono |

iOS `UNNotificationSound` only accepts Linear PCM, IMA/ADPCM, µLaw or aLaw in
WAV/AIFF/CAF. An AAC file in `Library/Sounds` is silently ignored and the default sound
plays instead. 22.05 kHz is there to stay under budget. The highest partial in any of
them is about 9.3 kHz, so nothing is lost.

## Micro-sounds

Soil settle, growth shimmer, button tap and unlock. AAC, one copy each, 25 kB total. They
peak at -20, -16, -15 and -12 dBFS (tap up to unlock), well below the end sounds at -9.
The tap fires the most, so it's the quietest.

## Not verified on a device yet

| | Covered by tests | Still needs a phone |
|---|---|---|
| Playback with the screen locked | `UIBackgroundModes: audio`, `playback` category | that iOS keeps it going for a 2-hour session |
| Loop seam | click/gap/level on the files | that it actually sounds seamless |
| Phone call interruption | `audio_interruptions_test.dart` | that the platform sends the events |
| Headphones unplugged | same | that `becomingNoisy` fires for Bluetooth as well as wired |
| Chime over the bed | bed stops when the chime plays | that it's audible |
| Chosen sound on the notification | `completion_details_test.dart` | Android channel per sound, iOS finding the WAV |
| "None" end sound | no sound is passed, importance unchanged | that a silent channel still shows the notification |

Known Android gap: nothing keeps the process alive just for the bed. Normally the
foreground service does, but the user can turn off the live surface. With that off and a
bed playing in the background, the app relies on Android not killing a process that holds
audio focus. That usually works but isn't guaranteed. Fixing it means either tying the bed
to the foreground service or adding `just_audio_background`, which adds a second
notification.
