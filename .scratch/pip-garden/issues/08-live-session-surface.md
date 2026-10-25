# 08 — Live session surface on both platforms

**What to build:** The user starts a session and puts their phone down. On iPhone the Dynamic Island shows a tiny ring and plant icon, expanding to a full progress ring, time remaining and growth stage; the lock screen carries a Live Activity for the session's duration. On Android an ongoing notification shows a live countdown and the plant's current stage, and keeps the session alive.

**Android has no equivalent of the Dynamic Island and no ActivityKit.** The honest counterpart is a foreground service with an ongoing notification — which additionally buys reliability that iOS gets for free. Build one shared "live session surface" port in Dart with two platform implementations behind it; no view or domain code should branch on platform.

**Blocked by:** 06, 03

**Status:** done — every criterion is built. Five are qualified, mostly for the reason ticket 06's were — **this machine has no iOS device, no Android device, no emulator and no Xcode** — and one of them for a real platform limit rather than a missing device: iOS cannot advance a Live Activity's growth stage while the app is suspended. See *Verification gaps*. The Dart side is covered by 330 app tests and 168 domain tests; the Swift and the Kotlin have never been compiled, and the criterion that asks for a 120-minute Doze run needs hardware, which is ticket 24's.

- [~] iOS: Live Activity starts with the session and ends when it completes or is cancelled; compact state shows ring + plant icon; expanded shows progress ring, time remaining and growth stage per REQ-010 — **the whole surface is written and wired into the Xcode project; when it is put up and taken down is asserted through the port. No Swift has been compiled**
- [~] iOS: the countdown stays accurate without the app running, and the activity does not linger after the session ends — **the countdown is an absolute `endsAt`, which is what makes it free. "Does not linger" is met as far as iOS allows and no further: a suspended app cannot end an activity at the instant a session completes, so the activity is marked stale *at* that instant and the widget draws a finished state from `context.isStale`; it is ended for real on the next foreground. There is no third option without a push server this product does not have — see ADR 0007**
- [~] Android: a foreground service posts an ongoing, non-dismissable notification with a live countdown and current growth stage, and is torn down on completion or cancellation — **written, declared and wired, and the service stops *itself* at the due instant so the teardown does not depend on the app being alive. No Kotlin has been compiled. "Non-dismissable" is true up to Android 13 and not on 14 — see Verification gaps**
- [~] Android: the correct foreground service type is declared and the service survives Doze for the length of a 120-minute session on a physical device — **the type is declared, justified and asserted by a test. Doze needs a device**
- [~] Both surfaces update as the plant advances a growth stage — **Android does, in the background as well as the foreground. iOS does only while the app can run: advancing a Live Activity needs the app awake or a push token, and this product has no backend. A phone put down at minute three shows a sprout until it is picked up, with an exact countdown beside it. This is a platform limit, it was not designed around, and it is the one place the two surfaces genuinely differ in what they can promise**
- [x] Tapping either surface opens the app on the active session screen
- [x] A settings toggle enables/disables the live surface, defaulting to ON (REQ-033); disabling it must not break background session completion from ticket 06
- [~] Devices without a Dynamic Island fall back to the lock-screen Live Activity with no visual glitches — **there is no fallback code to glitch: one `ActivityConfiguration` supplies both presentations and iOS picks. What a lock screen looks like still has to be looked at**
- [x] Dart code talks to one port; platform specifics live behind it

## What was built

**One rule, and ADR 0007 is it: the live surface shows a session it never runs.** The
Dynamic Island, the lock-screen activity and Android's ongoing notification are windows
onto a session, not the thing keeping it. Nothing outside the Flutter engine holds a
countdown, decides a session is over, or is required for one to complete — which is what
makes REQ-033's switch safe to offer at all, and what makes a device that kills the
service lose a picture rather than a session.

**The countdown is free, and that is the whole design.** The surface is handed
`endsAt` — an absolute instant, as epoch milliseconds — and both platforms count to it
themselves: `Text(timerInterval:)` on iOS, `Notification.setUsesChronometer` with
`setChronometerCountDown(true)` on Android. So the lock screen stays right for two hours
with nothing of this app awake, and the app pushes only what the platform cannot work out:
the plant reaching a new stage, and the user holding or resuming. **About six pushes in a
twenty-five-minute session rather than fifteen hundred**, and there is a test that fails if
that regresses.

`LiveSession.showsTheSameAs` is where that judgement is written down, and the rule it
implements is **compare what the surface draws, and nothing else**. That turns out to
depend on whether the session is held: running, the platform counts down to `endsAt` and
`remaining` is the thing moving; held, the platform draws a static `remaining` and
`endsAt` is the thing moving, because a session held for five more seconds ends five
seconds later. Comparing the wrong one of the two costs a push a second — which is the bug
the first version of this had, for held sessions, and which the review caught.

**The surface comes down when the session ends, whether or not the app is there.** This is
the half that a keeper watching a snapshot cannot do on its own, because the whole scenario
is a phone face-down on a desk. Android's service stops itself: one `postDelayed` at the
due instant, re-armed on every update because a hold moves it. iOS cannot — a suspended app
runs nothing — so the activity is given `staleDate = endsAt` and the widget draws a
finished state off `context.isStale`: "Session complete", a full ring, a mature plant, a
checkmark where the countdown was. It stops claiming to be a countdown at the right
instant; it is ended for real on the next foreground.

**One port, one channel, no branch.** `LiveSessionSurface` has three methods and one
implementation, `ChannelLiveSessionSurface`, over `pip_garden/live_session`. Swift and
Kotlin answer the same three methods against the same map. `test/live/one_port_test.dart`
fails if any view, session or live-surface code reaches for `Platform.is…`,
`defaultTargetPlatform` or `TargetPlatform`, and fails if a second implementation of the
port ever appears — because a choice between two made in Dart breaks the rule just as
thoroughly as a branch does.

**`dueAt` moved into the domain, and it fixed a latent bug in ticket 06.** Both the surface
and the completion notification need the instant a session is due, and both were computing
it as `clock.now() + snapshot.remaining` — the same number arrived at by adding a fresh
clock reading to a subtraction from an older one, so it slides forward by however long the
caller took to ask. On a lock screen that is a push a second to redraw something already
correct; on a scheduled alarm it is a chime late by the same amount. `SessionMachine` now
computes it exactly, from the anchor, and `SessionAnnouncer` reads it rather than
recomputing it.

**Android: a `specialUse` foreground service, and the reasoning is in the manifest.** From
Android 14 a service with no declared type crashes at `startForeground`, and none of the
named types describes a focus timer — `shortService` is capped at minutes against
two-hour sessions, `dataSync` and `mediaPlayback` would be lies. `specialUse` is the
documented escape hatch, at the cost of a Play Console justification, which is written out
as the service's `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` so the console form and the code
cannot disagree. The service holds no wake lock, no thread and no timer: a 120-minute
session costs it exactly what a five-minute one does, which is what makes surviving Doze a
question about the platform's contract rather than about this code.

**iOS: the widget extension is in the Xcode project, not left for someone with a Mac.**
`ios/Runner.xcodeproj/project.pbxproj` gained a `LiveSessionWidget` app-extension target,
its three build configurations, a target dependency and an Embed Foundation Extensions
phase — hand-edited, because there is no Xcode here. It was checked with an OpenStep plist
parser written for the purpose: the file parses, every reference resolves, no object is
orphaned, and the three targets come out with the right product types. That is structural
soundness and not a build, which is why the iOS criteria are still qualified.

`LiveSessionAttributes.swift` is a member of **both** targets. An `ActivityAttributes` type
is matched between app and extension by its shape, so one membership rather than two is an
activity that starts and never appears, with nothing in any log; there is a test that
counts the two.

**The Dynamic Island fallback is the absence of code.** One `ActivityConfiguration` is
handed a lock-screen view and a Dynamic Island view, and iOS picks — an iPhone without an
island shows the lock-screen presentation and nothing else. There is no capability check
anywhere, in Swift or in Dart, and a branch is the only thing that could glitch.

**Tapping either surface lands on the timer, from cold or warm.** Android's notification
carries an intent with `ACTION_OPEN_SESSION`; the Live Activity carries
`pipgarden://session`. Both arrive at the same `opened` stream on the port. The cold
case is the one worth knowing about: the tap happens before there is any Dart alive to hear
it, so each platform holds it and Dart takes it once, at first listen — hence
`takeLaunchTap` as a third method rather than a stream that would have missed it.

Which tab the shell shows moved out of `AppShell`'s `State` and into `selectedTabProvider`,
because the tab bar is no longer the only thing that chooses one.

**REQ-033's switch says what it does not do.** The settings row is "Show on the lock
screen", with a note underneath: *"Turning this off does not stop a session. It still
finishes and still tells you when it does."* That is the thing a user turning it off would
reasonably fear, and ADR 0007 makes it a promise rather than a hope — there are two tests
that turn the surface off and then assert that a backgrounded session is still scheduled,
still completes and still plants.

**Schema version 7.** `liveSurfaceEnabled`, a column with its own default, so a row written
before this ticket reads as on — which is both what a user who never saw the switch means
and what REQ-033 asks for.

## Verification gaps

**Nothing has run on a phone, and no native code has been compiled.** There is no iOS
device or simulator here (simulators need macOS), no Android device or emulator (no
`/dev/kvm`), and neither Xcode nor the Android SDK's build tools. Everything above is
verified by `flutter analyze --fatal-infos` and the suite — 330 app tests and 168 domain
tests, all green. What a machine with the toolchains has to be trusted with:

| Claim | Why only a device or a Mac can settle it |
|---|---|
| The Swift compiles | No Xcode. The SwiftUI in `LiveSessionWidget.swift` is the largest untested surface in this ticket |
| The Kotlin compiles | No Android SDK build tools here |
| The Xcode target builds and embeds | The project file is structurally sound and has never been opened |
| The activity appears on a lock screen, and in an island | ActivityKit's own behaviour, and its authorisation state |
| The countdown is within a second over 120 minutes | `Text(timerInterval:)` and the system chronometer are the things being trusted |
| The service survives Doze for 120 minutes | Requires Doze, which requires a device. See `docs/battery-baseline.md` for the recipe |
| The service's own `postDelayed` stop fires on time in Doze | It is a main-looper post in a process the system is keeping alive, which should be enough. Should is not a test |
| A finished activity really does read as finished at `staleDate` | `context.isStale` firing when the app is asleep is ActivityKit's promise, not one this can check |
| The notification is legible on the lock screen, at a large text size, in both themes | A look, not an assertion |
| An iPhone without a Dynamic Island shows no glitch | The claim is that there is no branch; the *look* is still a look |

**The plant on the iOS surface is an SF Symbol, not the plant.** A widget extension is a
separate process and cannot read a Flutter asset, so `PlantRing.glyph(forStage:)` maps the
growth stage to one of five system glyphs — a placeholder in the same spirit as the
placeholder sprites, so the surface is complete and swappable rather than blank. Ticket 23
reaches it by way of an app group and a shared image, and that one function is what it has
to replace. Android's small icon is a placeholder for the same reason and in the same
spirit: `ic_stat_session.xml`, a silhouette, because Android draws a small icon as a mask
and anything with colour in it arrives as a white blob.

**iOS shows a stale growth stage once the app is suspended, and there is no fix inside
this ticket.** Advancing a Live Activity needs the app awake or a push token, and the
product has no backend (PRD §12 made analytics local-only for the same reason). The
countdown stays exact — that is `endsAt` and the system draws it — and the plant stops
growing on the lock screen until the app is next opened. Deriving the stage inside the
widget does not rescue it: a Live Activity re-renders on an update and once at its stale
date, and one extra render cannot cover three stage transitions. **This is the one
criterion that a device would not settle**, and it should be known before any store
screenshot shows an iPhone lock screen with a maturing plant on it.

**Android 14 lets the user dismiss a foreground service notification.** "Non-dismissable"
was true up to Android 13 and is not any more: from 14 the user can swipe an ongoing FGS
notification away once the app has been in the background a while. The service keeps
running and the surface comes back on the next thing worth showing. Nothing can be done
about it, and the criterion is met as far as the platform allows.

**The `specialUse` justification is subject to Play review.** It can be rejected. The
fallback if it is would be `shortService` plus a re-post, which does not cover a
120-minute session — so this is worth knowing before the first submission rather than
after. `docs/platforms.md` says where to re-check the policy.

## ADR 0005's open question, answered — with a no

ADR 0005 recorded a gap and expected this ticket to close it: an iOS app that is suspended
and then swiped away is killed without `detached`, so its session is restored on the next
launch rather than voided. A Live Activity *does* end when the user force-quits, so "there
is a stored session in flight but no activity" looks like the missing signal.

**It is not one, and the reconciliation was deliberately not built.** That same state is
what a user who turned REQ-033's switch off has, what a user who disabled Live Activities
in Settings has, and what a device that refused the request has. Voiding on it would throw
away real sessions the user is in the middle of, to catch a case ADR 0005 had already
chosen to fail kindly on. The gap stays open on purpose; the reasoning is in ADR 0007 so
the next person to notice it does not have to rediscover it.

## Bugs this ticket found and fixed

Four of the five below were found by `/code-review` after the ticket first read as done,
which is worth recording: three of them were in the Swift and the Kotlin, where nothing on
this machine compiles, and the fourth was a claim in this file that the code did not keep.

- **A held session was pushed once a second — the exact cost the design exists to avoid.**
  `showsTheSameAs` compared `endsAt`, which stands still while a session runs and moves
  every second while one is held. So pausing turned six pushes a session into one a second:
  a notification rebuild per second on Android, and ActivityKit updates per second on iOS
  against a budget the app deliberately did not request. The guard test only covered a
  running session. Fixed by comparing what the surface actually draws, and there are now
  tests for both phases.
- **The lock-screen activity had no tap target.** `.widgetURL` was attached to the Dynamic
  Island and not to the lock-screen view, so a tap opened the app with no URL and landed on
  the garden. It failed hardest on exactly the devices the fallback criterion is about —
  an iPhone without an island has no other presentation to tap.
- **`Text(timerInterval: Date.now...state.endsAt, …)` would have crashed the widget
  extension.** A `ClosedRange` traps when its bounds are inverted, and this view is
  rendered with `endsAt` in the past on two ordinary paths: at the stale date, which the
  app sets *to* `endsAt`, and on any relaunch where the app was killed before it could end
  the activity. Clamped.
- **Android's `startForegroundService` could throw from the background.** Dart timers keep
  running behind a backgrounded Android app, so a growth-stage push can arrive with nobody
  looking; if the service had been killed in between, that is a *start* from the background
  and Android 12 forbids it. Now caught and reported through the channel, which is what the
  port's best-effort contract promises.
- **The due instant slid forward every time it was asked for.** `clock.now() +
  snapshot.remaining` is not a stable value — it is a fresh clock reading plus a
  subtraction from an older one — so ticket 06's scheduled completion was late by however
  long the announcer took to run, and a naive live surface would have pushed an update
  every second forever. `SessionSnapshot.dueAt` computes it from the anchor instead. This
  was already wrong before this ticket; it was invisible because a notification a
  millisecond late is a notification on time.

## Decisions worth knowing downstream

- **Ticket 09's break timer inherits the surface along with the announcer.** A break is a
  second thing that could be shown on a lock screen, and `LiveSession` describes a *focus*
  session — it carries a plant. Whoever builds the break has to decide whether a break gets
  its own surface or none; there is one activity and one notification id on the assumption
  that one thing runs at a time, and a break that can run alongside nothing else keeps that
  true.
- **Ticket 23's art swap has a third place to go.** The Dart sprites, the iOS
  `PlantRing.glyph(forStage:)` and Android's `ic_stat_session.xml`. The first is a registry
  swap as designed; the other two are separate processes that cannot read Flutter assets,
  and that is worth costing before the ticket is started rather than during it.
- **Ticket 24's battery baseline should be taken before this ships, or after, but not
  across it.** `docs/battery-baseline.md` was written when a backgrounded session cost
  approximately nothing. It still should: this ticket adds no timer, no wake lock and no
  polling, and about six channel crossings per session. If a measurement disagrees, the
  foreground service is the first thing to suspect and the design above is the claim to
  falsify.
- **`selectedTabProvider` is the way to open a tab from outside the shell.** Ticket 12's
  plant inspection and ticket 16's onboarding will both want it; it is a provider now
  rather than widget state, and `AppShell` is a `ConsumerWidget`.
- **REQ-010's "garden icon" on the lock screen is the growing plant, not a garden.** The
  PRD's wireframe says garden icon; what is drawn is the plant the session is growing,
  because that is what the session's own screen shows and what the notification copy names.
  Worth flagging as a small, deliberate divergence from §5.2.
