# 09 — Break timer and the full Pomodoro cycle

**What to build:** After a focus session ends, the user can take a break — automatically or by choice — and after several sessions, a longer one. The app cycles focus → break → focus without the user having to tap anything, if they want it that way.

**Blocked by:** 06, 03

**Status:** done — every criterion is built and covered. One is qualified, and it is ticket 06's gap inherited rather than a new one: **this machine has no iOS device, no Android device and no emulator**, so whether the OS delivers the notice a break schedules is still unwitnessed. The Dart side is 43 domain tests and 26 app tests on top of the 360 + 211 the suite already runs green.

- [x] Completing a focus session offers a break of the configured length; the break runs on the same timer machinery with a visually distinct, restful treatment
- [x] Auto-start-break and auto-start-next-session toggles added to settings, both defaulting off (REQ-032)
- [x] After N sessions (configurable 2–6) the break offered is a long break
- [x] Breaks do not grow plants and do not count toward session totals, streaks or milestones
- [x] Breaks can be skipped or ended early, returning cleanly to an idle state
- [~] A break ending plays the end sound and notifies, like a session, and works when backgrounded — **the chime, the haptic, the scheduled notice, its instant and its copy are all asserted, and a break survives an hour in the background because it is read from the clock rather than counted. Whether the OS rings is device-only, exactly as it was for the session in ticket 06**
- [x] With both auto-start toggles on, the app cycles focus → break → focus unattended, and the cycle survives backgrounding
- [x] Cycle position is covered by state-machine tests, including the wrap from long break back to session one

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/session/rest_break.dart` | `Break`, `BreakKind`, and `BreakOffer.at` — the whole long-break rule in one comparison |
| `packages/pomodoro_domain/lib/src/session/session_machine.dart` | `onBreak` / `breakOver`, `startBreak`, `endBreak`, and `cyclePosition` |
| `packages/pomodoro_domain/lib/src/settings/garden_settings.dart` | `autoStartBreak`, `autoStartNextSession`, and `longBreakLength` derived from the break the user chose |
| `lib/src/session/session_providers.dart` | `breakOnOfferProvider`, `startBreak`, `skipBreak`, and `_autoStart` off the tick that noticed an ending |
| `lib/src/session/session_announcer.dart` | A break that runs out is announced by the session's rule; a break walked out of makes no sound |
| `lib/src/notifications/session_notifications.dart` | `SessionCompletionNotice.forBreak` — calm copy that names no plant, because a break grows none |
| `lib/src/features/timer/timer_screen.dart` | `_BreakOffered`, `_BreakControls`, the sky-coloured ring and the bare soil under it |
| `lib/src/features/settings/settings_screen.dart` | The Breaks section: two lengths, and REQ-032's two switches |
| `lib/src/live/live_session.dart` | A break is not put on the lock screen, and why |
| schema v8 | `settings.auto_start_break` / `auto_start_next_session`, both defaulting off |
| `docs/adr/0008-…` | The cycle advances when the app is awake to advance it |

## Three things worth knowing before picking up a dependent ticket

**"Survives backgrounding" was read as *the cycle*, not *the countdown*.** ADR 0008 is the
whole argument. Nothing of this app runs while it is away, so the alternative reading —
replay the legs the wall clock says went by — would have to replay a *focus session* too,
completing it and dropping a plant in the garden for time the user spent with their phone
in a pocket. That is handing out the reward for not using the app, and there is no way to
replay the break without also replaying the session after it, because it is the same rule
applied twice. So a session that finished during an hour away is found complete on the way
back in, and the break it earned starts *then*, whole. The settings screen says so under
the switches rather than leaving the user to discover it.

**A break is thinner than a session on purpose, and the thinness is the feature.** No id,
no outcome, no row, never stored, cannot be paused. A break that was skipped and a break
that ran its course leave the same trace, which is none — so nothing downstream has to
learn to exclude breaks from a count, a streak or a milestone. Ticket 13 inherits a
`cyclePosition` that only completed sessions move, and a `plants` table breaks never touch.

**Skipping a break lands in `idle`, not in `breakOver`.** That one line is what stops
auto-start from starting a session over a break the user walked out of, and it is also
what keeps a skipped break silent while a break that ran out chimes. Walking out is the
user taking the cycle back by hand; the alternative is a SKIP button that starts a
session, which is not what it says.
