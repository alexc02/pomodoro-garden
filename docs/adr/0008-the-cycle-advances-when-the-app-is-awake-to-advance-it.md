# The cycle advances when the app is awake to advance it

REQ-032's auto-start starts the next leg of the Pomodoro cycle **anchored to the moment it
is noticed**, never to the moment that earned it. A session that finished during an hour in
a pocket gets its break when the user opens the app, and that break is a whole break.

## The problem

Ticket 09 asks for a cycle that runs unattended: focus → break → focus, with both switches
on, and it has to "survive backgrounding". Nothing of this app runs while it is away —
REQ-005 forbids depending on anything that would — so the two halves of that sentence pull
in opposite directions. Whatever noticed the session end is the same thing that was not
running when it happened.

Two readings of "survives backgrounding" were available:

- **The cycle ran while the app was away, and the app catches up with where it got to.**
  A session that ended fifty minutes ago had a five-minute break which also ended, so the
  next session started forty-five minutes ago and is nearly over. The wall-clock anchor
  makes all of that computable, which is exactly what makes it tempting.
- **The cycle is where the app left it, and moves on when the app is next awake.** The
  session is found complete, and the break it earned starts now.

## The decision

The second. `SessionController._autoStart` runs off the tick that noticed an ending and
starts what is due from the current instant.

The first reading breaks on the leg it cannot honestly replay: a *focus session*. Anchoring
one an hour ago would complete it, record it, and drop a plant in the garden for time the
user spent with their phone in a pocket — and a plant is the whole reward this app has. It
would be handing out the reward for not using the app. There is no version of that which
is only a little bit wrong, and no way to have the break replayed without the session after
it also being replayed, because they are the same rule applied twice.

So the cycle is a queue of one, not a simulation. What survives backgrounding is the
user's *position* in it — `SessionSnapshot.cyclePosition`, which counts completed sessions
and wraps when a long break begins — and not a set of legs that ran without anybody there.

## What this costs

**A break can start long after the session that earned it.** A user who finishes a session
and puts their phone down for an hour is handed a fresh five-minute break on their way back
in, not a break that expired fifty-five minutes ago. That is arguably what they want and
unarguably not what a literal reading of "unattended" says, and it is the one place where
the phrase "the app cycles focus → break → focus unattended" needs the word *awake* in it.
The settings screen says so under the switches, in as many words.

**Auto-start reacts to an ending, and endings are not states.** A user sitting on a
completed session who then turns auto-start on is not handed a break: the completion has
already been published, and turning a switch on does not un-end it. Without that rule the
next resume — which calls `catchUp`, which ticks — would start a break the user never
accepted, because a tick that finds the timer in `completed` cannot otherwise tell itself
apart from the tick that put it there. `SessionController._published` is what remembers,
and it starts null so that a launch which restores an already-finished session still gets
the break it earned.

**A skipped break stops the cycle rather than continuing it.** `endBreak` lands in `idle`
rather than `breakOver`, so nothing auto-starts over it. Walking out of a break is the user
taking the cycle back by hand, and the app lets them have it; the alternative is a skip
button that starts a session, which is not what it says.

## Consequences

- `settings` gains `autoStartBreak` and `autoStartNextSession` (schema 8), both defaulting
  to **off**. That default is the ticket's requirement rather than a preference: an app
  that starts counting something the user did not ask for has taken a decision away from
  them.
- The break is announced exactly as a session is — the chime and the haptic in front of the
  user, a scheduled notice when the app is away — because a break is the one countdown the
  user is *meant* to be away from. `SessionCompletionNotice.forBreak` is that copy, and it
  names no plant, because a break grows none.
- A break is not shown on the live surface. It has no plant, and the plant is what both
  surfaces are built around; see `LiveSession.of`.
