# Platform minimums

| | Minimum | Target |
|---|---|---|
| iOS | 17.0 | latest SDK |
| Android | API 26 (8.0 Oreo) | API 36 (Android 16) |

Asserted by `test/platform/minimum_versions_test.dart`. Change a number there
and here whenever you change one in the platform files.

## Where each value lives

| Value | File |
|---|---|
| iOS minimum | `ios/Runner.xcodeproj/project.pbxproj` — `IPHONEOS_DEPLOYMENT_TARGET`, all three configurations |
| iOS minimum, for pods | `ios/Podfile` — the `platform` line *and* the `post_install` hook |
| Android `minSdk` / `targetSdk` / `compileSdk` | `android/app/build.gradle.kts` |

## Why these

**iOS 17.0.** Ticket 08 puts the running session in the Dynamic Island via a
Live Activity, and iOS 17 is where the ActivityKit API needed for that is
usable without back-compatibility branches. As of this ticket, iOS 17 and later
covers the large majority of active devices, and the users this app is aimed at
skew recent.

**Android API 26.** The floor for notification channels and the modern
foreground-service model — both load-bearing for ticket 08, which keeps a
running session alive and visible.

**Android target 36.** Play requires new apps to target API 35 today
(11 Aug 2026) and API 36 from 31 Aug 2026. This app ships after that date, so
it targets 36 now rather than taking the bump as a release blocker later.
Re-check the current requirement before submitting:
<https://developer.android.com/google/play/requirements/target-sdk>.

`compileSdk` is held equal to `targetSdk` so behaviour changes at the targeted
level surface as compile errors rather than runtime surprises.

## What ticket 08 added to each platform

| | What | Where |
|---|---|---|
| iOS | A widget extension target, `LiveSessionWidget`, holding the Live Activity | `ios/LiveSession/`, and the target in `ios/Runner.xcodeproj/project.pbxproj` |
| iOS | `NSSupportsLiveActivities`, and the `pipgarden://` scheme a tap on the surface opens | `ios/Runner/Info.plist` |
| Android | A foreground service and its ongoing notification | `android/app/src/main/kotlin/.../LiveSessionService.kt` |
| Both | The one method channel behind `LiveSessionSurface` | `lib/src/live/`, `LiveSessionSurfacePlugin.{kt,swift}` |

Asserted by `test/platform/live_surface_wiring_test.dart`, which is the only thing
here that can check any of it — none of the Swift or the Kotlin compiles on a Linux
workstation. See ADR 0007 for why the surface is shaped the way it is.

## What ticket 10 added to each platform

| | What | Where |
|---|---|---|
| iOS | `UIBackgroundModes: audio`, so a bed goes on playing behind a locked screen | `ios/Runner/Info.plist` |
| Android | nothing | — |

Asserted by `test/platform/background_audio_test.dart`, together with the audio
categories the two uses configure. The background mode is what the app is *allowed* to do
rather than something it does: a session on Silence opens no audio session, so nothing
keeps the process alive and the app suspends exactly as it did before ticket 10.

Android needs no manifest change, and that is the gap rather than the good news — see
`docs/ambience.md`. Nothing there keeps the process alive for the bed on its own.

### `specialUse` needs a Play Console justification

From Android 14 every foreground service must declare a type, and none of the named
types describes a focus timer: `shortService` is capped at a few minutes against
sessions that run to two hours, and `dataSync` and `mediaPlayback` would be lies.
`specialUse` is the documented answer for a service the taxonomy does not cover, and
it comes with a condition — **the first Play submission has to justify it in the
console**, and can be rejected.

The justification is already written down in the manifest, as the service's
`PROPERTY_SPECIAL_USE_FGS_SUBTYPE`; the console form wants the same words. Its
substance is that the service holds no wake lock and does no work — the countdown is
rendered by the system from an absolute end instant — so it is a visible timer and
nothing else. Re-check the current policy before submitting:
<https://developer.android.com/develop/background-work/services/fg-service-types>.

## What ticket 11 added to each platform

| | What | Where |
|---|---|---|
| Android | An `AutomaticZenRule` the app owns, switched on for the length of a session | `android/app/src/main/kotlin/.../QuietModeRule.kt` |
| Android | `ACCESS_NOTIFICATION_POLICY`, and the receiver behind the rule's deadline | `AndroidManifest.xml`, `QuietModeReceiver.kt` |
| iOS | An App Intent the user wires into a Shortcuts automation, and a Siri phrase for it | `ios/Runner/StartFocusSessionIntent.swift` |
| Both | The one method channel behind `QuietMode` | `lib/src/quiet/`, `QuietModePlugin.{kt,swift}` |

Asserted by `test/platform/quiet_mode_wiring_test.dart`. See ADR 0010 for why the two
platforms answer the same requirement so differently, and why the difference reaches Dart
as a capability rather than as a platform check.

### Two things to know before changing any of it

**Quiet mode needs Android 10, not the app's API 26 floor.** Adding a zen rule is API 24;
*activating* one from the app that owns it is `setAutomaticZenRuleState`, which is API 29.
Below that the app reports `unavailable` and the settings screen offers no switch. The
`minSdk` is unchanged.

**`ACCESS_NOTIFICATION_POLICY` has no runtime dialog.** The only way to hold it is for the
user to find this app in Settings → Do Not Disturb access, so the app explains where it is
sending them and then opens that screen. It is also revocable there at any time, which is
why the app re-reads it on every resume rather than at launch. Both are Play-listing
matters as well: §10's permission table names it as optional and needing justification.

## The Podfile

Checked in rather than left to `flutter build` to generate. Later tickets add
plugins with native pods (audio, purchases, notifications), and
`flutter_additional_ios_build_settings` only raises a pod's deployment target to
Flutter's own floor, which is below ours. The `post_install` hook pins every pod
to 17.0.
