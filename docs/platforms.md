# Platform notes

| | Minimum | Target |
|---|---|---|
| iOS | 17.0 | latest SDK |
| Android | API 26 (8.0) | API 36 (16) |

`test/platform/minimum_versions_test.dart` checks these. If you change one, change it in
all of these places:

- iOS: `IPHONEOS_DEPLOYMENT_TARGET` in `ios/Runner.xcodeproj/project.pbxproj` (all three
  configurations), and the `platform` line and `post_install` hook in `ios/Podfile`
- Android: `minSdk` / `targetSdk` / `compileSdk` in `android/app/build.gradle.kts`

iOS 17 is the first version where the ActivityKit APIs used for the Live Activity work
without compatibility branches. API 26 is the floor for notification channels and the
current foreground-service model. Play requires target 36 from 31 Aug 2026, so it's set
already. `compileSdk` matches `targetSdk`. Check the current Play requirement before
submitting: <https://developer.android.com/google/play/requirements/target-sdk>

## Native pieces

| Feature | iOS | Android |
|---|---|---|
| Live session surface | `LiveSessionWidget` extension in `ios/LiveSession/`, `NSSupportsLiveActivities` + `pipgarden://` scheme in `Info.plist` | foreground service in `LiveSessionService.kt` |
| Background audio | `UIBackgroundModes: audio` in `Info.plist` | nothing extra (see `docs/ambience.md`) |
| Quiet mode | `StartFocusSessionIntent.swift` (App Intent for a Shortcuts automation) | `AutomaticZenRule` in `QuietModeRule.kt`, `QuietModeReceiver.kt`, `ACCESS_NOTIFICATION_POLICY` |

Each feature talks to Dart over a single method channel (`lib/src/live/`, `lib/src/quiet/`,
`*Plugin.{kt,swift}`). The Swift and Kotlin can't be compiled on Linux CI, so
`test/platform/*_wiring_test.dart` does a text check that the pieces are wired up.

## Gotchas

- `specialUse` foreground service: since Android 14 every foreground service needs a
  type, and none of the named types fits a focus timer (`shortService` is capped at a few
  minutes). `specialUse` has to be justified in the Play Console on first submission. The
  text is in the manifest as `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`. The short version: no
  wake lock, no work, the system draws the countdown from an end timestamp.
  <https://developer.android.com/develop/background-work/services/fg-service-types>
- Quiet mode on Android needs API 29 (`setAutomaticZenRuleState`). Below that the app
  reports it as unavailable and hides the switch.
- `ACCESS_NOTIFICATION_POLICY` has no runtime prompt. The user has to grant it in
  Settings → Do Not Disturb access, and can revoke it at any time, so the app re-checks
  on every resume.
- A session on Silence doesn't open an audio session, so the background audio mode
  doesn't keep the app alive on its own.

## Podfile

Checked in on purpose. `flutter_additional_ios_build_settings` only raises pods to
Flutter's own minimum, which is lower than 17.0, so the `post_install` hook pins every pod
to 17.0.
