# A break replays; a session never does

Amends `0008-the-cycle-advances-when-the-app-is-awake-to-advance-it.md`. PRD v2.2 REQ-032,
ticket 34.

With *Start breaks automatically* on, a session that ends while the app is away is followed
by its break **anchored at the instant the session ended**, not at the instant the app
noticed. The break's end is announced by a notification on time. The next **focus session
is still never started for time the app was not watching**.

## Why 0008 is amended

0008 chose "the cycle is a queue of one, not a simulation". The cycle moved on only when
the app was awake, and whatever started was anchored to that moment. Its reason was sound,
and it still stands for one leg of the cycle. Replaying a missed *focus session* would
complete it, record it and plant something for time the phone spent in a pocket, and the
plant is the app's only reward.

0008 also said the break could not be replayed without the session after it being replayed
too, "because they are the same rule applied twice". That was the part the gap review
(`.scratch/pip-garden/prd-gap-report.md`, finding B2) questioned. The two legs are not
alike:

| | Earns anything? | Safe to anchor in the past? |
|---|---|---|
| A break | No. It plants nothing and counts toward nothing | **Yes.** Nothing is handed out for it |
| A focus session | A plant, a statistic, a step toward a milestone | **No.** That would be the reward for not using the app |

So the rule is applied once and then stops. The cost of 0008's reading was real: a user who
leaves the phone face-down, the main way people use a Pomodoro timer, got nothing from the
switch. The session ended, the phone chimed, and the break didn't start until the phone was
picked up.

## The decision

**On return.** When a tick collects a session that completed while the app was away and
*Start breaks automatically* is on, the break starts at the session's own completion
instant: its anchor, plus its planned duration, plus every minute it spent paused, the same
instant `SessionMachine.poll` records it completing at. If the break has also run out by
now, the app is in `breakOver`, exactly as if it had run in front of the user.

A break the **user** asks for, by tapping *Take a break*, still starts when they tap it.
Replaying applies only to the break the switch starts.

**On the way out.** When the app leaves the foreground with a session running and the
switch on, it schedules two notifications, not one: the session's end, as before, and the
break's end, at that instant plus the length of the break the cycle will offer then. Both
are withdrawn when the app returns, as one always was. A paused session schedules neither,
because nobody can say when it will end.

**The next session.** *Start sessions automatically* is unchanged from 0008. It reacts to a
break ending that the app noticed, from the instant the app noticed it. A user who opens the
app to find the replayed break already over gets the next session started then, if they
asked for that, which is what the settings note promises: "the cycle carries on when you
open it again". Nothing is anchored before that moment.

## What this costs

- **`SessionNotifications` holds two pending notices instead of one.** The port gains
  `scheduleFollowUp`, posted under its own id, and `cancelCompletion` withdraws both.
- **The break-end notice can be wrong if a setting changes while the app is away.** It is
  computed from the break length and cycle position at the moment the app leaves. Nothing of
  the app runs afterwards to correct it, the same limit 0008 and REQ-005 accept for the end
  sound.
- **A break can now be already over the moment the app sees it.** That was always possible
  for a break started in front of the user and then left alone. Now it is also possible on
  return, and `SessionAnnouncer`'s "watched, not found" rule keeps the chime quiet for it,
  because the notification already said it.

## Consequences

- `SessionMachine.startBreak` takes an optional `at`, never later than now.
- `SessionController._autoStart` starts the auto break at the completed session's due time,
  and checks once more for a break that is already over.
- `SessionAnnouncer` schedules the follow-up notice; `LocalSessionNotifications` posts it
  under a second id.
