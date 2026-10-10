# 10 — Ambient background sounds

> ⚠️ **Amended by the v2.1 decision that the app is free.**
> The last acceptance criterion — *free users get 3 of the 6, the remaining 3 marked
> premium* — no longer holds and is not owed. All six beds are offered, unmarked;
> `AmbientSound.premium`, `.free` and `.premiumOnly` are gone, as is the line under
> the chips that explained the marks.
> See `docs/adr/0021-the-app-is-free-and-sells-nothing.md` and PRD §3.6.

**What to build:** The user picks Rain, Forest, Ocean, Café, White Noise or Silence from the active session screen, and it plays seamlessly for the whole session — through backgrounding and screen lock — creating an atmosphere without a single audible loop seam.

All audio is bundled; there is no streaming. Placeholder loops are acceptable if final audio is not ready, provided the seam requirement is met by the final assets.

Built on **`just_audio` + `audio_session`**. The second package is not optional decoration — it configures the iOS `AVAudioSession` category and Android audio focus, which is what makes the interruption, ducking and route-change criteria below achievable rather than accidental.

**Blocked by:** 06, 03

**Status:** done — every criterion is built and covered as far as a workstation can cover it. Five are qualified, and all five for the same reason ticket 06's and 09's were: **this machine has no iOS device, no Android device and no emulator**, so nothing here has been heard. What could be moved off the device *was* — the loop seam is measured against the files, the audio-session categories are asserted against the configuration, and every interruption and route-change decision is a unit test — but whether a phone plays it is unwitnessed. The Dart side is 35 app tests and 13 domain tests on top of the 369 + 209 the suite already ran green. One finding is the product's rather than the code's, and it is written up under **§5.4 asks for two things that cannot both be true** below.

- [x] Six options selectable from the active session screen, changeable mid-session without a gap or restart
- [~] Loops are seamless — no audible click, gap or level jump at the loop point on either platform — **all three failure modes are measured against the shipped files rather than trusted (`test/ambience/bundled_audio_test.dart`): the step across the join against the file's own 99.9th-percentile step, the level either side of it in decibels, and that neither end fades. What no test can hear is whether the *material* repeats noticeably, which is a judgement about the recording rather than the join**
- [~] Playback continues when the app is backgrounded and the screen is locked, and stops when the session ends or is cancelled — **the stopping half is fully tested, by every route out of a session. The continuing half is a platform configuration asserted where it lives (`UIBackgroundModes: audio` plus the `playback` category) and unwitnessed on a device. Android has a real gap of its own — see below**
- [~] The end-of-session chime is audible over the ambient bed — duck or fade the ambience rather than letting them fight — **the bed fades out in under a second while the chime rings for four, and the audio session is held on the bed's category until the chime has finished so its tail is not re-categorised mid-note. Whether the fade is enough to hear over is an ear**
- [~] Behaves correctly against other audio: interrupted by a phone call and resuming afterwards, and honouring the user's choice when music is already playing — **every decision is a unit test, including two interruptions at once. "Honouring the user's choice" is read as: they picked rain over the music, from a picker showing them what they were choosing, so the bed takes the audio and Silence hands it straight back. What is unwitnessed is whether the platform sends the events**
- [~] Route changes mid-session (headphones unplugged, Bluetooth disconnect) do not crash or orphan playback — **unplugging holds the bed and plugging back in starts it again, both tested as decisions. Same device gap**
- [x] Selection persists as the default for the next session
- [x] Total bundled audio stays within the §5.4 budget of 8 MB — **6.98 MB, asserted by a test that weighs every file that ships, including the chime's second Android copy**
- [x] Free users get 3 of the 6; the remaining 3 are marked premium but remain unlocked until ticket 18 lands the entitlement

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/settings/ambient_sound.dart` | `AmbientSound` — the six, the free/premium split, and the fallback for a name this build does not know |
| `packages/pomodoro_domain/lib/src/settings/garden_settings.dart` | `ambientSound`, defaulting to silence — the setting a running session reads and a finished one leaves behind |
| `lib/src/audio/app_audio_session.dart` | The one audio session and its two uses. `useFor` for the bed, `ensureConfigured` for the chime — see ADR 0009 |
| `lib/src/ambience/ambience.dart` | The port, and the only place a loop file is named |
| `lib/src/ambience/bundled_ambience.dart` | Two `just_audio` players, crossfaded past each other; queued calls; equal-power fades |
| `lib/src/ambience/audio_interruptions.dart` | What a call, a duck or a yanked cable does to the bed — decisions with no player in them, so they can be tested |
| `lib/src/ambience/ambience_keeper.dart` | Keeps the bed in step with the session and the setting, the way `LiveSurfaceKeeper` keeps the lock screen |
| `lib/src/features/timer/ambience_picker.dart` | The six chips, on the screen the session runs on, with the premium three marked |
| `lib/src/feedback/bundled_end_sound.dart` | Moved onto the shared session; names no category any more |
| `scripts/make_placeholder_ambience.py` | Five seamless-by-construction loops, seeded so a diff means the synthesis changed |
| `ios/Runner/Info.plist` | `UIBackgroundModes: audio` |
| schema v9 | `settings.ambient_sound`, defaulting to `'silence'` |
| `docs/adr/0009-…` | One audio session, with two uses |
| `docs/ambience.md` | The format argument, the budget arithmetic, and what a workstation cannot verify |

## Four things worth knowing before picking up a dependent ticket

**§5.4 asks for two things that cannot both be true, and this is the ticket that found
out.** The spec says the beds are "AAC, 60s loop"; §4.4 budgets the loop join at under
five milliseconds; §5.4 caps all the app's audio at 8 MB. Every lossy codec pads what it
encodes — AAC prepends about 48 ms of encoder delay — and no gapless mechanism is honoured
by both AVPlayer and ExoPlayer, so **an AAC loop cannot meet the seam budget at all**. Go
lossless and sixty seconds is three to four times the size budget. Loop length is the only
one of the three that is not a numbered requirement, so loop length is what gave: the
placeholders are 15 s, and the recommendation for the real recordings is **FLAC, mono,
44.1 kHz, twenty seconds** — a longer and much better loop than what ships, inside the
same 8 MB. The arithmetic is in `docs/ambience.md`. Anything longer is a §5.4 decision, not
a sound-design one.

**There is one audio session, and it is not a feature's to configure.** iOS has one
`AVAudioSession` per process and Android one focus request per app, so the chime and the
bed were never two configurations — they were one, and whichever called `configure` last
would win. Ticket 06's `BundledEndSound` set it directly; it no longer does. The rule is
now a sentence — *the silent switch wins unless the user has asked for a bed* — and it
lives in `AppAudioSession`. **A later ticket that plays anything adds a third `AudioUse`
there rather than a `configure` call of its own.** ADR 0009 is the argument.

**The bed belongs to a focus session, running or held — and to nothing else.** A pause
keeps it, because a pause is the user stepping away from the desk rather than out of the
hour, and a bed that stopped and restarted around a two-minute interruption would put in
the gap this ticket exists to forbid. A break has no bed, because the rest of that screen
already says a break is not the session — sky ring, bare soil, nothing growing — and rain
carrying on through it would say the opposite. Ticket 11's quiet mode inherits a bed that
is already tied to the session's phase and nothing else.

**Android has a gap this ticket could not close, and it is ticket 24's.** iOS keeps the
process alive for background audio because of the `UIBackgroundModes` key. Android has no
equivalent: what keeps a backgrounded app running is ticket 08's foreground service, which
the user can turn off with REQ-033's switch. Turn it off, start a session with a bed, put
the phone away, and the bed plays only for as long as Android chooses not to reclaim the
process — which it usually does not for an app holding audio focus, but which it does not
promise. Closing it means either tying the bed to a service the user was offered
separately, or adding `just_audio_background` and a second ongoing notification. Both are
decisions about what the user is shown, and neither belonged to this ticket.
