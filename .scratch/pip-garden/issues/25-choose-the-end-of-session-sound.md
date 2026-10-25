# 25 — Choose the end-of-session sound

**What to build:** REQ-031's six end-of-session sounds, and the control that picks between them. The app ships one — the wind chime REQ-008 makes the default — and has since ticket 06. US-028 is a P0 story that nothing owns: ticket 06 owed only the default, ticket 23 is art and nothing else, and PRD §9.2 commissions the recordings without any ticket wiring them up.

**Blocked by:** 03, 06 — both done. The *recordings* are blocked on PRD §9.2's sound designer, the same way ticket 23 is blocked on §9.1's illustrator. Everything below except the files themselves can be built against placeholders first, and should be.

**Status:** done.

- [x] All six of REQ-031's choices exist and are selectable: Wind Chime (default), Soft Bell, Birdsong, Singing Bowl, Ocean Wave, None
- [x] The choice is stored on the settings row — PRD §4.3 names the column `endSound` — and survives a relaunch and a reset (a reset clears a garden, not a preference; see ADR 0019)
- [x] The control is a row in settings, and it plays the sound when the user picks it — a sound chosen from a list of names nobody can hear is a list of names
- [x] The chosen sound is what plays when a session completes **in front of the user**, through `EndSoundPlayer`
- [x] The chosen sound is what plays when a session completes **while the app is away**, on the notification ticket 06 schedules — on both platforms. See *The Android channel is the hard part* below
- [x] **None** is silent in front of the user and silent on the notification, and the notification still *appears* — the announcement is the news, not the noise
- [x] Changing the sound is recorded as a `settings_changed` event with a `SettingKey` of its own (§7.1)
- [x] `CONTEXT.md` gains the word. There is a glossary entry for **ambient sound** and for **bed**, and nothing at all for the sound at the end — see *The word, and a name collision* below

## Three things worth knowing before starting

### The word, and a name collision

`EndSound` is already taken. It is the **port** in `lib/src/feedback/end_sound.dart` — the thing that plays a sound — and the obvious name for the new domain enum is the same one. They cannot both have it, and the enum is the one that belongs in `packages/pomodoro_domain/`, beside `AmbientSound`, which is exactly its shape: a small set of named choices, stored as text, defaulted, read back through a `named()` that survives a value this build has never heard of.

Renaming the port is the cleaner half of the trade — it plays a sound, so `EndSoundPlayer` says what it is and leaves `EndSound` free for the choice. That is a mechanical rename across `feedback_providers.dart`, `bundled_end_sound.dart`, `session_announcer.dart` and the test fakes, and it makes the pair read the way `AmbientSound` and `Ambience` already do: the user chooses a *sound*, the *player* plays it.

Whatever is chosen, decide it before writing the enum, and put the answer in `CONTEXT.md` under the ambient-sound entries. The glossary is deliberate about this distinction elsewhere — *ambient sound* is the thing chosen and *bed* is the thing playing — and the end sound needs the same two-sided treatment or it will acquire three names by accident.

### The Android channel is the hard part

`LocalSessionNotifications` posts on one channel, `session_completion`, created once at setup with `RawResourceAndroidNotificationSound(windChimeAndroidResource)` (`lib/src/notifications/local_session_notifications.dart:37,149`). **A notification channel's sound cannot be changed after the channel is created** — that is the platform's rule, not the plugin's, and deleting and recreating a channel to change it is worse: it resets every other choice the user made about that channel, including whether it may make a sound at all, which is a setting the current code's own doc comment points out belongs to them.

So six sounds means **six channels**, one per choice, created lazily and named for the sound. The one the app posts on is the one the setting names. This is the standard answer and it has a visible consequence: the user's system notification settings will list a channel per sound they have tried. Naming them well is therefore part of the work, not polish.

iOS has none of this — `UNNotificationSound` takes a file name per notification, and `_installIosSound` already copies the asset into `Library/Sounds` on first use. Extend it to install whichever sounds are needed rather than the one, and keep the copy-on-change check it already has, so a re-synthesised placeholder is not shadowed by a stale copy.

### These may be compressed, and the beds may not

`docs/ambience.md` argues at length that REQ-012's loops have to be uncompressed PCM, because every lossy codec pads what it encodes and the padding lands in the loop seam. **None of that applies here.** An end sound is a one-shot: it has no seam, nothing joins it to itself, and §5.4 asks for AAC. Ship these as AAC or another compressed format, and do not let `bundled_audio_test.dart`'s PCM assertion — which is written against `AmbientSound.values` — be widened to cover them.

That matters for §4.4's 50 MB more than it looks. `docs/performance-record.md` §6 records that six of the binary's twenty-nine megabytes are audio, and that it is the one dial the project controls. Five more uncompressed one-shots would spend headroom for no reason.

## What to touch

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/settings/` | The new enum, beside `ambient_sound.dart` and shaped like it |
| `packages/pomodoro_domain/lib/src/settings/garden_settings.dart` | The field, and its `with…` |
| `packages/pomodoro_domain/lib/src/analytics/analytics_event.dart` | A `SettingKey` member, and the diff in `settingsChanges` that emits it |
| `lib/src/data/database.dart` | Schema version **19**: the column, defaulted to the wind chime so an upgrading user keeps what they have been hearing |
| `test/data/database_migration_test.dart` | The case for it — an upgrade from 18 with rows in it, per the README's rule |
| `lib/src/data/drift_settings_repository.dart` | Two lines of mapping |
| `lib/src/feedback/` | The port renamed if that is the choice; `BundledEndSound` selecting its asset from the setting |
| `lib/src/notifications/local_session_notifications.dart` | The channel per sound, and the iOS install widened |
| `lib/src/features/settings/settings_screen.dart` | The row — and delete the comment at `_FeedbackSection` saying why there isn't one |
| `assets/audio/`, `scripts/make_placeholder_sounds.py` | Five more placeholders until §9.2 delivers |
| `CONTEXT.md` | The word |

## What this ticket is not

**Not a per-session choice.** The end sound is a setting, like the ambient bed, and unlike the bed it has no reason to be reachable from the timer screen — the moment it matters is the moment the session ends, which is too late to choose. One row in settings is the whole surface.

**Not a second haptics switch.** REQ-037's haptics are one toggle covering both taps, and the reasoning in `GardenSettings.hapticsEnabled` applies here unchanged: **None** is already the user's way of turning the sound off, so a separate on/off beside a six-way choice would be two controls for one decision.

## What was decided differently, and why

**The name.** The port was renamed, as the ticket's cleaner half suggested: `EndSoundPlayer` in `lib/src/feedback/end_sound_player.dart`, `BundledEndSoundPlayer` beside it, and `EndSound` is now the domain enum in `packages/pomodoro_domain/lib/src/settings/`. `CONTEXT.md` carries the two-sided treatment — **End sound** is the thing chosen, **Chime** is the thing heard — plus **End sound player** for the machinery, which is what the rename bought.

**These are compressed on Android and PCM everywhere else, not AAC throughout.** The ticket is right that a one-shot has no seam and that §5.4 asks for AAC, and the Android raw resource is AAC accordingly. The Flutter asset is not, and cannot be: `UNNotificationSound` accepts only Linear PCM, IMA/ADPCM, µLaw and aLaw in WAV, AIFF or CAF, and the asset is the file `_installIosSound` copies into `Library/Sounds`. An AAC asset would play correctly in the app and be silently replaced by the system default on the iOS notification — the half of REQ-031 a user only meets when they are away from their phone, which is the half hardest to notice is broken.

Shipping one format everywhere does not fit: five one-shots at 44.1 kHz PCM put the bundle over §5.4's 8 MB on their own. So the asset is PCM at **22.05 kHz** — nothing here has anything above 11 kHz to lose, the highest partial in the set being the wind chime's at 9.3 kHz — and the copy that *can* be compressed is. Total bundled audio is now 7.27 MB. The full argument, and the delivery constraint it creates for §9.2's sound designer, is in `docs/ambience.md` under *The end sounds are not beds*.

`bundled_audio_test.dart`'s PCM assertion was **not** widened, as the ticket asked: it still runs over `AmbientSound.values` only. What is asserted about the end sounds is in `test/feedback/end_sounds_test.dart`, including that the Android copy is compressed and the asset is not — both directions, because that asymmetry is the thing most likely to be tidied away by somebody making the two match.

**`scripts/make_placeholder_sounds.py` now needs `ffmpeg`** on PATH, for the AAC half. Noted in the script, in the README, and nowhere else it matters — the generated files are what ship.

**A bug in ticket 06's placeholder script came out with it.** Its synthesis loop broke on `envelope < 1e-4`, and the envelope is *zero* at the strike — so it broke on the first sample and wrote four seconds of digital silence. The app's default chime has been silent since ticket 06 and nothing noticed, because nothing listened. The guard now waits for the attack to pass, and `end_sounds_test.dart` asserts every sound is audible.

**Two neighbouring constants moved.** `BundledAmbience._chimeOutlastsTheBedBy` went from five seconds to six: it was sized against the four-second wind chime, and REQ-031's singing bowl is five, so the old margin was exactly the longest sound and therefore not a margin.
