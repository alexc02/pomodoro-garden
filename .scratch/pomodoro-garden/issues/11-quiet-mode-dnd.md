# 11 — Quiet mode: automatic DND on Android, a hint on iOS

**What to build:** REQ-014 asks for Focus Mode to toggle automatically when a session starts. **This is possible on Android and impossible on iOS**, and the ticket ships that asymmetry honestly rather than faking parity.

On Android, starting a session silences the device and ending it restores the previous state. On iOS, no public API can activate a Focus mode — Apple's Focus APIs are read-only (Focus Status, gated behind the Communication Notification capability) or reactive (`SetFocusFilterIntent`, which only tells your app a Focus changed). Access appears to have tightened further in iOS 26. So iOS gets a donated App Intent the user can wire into a Shortcuts automation, plus a one-time in-app hint.

Build one shared quiet-mode port. The settings toggle only appears where automation is real; on iOS the settings row leads to the hint and the Shortcuts recipe instead of pretending to be a switch.

Android implementation is constrained: apps targeting Android 15+ **cannot** modify the global interruption filter — `setInterruptionFilter` silently redirects to an app-owned rule. Use `AutomaticZenRule` explicitly:

```kotlin
val ruleId = nm.addAutomaticZenRule(
    AutomaticZenRule.Builder("Focus Time", Uri.parse("garden.focus"))
        .setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
        .setConfigurationActivity(ComponentName(context, MainActivity::class.java))
        .build())
// rules start as STATE_FALSE — activation is a separate call
nm.setAutomaticZenRuleState(ruleId, /* active */ …)
```

**Blocked by:** 06, 03

**Status:** done — every criterion is built and covered as far as a workstation can cover it. Five are qualified, and all five for the reason tickets 06, 09 and 10's were: **this machine has no iOS device, no Android device and no emulator**, so no phone has gone quiet. What could be moved off the device *was* — every rule about when quiet begins and ends is a widget test through the real app, and everything that is a string two files have to agree on is asserted across them. The Dart side is 50 new tests across three quiet-mode files, plus one each in the migration, settings-repository and domain-settings suites, on top of the 404 + 222 the suite already ran green — 456 and 223 now. **Two deliberate departures from the ticket text are written up below**: the snippet's `INTERRUPTION_FILTER_NONE` is not what ships, and quiet mode needs Android 10 rather than the app's API 26 floor.

- [~] Android: an `AutomaticZenRule` is registered once and activated on session start, deactivated on session end, cancel, or void — **every one of those routes is a test (`test/quiet/quiet_mode_test.dart`), and the rule is looked up by its condition id rather than by a stored id, so it cannot be registered twice. That the platform honours it is unwitnessed**
- [~] Android: `ACCESS_NOTIFICATION_POLICY` is declared, `isNotificationPolicyAccessGranted()` is checked before use, and an ungranted user is walked to the DND access settings screen with a clear explanation — there is no runtime dialog for this — **the explanation and the walk are tested end to end in Dart; the manifest entry, the check and the intent are asserted as text because none of the Kotlin compiles here**
- [x] Android: revoking policy access while the feature is on is detected and the toggle reflects reality rather than silently no-op'ing — **re-read on every resume, not cached. The switch shows what the *phone* says, not what the setting says, and the note under it explains the difference. Both the silence coming off mid-session and the control showing off are tested**
- [~] Android: quiet mode never outlives its session — force-quitting mid-session must not leave the device permanently silenced — **four routes, three of them tested here: the session ending, the `detached` signal, and a launch that finds nothing in flight and says so unprompted. The fourth is the one that survives a process killed without warning — an `AlarmManager` deadline set when the silence starts — and it is unwitnessed. Its one gap is named in ADR 0010**
- [~] Android: the app's own end-of-session notification still reaches the user while its rule is active — **this is why the rule is `INTERRUPTION_FILTER_PRIORITY` and not the snippet's `NONE`; see below. Asserted as the pair it is — the rule allows reminders, the notice is posted as one — and unwitnessed on a device**
- [~] iOS: an App Intent is exposed that the user can wire into a Shortcuts automation, and a one-time dismissible hint explains how — **the hint, the recipe and "once ever, not once a launch" are tested through the real app. The intent is Swift: its presence, its target membership and the fact that its title matches the name the recipe tells the user to look for are asserted, and whether Shortcuts lists it is unwitnessed**
- [x] iOS: no toggle claims automation the platform cannot deliver — **there is no `SwitchListTile` in the quiet-mode section unless the platform reported that it can act on one, and the test that says so scrolls to the bottom of the screen first so the absence is an absence rather than a widget that was never built**
- [x] One shared port; no domain or view code branches on platform — **`test/live/one_port_test.dart` already scans every file in `lib` for a platform check and covers the new ones for free; `test/platform/quiet_mode_wiring_test.dart` adds the other half, that exactly one class implements `QuietMode`**

## What was built

| Where | What |
|---|---|
| `lib/src/quiet/quiet_mode.dart` | The port, and `QuietModeAccess` — the four answers a phone can give about what it will let the app do |
| `lib/src/quiet/channel_quiet_mode.dart` | One method channel, no platform branch, everything best-effort |
| `lib/src/quiet/quiet_mode_providers.dart` | The port, and the access answer as something that can be re-asked |
| `lib/src/quiet/quiet_mode_keeper.dart` | Keeps the phone as quiet as the timer says it should be, the way `AmbienceKeeper` keeps the bed |
| `lib/src/features/settings/settings_screen.dart` | The section that is a switch, a recipe, or a sentence, depending on what the phone said |
| `lib/src/notifications/local_session_notifications.dart` | The completion notice is now `CATEGORY_REMINDER`, which is what gets it through the app's own silence |
| `packages/pomodoro_domain/.../garden_settings.dart` | `quietModeEnabled` and `quietModeHintDismissed`, both off |
| `android/.../QuietModeRule.kt` | The zen rule, its policy, and the alarm that lifts the silence with the app dead |
| `android/.../QuietModeReceiver.kt` | What that alarm wakes |
| `android/.../QuietModePlugin.kt` | Android's half of the channel |
| `android/app/src/main/AndroidManifest.xml` | `ACCESS_NOTIFICATION_POLICY`, and the receiver |
| `ios/Runner/StartFocusSessionIntent.swift` | The App Intent, and the Siri phrase that surfaces it |
| `ios/Runner/QuietModePlugin.swift` | iOS's half: "the app cannot, the user can", and the route the intent reaches Dart by |
| schema v10 | `settings.quiet_mode_enabled`, `settings.quiet_mode_hint_dismissed`, both defaulting to false |
| `docs/adr/0010-…` | Quiet mode is a capability the phone reports, not a feature the app claims |
| `docs/platforms.md` | What this ticket added to each platform, and the two things to know before changing it |

## Four things worth knowing before picking up a dependent ticket

**The snippet's `INTERRUPTION_FILTER_NONE` is not what ships, and the fifth criterion is
why.** Total silence has no policy to negotiate: it silences this app's own completion
notification along with everything else, so the app would go quiet for twenty-five minutes
and then fail to say the twenty-five minutes were up. What ships is
`INTERRUPTION_FILTER_PRIORITY` with a `ZenPolicy` that disallows every sound and then
allows exactly two categories — **alarms**, because an app that made somebody sleep
through an alarm clock has done more damage than an unsilenced phone ever could, and
**reminders**, which is the category ticket 06's notice is now posted in. The cost is
named rather than hidden: other apps' reminders come through too.

**Quiet mode needs Android 10, and `minSdk` is unchanged.** Registering a zen rule is API
24; *activating* one from the app that owns it is `setAutomaticZenRuleState`, API 29.
Before that the only route is a bound `ConditionProviderService` — a background service, on
the platform versions least able to keep one alive, for a feature about silence. Those
devices report `unavailable`, the settings screen offers no switch, and every other feature
still works there. The PRD's claim that "API 26 is the floor for `AutomaticZenRule`" is
true of registering one and not of using it.

**The asymmetry is a value, not a branch, and a fourth ticket will meet it.**
`QuietModeAccess` has four cases and none of them is a platform name; the settings screen
switches on it and the keeper reads it. Anything later that wants to know whether the phone
can be silenced asks the port, and **nothing may reach for `Platform.isAndroid`** —
`one_port_test.dart` fails the build if it does.

**iOS's App Intent starts a session, which means a session can now begin with nobody
looking at the app.** `QuietModeKeeper` handles it, ignores it while anything is in flight
— including a break, because walking out of one is the user's decision and not a Shortcut's
— and shows the timer tab when it takes it. A later ticket adding a second way in from
outside should join it there rather than in a screen.
