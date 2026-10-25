# Google Play: permission declarations

Two of the app's permissions need their own declaration in Play Console, separate from the
Data safety form, and Play reviews them.
Checked against the release build's merged manifest on 2026-10-11.

## 1. Exact alarms: `USE_EXACT_ALARM`

Play Console → **App content → Exact alarm permission** (shown once the bundle declares it).

Play allows `USE_EXACT_ALARM` only for apps whose core function needs it: an **alarm clock
or timer**, or a calendar app. A focus timer is a timer.

**Suggested answer:**

> Pip Garden is a focus timer. Its core function is a countdown the user starts: a
> focus session of a length they choose, followed by an optional break. When the user leaves
> the app during a session, the app schedules one notification for the exact moment the
> session (and, if enabled, the break) ends. That notification is the timer's alarm. It must
> arrive on time, because a focus session that ends late is the core function failing. No
> exact alarm is scheduled except for a countdown the user started.

`SCHEDULE_EXACT_ALARM` is also declared, capped at Android 12 (`maxSdkVersion="32"`), where
it is granted on install. No declaration is needed for it.

## 2. Foreground service: `FOREGROUND_SERVICE_SPECIAL_USE`

Play Console → **App content → Foreground service permissions**.

Android has no foreground service type for a user-visible timer, so the app uses
`specialUse` with a subtype declared in the manifest. Play asks what the service does, why
no other type fits, and **may ask for a short video** of the feature.

**Suggested answer:**

> While a focus session runs, the app shows it in an ongoing notification: the session's
> countdown and how far the plant has grown. It's Android's counterpart to an iPhone's
> lock-screen Live Activity. The user starts it by starting a session, can switch it off in
> Settings ("Show on the lock screen"), and it stops when the session ends or is cancelled.
> The service keeps no wake lock and does no work while it runs: the countdown is drawn by
> the system from the session's end time. None of the defined foreground service types
> describes a user-visible countdown, so `specialUse` is used.

**Video, if asked:** record on the Android emulator: start a session, leave the app, pull
down the notification shade to show the running countdown, return, cancel, and show the
notification disappear. About 20 seconds is enough.

## 3. The rest (no declaration needed)

| Permission | Note |
|---|---|
| `POST_NOTIFICATIONS` | Runtime permission; the app asks when the first session starts |
| `RECEIVE_BOOT_COMPLETED` | Re-arms a pending session notification after a restart |
| `FOREGROUND_SERVICE` | Base permission for the service above |
| `ACCESS_NOTIFICATION_POLICY` | Optional Quiet mode; the user grants it in system settings |
| `VIBRATE` | Haptics |
| `ACCESS_NETWORK_STATE` | Added by the audio library; no internet access |
