# 26 — The four micro-sounds

**What to build:** PRD §5.4's last four rows — soil settle, growth shimmer, button tap and unlock. They are counted in §9.2's fifteen audio assets and no ticket has ever owned them, so the app is silent at four moments the design specifies a sound for. Every one of those moments already exists in the code and already does something else; this ticket adds a sound to it and nothing more.

**Blocked by:** 04, 06, 13 — all done. The *recordings* are blocked on PRD §9.2's sound designer, like ticket 25's. Build against placeholders.

**Status:** done.

- [x] **Soil settle** plays as the seed lands — §5.4 puts it at "seed planted", and §5.3 puts the landing at the end of the 0.8s drop, not the start of it
- [x] **Growth shimmer** plays when a plant reaches a new growth stage, at the same moment REQ-037's subtler haptic fires
- [x] **Button tap** plays on the app's primary actions, and the ticket names which ones — see *Which taps* below
- [x] **Unlock** plays when a milestone award is celebrated — see *What "unlock" means here* below
- [x] None of the four plays over an ambient bed in a way that fights it, and none of them takes audio focus away from one (ADR 0009)
- [x] None of the four plays when the app is not in front of the user. These are responses to something on screen; there is nothing to respond to when nobody is looking
- [x] They are silent when the phone asks for silence, and the ticket records what that means — see *The switch this ticket does not have* below
- [x] `CONTEXT.md` gains a word for them, if the answer to the design question below is that they are one thing rather than four

## The moments already exist

Nothing here needs a new trigger. Each of the four is a line added where something already happens, which is the whole reason this is a small ticket:

| Sound | Where the moment already is |
|---|---|
| Soil settle | `lib/src/garden/growing_plant.dart` — the `_drop` controller, and `plant_painter.dart:89`'s "small soil particle burst on landing" is already drawn at exactly the instant this sound wants |
| Growth shimmer | `lib/src/session/session_announcer.dart` — where the growth haptic already fires on a stage change |
| Button tap | The primary actions; see below |
| Unlock | `lib/src/garden/milestone_keeper.dart` — `_celebrate`, where the card rises |

## Four things to decide

### Which taps

§5.4 says "button tap" and the app has a great many buttons. A sound on all of them is a different product from the one PRD §2 describes — *no notifications screaming for attention*, *calm* — and an app that clicks at every settings row is not it.

The defensible reading is **the actions that start and end something**: START, Pause, Resume, Cancel, and accepting a break. Those are the taps that change what the app is doing, and they are the ones a user takes deliberately. Everything else — a settings switch, a tab, a theme chip, dismissing a card — stays silent. Write the answer down in the ticket when it is settled; the list is the requirement, because "button tap" on its own cannot be finished.

### What "unlock" means here

§5.4 gives no context for it and there are two candidates. REQ-018 unlocks four plots every ten sessions, and REQ-021 awards a bonus plant at seven milestones.

**The milestone is the one to take.** A plot unlock is invisible — it is a floor derived from a session count (ADR 0006), nothing on screen announces it, and a sound for something the user cannot see is a sound they cannot explain. A milestone award already has a moment built for it, and `MilestoneKeeper` already holds that moment back until the timer has come to rest specifically so it reads as its own event. That is a moment with room in it for a sound.

### The switch this ticket does not have

REQ-037 gives haptics a toggle. REQ-031 gives the end sound a **None**. These four have neither, and the PRD never says what silences them.

Do not invent a fifth switch. The two honest options are to fold them under something the user already controls, or to give them nothing and let the platform's own volume be the answer. Whichever is chosen, the requirement is that **a phone set to silent stays silent** — these are UI feedback, not media, and `AppAudioSession`'s `ambient` use is the one that already respects the iOS silent switch (ADR 0009). That is the property to test, and it is the reason these must not be played on the `playback` use the ambient bed asks for.

### Whether they are one thing or four

`EndSound` is a port with one method because there was one sound. Four fire-and-forget one-shots at four unrelated call sites will otherwise become four providers and four fakes in the harness. One small port that takes which sound to play — and one fake that records the sequence — is the shape that keeps `test/support/app_harness.dart` from growing a parameter per sound.

If it is one thing, it needs a word in `CONTEXT.md`, and the glossary's own habit says what kind: name the *part of the app*, the way `Ambience` names the machinery and `bed` names the thing heard.

## What this ticket is not

**Not a sound on everything.** The four are a closed set from §5.4 and the ticket is finished when they are done. A fifth sound is a new requirement, not a natural extension of this one.

**Not the end-of-session sound.** That is ticket 25, it is a user's choice rather than a fixed asset, and it reaches the scheduled notification, which none of these four ever do.

---

## The four decisions, settled

### Which taps — five, and they are the requirement

**START, Pause, Resume, a *confirmed* Cancel, and accepting a break.** Written as `MicroSound.buttonTap`'s doc and as the five call sites in `timer_screen.dart`.

Two readings of the list needed settling beyond the ticket's wording:

- **Cancel is the confirmation, not the button that opens the question.** Tapping CANCEL ends nothing — it asks something. Backing out of the dialog is silent; the tap is on *Cancel session*.
- **Onboarding's "Start my first session" is a START.** It was missed on the first pass and found in review. The list is about what a tap *does*, not which screen it is on, and that button begins a real session with a finger on it. Skip and Next stay silent: one abandons the flow, the other turns a page.

What is deliberately **not** on the list: every settings control, the tabs, the theme and ambience pickers, dismissing a card — and **skipping a break**, which is the one omission worth naming. `SessionMachine.endBreak` already puts a skipped break in `idle` rather than `breakOver` precisely so that walking out of a break makes no sound at all; a tap on the one control a break has would take that back.

The sound sits at the controls rather than in `SessionController`, and that is load-bearing: REQ-032 calls the same methods with nobody touching anything, and a sound in the controller would make the app click at itself while the phone is in a pocket. There is a test for exactly that.

### What "unlock" means — the milestone, as the ticket argued

REQ-021's award, played in `MilestoneKeeper._celebrate` as the card rises. REQ-018's plot unlock makes no sound, for the ticket's own reason: it is a floor derived from a session count, nothing on screen announces it, and a sound for something invisible is a sound the user cannot explain.

### The switch — none, and the phone is the answer

**No switch of any kind.** The four play on `AudioUse.chimeOnly`, which is `ambient` on iOS — the category the ring switch mutes — and the notification usage on Android, which the ringer mode governs the same way. What turns a micro-sound down is the phone's volume; what silences it is the phone's silent switch.

Folding them under `EndSound.none` was the other honest option and was rejected: that value is scoped to what a *completed session* sounds like, on screen and on the notification, and quietly widening it would make ticket 25's settings row a lie about what it controls.

**The exception, named rather than left to be discovered on a device:** a running ambient bed holds the session on `playback`, which ignores the ring switch, so a micro-sound fired *during a bed* is audible on a silenced phone. Two of this ticket's criteria pull against each other there, and ADR 0009 decides it — taking the session back to `ambient` for a button tap would silence the rain the user asked for. It is the end sound's existing bargain applied to four quieter sounds rather than a new one. Documented on `BundledMicroSounds` and asserted in `test/feedback/micro_sounds_test.dart`.

### One thing, not four

One port, `MicroSounds`, taking which sound to play; one `FakeMicroSounds` recording the *sequence*, because these fire at moments that are ordered and the order is what a test can get wrong. `app_harness.dart` grew one parameter rather than four.

`CONTEXT.md` gains one entry, **Micro-sound**, for the thing heard. The machinery gets no separate word, and the entry says why: there is no third idea to name here. *Ambient sound* / *bed* / *ambience* splits three ways because the user *chooses* a bed; nobody chooses a micro-sound, so there is no choosing half to tell apart from a playing half.

## What else changed, and why

**The soil settle is played by the timer screen, not by `GrowingPlant`.** The ticket points at `growing_plant.dart` and it is right that nothing else knows when the seed touches the soil — but "knows when" and "decides what that means" are different jobs. Putting the player in the drawing widget broke `test/garden/plant_platform_parity_test.dart` with a `MissingPluginException`: a widget that renders a plant should not need an audio device. So `GrowingPlant` exposes `onLanded` at the new `GrowingPlant.landsAt` — the same 0.8 the particle burst already began at, now named once instead of written twice — and the screen above it plays the sound. The parity test needs no audio override at all.

**Citations split between §5.4 and §9.2.** The ticket calls these "§5.4's last four rows"; they are not. §5.4 specs *two* of them — the soil settle and the growth shimmer get a context, a source and a format — while the button tap and the unlock are named in §9.2's asset table and nowhere else. The code cites whichever section actually says something about each, and the two durations the PRD never gives are this ticket's reading.

**The format argument is the short one.** These never reach a notification, so `UNNotificationSound`'s PCM-only rule — the thing that forced ticket 25's end sounds to ship twice — never applies. AAC, one copy each, 44.1 kHz, **25 kB for all four**. They are peaked at −20, −16, −15 and −12 dBFS, from the button tap up to the unlock, where the end sounds are all at −9: a sound that accompanies something should sit under the thing it accompanies, and the tap is the one that fires most often. `docs/ambience.md` has it under *The micro-sounds are the easy case*.

**A player per sound, and the load is memoised rather than the player.** Four one-shots are not as tidy as one end sound — a seed lands 800 ms after the tap that started the session — so a single player would have one cut the other off. Review found a race in the first version: two plays of the same sound before its first decode resolved would each build a player, leaking one and swallowing a tap, which a double-tap on the first PAUSE of a run could reach. `_players` now holds a `Future<AudioPlayer>` per sound, so the second tap awaits the first one's player and seeks it.

**Considered and deferred:** `BundledMicroSounds` and `BundledEndSoundPlayer` now share a configure-once-then-report-and-carry-on shape. Extracting it is a repo-wide refactor rather than this ticket's — the same idiom is in `LocalSessionNotifications._report` and `BundledAmbience._bestEffort` — and doing it here would touch three files this ticket has no business in.

**`scripts/make_placeholder_micro_sounds.py` needs `ffmpeg`**, as ticket 25's does, and is seeded: regenerating is byte-identical, so a diff means the synthesis changed.
