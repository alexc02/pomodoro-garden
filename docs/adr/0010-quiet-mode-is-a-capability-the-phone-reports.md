# Quiet mode is a capability the phone reports, not a feature the app claims

REQ-014 asks for the phone to go quiet while a focus session runs. **One of the two
platforms can do that and the other cannot**, and this app ships that difference honestly
rather than building a switch on iOS that silences nothing.

The rule the whole feature divides on is a sentence:

> **The control appears where the automation is real.**

## The problem

The PRD's v1.0 text assumed an app could enable a Focus mode on both platforms. It cannot.

- **Android can.** `AutomaticZenRule` lets an app register a Do Not Disturb rule of its
  own and switch it on and off, behind `ACCESS_NOTIFICATION_POLICY`.
- **iOS cannot.** No public API activates a Focus. Apple's Focus APIs are read-only —
  Focus Status, and only with the Communication Notifications capability — or reactive:
  `SetFocusFilterIntent` tells an app that a Focus *changed*. Access appears to have
  tightened further in iOS 26.

The tempting shape is a switch on both platforms with an `if (Platform.isIOS)` behind it
doing nothing. It looks like parity in review, and the user finds out at the worst
possible moment: a call in the middle of the session they thought they had protected.

## The decision

One port, `QuietMode`, and the difference between the platforms arrives as an **answer**
rather than as a branch. `QuietModeAccess` has four values and no platform names:

| | What it means | Who says it |
|---|---|---|
| `granted` | The app may silence the phone | Android, with policy access |
| `denied` | It could, and has not been allowed to | Android, without it |
| `byAutomation` | The app cannot, but the user can wire it up, and the app has donated the piece they need | iOS |
| `unavailable` | Nothing can be done here | Android below 10, and any build with nothing registered |

The settings screen switches on that value: a `SwitchListTile` for the first two, the
Shortcuts recipe for the third, and a plain sentence for the last. No view and no domain
code asks which phone it is running on, which is `test/live/one_port_test.dart`'s rule
applied to a second port.

**iOS's half is a real feature, not an apology.** `StartFocusSessionIntent` is an App
Intent that starts a session. The user's Shortcut runs *Set Focus* and then it, so turning
the phone quiet and starting the session are one tap — the outcome REQ-014 asked for,
reached by the only route the platform offers. Without the intent the recipe would be half
a recipe, and the hint would be telling somebody to do the app's job by hand.

## Why priority, and not total silence

The ticket's snippet used `INTERRUPTION_FILTER_NONE`. What ships is
`INTERRUPTION_FILTER_PRIORITY` with a `ZenPolicy` that disallows every sound and then
allows exactly two: **alarms** and **reminders**.

Total silence has no policy to negotiate. It would swallow ticket 06's completion
notification — the app going quiet for twenty-five minutes and then failing to say the
twenty-five minutes were up, which is the criterion "the app's own end-of-session
notification still reaches the user while its rule is active" failing in the most obvious
way there is. So the notice is posted as `CATEGORY_REMINDER` — it is something the user
asked to be told at a time they chose — and the rule's policy lets that category through.

Alarms are allowed for a plainer reason: an app that made somebody sleep through an alarm
clock has done more damage than an unsilenced phone ever could.

The cost is named rather than hidden: **other apps' reminders come through too.** A
calendar reminder is not obviously the wrong thing to hear during a focus session, and the
alternative was an app that could not announce its own sessions.

## Why the silence has a deadline the app does not keep

Quiet mode ends when the session does, and three separate things end it: the session
completing, being cancelled or being voided; a force-quit, on the `detached` signal; and a
launch that finds nothing in flight, which speaks up whether or not the app believes quiet
mode is on. All three need a live process, and a process the system kills to reclaim
memory gets none of them.

So `QuietMode.begin` takes a deadline. Android sets an `AlarmManager` alarm for the
instant the session is due, and `QuietModeReceiver` switches the rule off when it fires,
with nothing of this app running. **A phone left permanently silent by an app the user
never opens again is the one failure this feature is not allowed to have.**

It is not absolute, and the gap is worth writing down: a *force-stop* from system settings
cancels the alarm along with everything else the app owns, and leaves the rule as it was
until the next launch. That is the platform's own contract for a force-stopped app, and
the next launch is what fixes it.

## Why Android 10 rather than the app's API 26 floor

Registering a zen rule has been possible since Android 7. *Activating* one from the app
that owns it needs `NotificationManager.setAutomaticZenRuleState`, which is Android 10.
Before that the only route is a bound `ConditionProviderService` — a background service,
on the platform versions least able to keep one alive, for a feature about silence.

Those devices report `unavailable`, which is the truth and costs nothing: the settings
screen offers no switch, and the user's own Do Not Disturb toggle is where it always was.
The app's `minSdk` is unchanged, because one feature is not a reason to drop users of
every other one.

## Consequences

- `GardenSettings` gains `quietModeEnabled` and `quietModeHintDismissed`; schema version
  10 adds the two columns, both defaulting to false. The first is the most consequential
  default in the app — it decides which of somebody's calls they miss — and an upgrade
  must not turn it on.
- `QuietModeKeeper` is the fifth widget wrapped around the shell, and follows the same
  rule `AmbienceKeeper` does: what belongs to a focus session, running or held, and to
  nothing else. A break is loud, because a break is time the user is meant to be
  available in.
- The permission is re-read on every resume. It is granted and revoked on a system
  settings screen, which the user reaches by leaving the app, so a remembered answer is
  exactly how a revoked permission becomes a switch that is on and quietly does nothing.
- `local_session_notifications.dart` posts the completion notice in the reminder category
  — a line about quiet mode living in the notifications, asserted from both ends by
  `test/platform/quiet_mode_wiring_test.dart` because neither side can be observed here.
