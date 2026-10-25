# 06 — Sessions survive backgrounding, and end gently

**What to build:** The user starts a session, locks their phone, and works. Twenty-five minutes later a wind chime plays and a gentle notification tells them their plant has bloomed — even though the app was never in the foreground. Returning to the app shows the completed session, not a stale timer.

REQ-013's promise that a backgrounded session continues is only true if this ticket is right. It is the highest-risk area in the product (PRD §10 flags it), so test on real hardware on both platforms, not just simulators.

**Blocked by:** 05

**Status:** done — every criterion is built and covered off-device. Four are qualified and one is handed on, all for the same reason: **this machine has no iOS device, no Android device and no emulator.** See *Verification gaps*. Nothing here is waiting on more software; what is left is waiting on hardware, and ticket 24 is where the hardware arrives.

- [~] A session started, then backgrounded for its full duration, completes correctly and is recorded — verified on a physical iOS device and a physical Android device — **verified in widget tests, including with the app's timers running behind a `paused` binding; no device has been touched**
- [~] A local notification fires at completion while the app is backgrounded or the device is locked, with calm non-alarming copy — **the notice, its instant and its copy are asserted; whether the OS delivers it is device-only**
- [~] The wind-chime end sound plays at completion (default per REQ-008), including from the background, and respects the device silent switch — **the chime plays in the foreground and is attached to the notification for the background; the sound is a synthesised placeholder, and the silent switch is a category choice no test can hear**
- [x] A gentle success haptic fires at completion and a subtler one at each growth-stage transition, with an on/off toggle added to settings (REQ-037)
- [~] Notification permission is requested at a sensible moment — not on first launch — covering Android 13+ `POST_NOTIFICATIONS` and the iOS authorisation flow; the app degrades gracefully when denied, with the session still completing correctly — **when it is asked for, and what a refusal costs, are both covered; neither platform's dialog has been seen**
- [x] Killing the app after completion but before reopening still shows the session as completed on next launch
- [~] Battery drain during a backgrounded 25-minute session is measured and recorded for ticket 24's baseline — **the method is written and the table is empty. Measuring needs a device to drain; `docs/battery-baseline.md` makes taking the reading an afternoon rather than a design exercise, and ticket 24 owns it**

## What was built

**One rule, and everything else follows from it: a completion is announced once, by
whichever of the two can be heard.** In front of the user that is the wind chime and a
haptic, played by `SessionAnnouncer` at the instant the session ends. Away from them it is
a notification the operating system was handed when the app left the foreground — because
nothing of this app is running to play anything, and REQ-005 forbids depending on anything
that would be.

The notification therefore exists *only while the app is away*: scheduled on `paused`,
cancelled on `resumed` and on `detached`. That is what removes the race the obvious design
has. Scheduling at START and cancelling when the app notices its own completion means the
alarm and the app both fire at the same instant and the loser is whoever the scheduler ran
second — a double chime, or a notification that survives the app cancelling it. Scheduling
on the way out means there is never a moment when both could sound, and never one when
neither could.

**The corollary looks like a bug and is not.** A session that finished while the app was
away is *not* chimed at when the user opens the app. They were told when it happened;
telling them again ten minutes later would be an app that chimes at the wrong moment. The
announcer tells the two apart by remembering when the running session was due to end and
comparing that with the clock when the completion is noticed — inside two seconds it was
watched, outside it was found. A session restored at launch has no remembered due instant
at all, and so is silent by construction.

**No timezone anywhere.** A session's end is an absolute instant, so it is scheduled
against `tz.UTC`, which the `timezone` package supplies without loading its database. No
`flutter_timezone` dependency, no 250 KB of tzdata at launch, and a phone that crosses a
zone mid-session still chimes at the right moment.

**The silent switch wins.** The foreground chime configures its audio session as `ambient`
on iOS — the category that mutes with the ring switch. `playback`, the obvious choice for
an app that means to be heard, deliberately ignores that switch, and a focus app that
chimed in a meeting because the user had silenced their phone would have earned every word
of the review. On Android the equivalent is asking for the notification usage, which the
ringer mode governs the same way. It mixes rather than ducks, so a user who focuses to
music still has music afterwards.

**Three ports, because none of this leaves a mark on screen.** `SessionNotifications`,
`EndSound` and `Haptics` are interfaces with platform implementations and fakes in
`test/support/announcement_fakes.dart`. The notification fake models the platform rather
than counting calls — one pending notice at a time, scheduling replaces, cancelling clears,
and a notice scheduled without permission is accepted and silently dropped — which is what
makes "would the user's phone go off" a question a test can ask.

**Permission is asked for at the first START of a run, never at launch.** A permission
dialog over a screen nobody has used yet is a question about nothing, and the answer to it
is usually no. Asked when the user has just started their first session, the question is
about something they are visibly doing. Once per run rather than once ever, because neither
platform asks a user who has already decided, so there is no counter to keep.

**The sound is a placeholder, in the spirit of the placeholder sprites.**
`scripts/make_placeholder_sounds.py` synthesises a four-second wind chime — five struck
tubes in a pentatonic scale, each a stack of the inharmonic partials an aluminium tube
really rings at — and writes it to both places it has to exist: `assets/audio/` for Flutter,
and `android/app/src/main/res/raw/` because an Android notification channel cannot take its
sound from a Flutter asset. On iOS the asset is copied into the app container's
`Library/Sounds` on first use, which is one of the two places `UNNotificationSound` looks
and the only one a Flutter asset can reach without editing the Xcode project. Replacing the
placeholder with PRD §14's real recording is running the script's output over with a real
file; `end_sound.dart` is the only place any of the three names appear.

**REQ-037's switch, and schema version 5.** `hapticsEnabled` is a field on `GardenSettings`,
a column with its own default, and a switch on a new **Feedback** section of the settings
screen. The end sound is deliberately *not* on that screen: REQ-031 offers a choice of five
and this ticket ships the one REQ-008 makes the default, so a control there would be a
control with one option.

**Android's exact-alarm choice is `USE_EXACT_ALARM`.** From Android 14 `SCHEDULE_EXACT_ALARM`
is denied by default and can only be granted by sending the user to a system settings
screen — interrupting a focus app to ask permission to be punctual. `USE_EXACT_ALARM` is
granted on install and is documented for exactly this case, an app whose core function is a
timer, at the cost of being subject to Play review. If a device or a policy refuses anyway,
`LocalSessionNotifications` falls back to an inexact alarm: a late chime is worse than a
punctual one and far better than none.

**The battery baseline has a method but no number.** `docs/battery-baseline.md` is the half
of that criterion which does not need a battery: the Android `dumpsys batterystats` recipe
in both its forms — untethered for the percentage, `battery unplug` for the attribution,
because USB charges the device and only one of the two readings survives that — the Doze
check that exercises the actual delivery risk, and the reason iOS gets a coarse
percentage-delta method and nothing better. Two things in it are worth knowing without
reading it. An **idle control run is part of the measurement**, not an optional extra: the
budget is a small delta against a device's own drain, and a session run reported alone is a
reading of the device. And the whole thing is framed as a claim to falsify — a backgrounded
session should cost approximately *nothing*, so a reading meaningfully above idle is a bug
report about a Dart timer still ticking behind `paused` or an OEM refusing to freeze the
process, rather than a number for a table.

## Verification gaps

**Nothing has run on a phone.** There is no iOS device or simulator here (simulators need
macOS) and no Android device or emulator (no `/dev/kvm`). Everything above is verified by
`flutter analyze --fatal-infos` and the suite — 206 app tests and 135 domain tests, all
green — and four of the five qualified criteria are qualified on exactly this: the app-side
behaviour is covered, the platform's half of it is not. The fifth, the battery baseline, is
qualified differently — there is no app-side half to cover, only a method waiting for a
device. What a device has to be trusted with, and what would be checked first on one:

| Claim | Why only a device can settle it |
|---|---|
| The notification actually fires at 25 minutes with the screen locked | Whether the OS honours the alarm — iOS suspension, Android's OEM battery managers |
| The wind chime plays from the notification | iOS `Library/Sounds` install path; Android raw-resource channel sound |
| The silent switch mutes it | `ambient` category behaviour, and Android ringer modes |
| The permission dialogs appear once, at the first START | Android 13's `POST_NOTIFICATIONS` prompt and iOS's authorisation sheet |
| The haptics feel gentle rather than sharp | `mediumImpact` and `selectionClick` are choices about a sensation |
| Battery drain over a backgrounded session | Requires a battery. Method in `docs/battery-baseline.md`; the table in it is empty |

**The Android channel is created once and then frozen.** From Android 8 a channel's sound
is fixed at creation. If a later ticket changes the end sound, users who already have the
channel keep the old one unless the channel id changes with it — the trap is worth knowing
before REQ-031's five sounds arrive.

**A force-quit races the cancel.** On Android, `detached` both voids the session and cancels
the notice, and both writes are best-effort during teardown (ADR 0005). If the void lands
and the cancel does not, the user gets a chime for a session that grew nothing. On iOS a
suspended app is killed without `detached`, so neither happens — the session is restored on
the next launch and the notification fires for a session that really does complete, which is
consistent. Ticket 08's Live Activity is the second signal for both.

**The end sound is not the end sound.** It is a synthesised stand-in at the right length and
temperament, not PRD §14's licensed asset, and it should be listened to by a human before
anyone concludes REQ-008 is satisfied.

## Ticket 05's open question, answered

05 left this: *"a session whose planned end passed while the process was dead is restored
and then completes, planting normally — worth confirming against the scheduled notification
06 adds."* They agree, on both paths. If the app was backgrounded before it was killed, the
notification was already scheduled and fires at the true end, and the next launch restores
the session and completes it at the same instant — the user is told once and gets one plant.
If the app died while in the foreground, nothing was scheduled and nothing was said, and the
next launch completes it silently. There is no path where the notification claims a plant
the database does not have.

## Bugs this ticket found and fixed

- **The migration could not add a column to a table an earlier step had created.**
  `Migrator.createTable` builds the table as it is defined *today*, so the 1 → 2 step that
  first created `settings` was quietly creating a version-5 table, and the 4 → 5 step then
  failed on a duplicate column — for every user upgrading from version 1 or 2, which is
  every user who installed before ticket 03. The two steps that create tables now write
  their SQL out, so each leaves behind the shape of the version it introduces. Covered by a
  new version-4 case in `database_migration_test.dart` alongside the existing ones.
- **The "no view code names an image" test caught an audio asset.** `rootBundle.load` is on
  its list because it is one way an image reaches the screen; it is also the only way to
  read any asset, and the iOS sound install needs one. Narrowed by the sound's own name
  rather than by exempting the file, so that file naming a plant image is still caught.

## Decisions worth knowing downstream

- **Ticket 09's break timer inherits all of this.** "A break ending plays the end sound and
  notifies, like a session" is `SessionAnnouncer` with a second kind of thing to announce;
  the notice id is fixed at 1 on the assumption there is one thing running, and a break that
  can run alongside nothing else keeps that true.
- **Ticket 08 must not schedule a second notification.** The live surface is a different
  object — an ongoing notification and a Live Activity — and the completion notice stays
  where it is. Two things announcing one completion is the failure this ticket's rule exists
  to prevent.
- **Ticket 24's battery baseline starts here**, unmeasured, with its method written down in
  `docs/battery-baseline.md`. The design gives it the best possible starting point — no
  background execution, one alarm per session, no polling — so the measurement is mostly of
  the foreground second-ticker and, from ticket 10, the ambient audio. The document is
  deliberately framed as a *claim to falsify* rather than a number to collect: a backgrounded
  session should be indistinguishable from an idle device, and it names the two things worth
  suspecting first if it is not. Take the reading before ticket 10 and ticket 08 land, or the
  three costs become one indivisible number.
- **REQ-031's sound selection is unowned.** Ticket 03 nominally carried it and shipped
  lengths only; this ticket ships REQ-008's default. Somebody has to own the other four
  sounds and the picker, and it is not this ticket.
