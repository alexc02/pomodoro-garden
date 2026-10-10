# Onboarding is a layer over the running app, and skipping it skips all of it

REQ-003 allows three screens: a welcome with a garden preview, a session length, and
start. US-003 asks for the tutorial to be *overlaid on the actual app, not a separate
screen*. Those two sentences decide most of this ticket; what is written down here is the
part they leave open.

## The app is built underneath the flow, from the first frame

`OnboardingOverlay` sits inside every other keeper, wrapping `AppShell` in a `Stack`. The
shell — all four tabs, the session controller, the garden's camera — is alive behind the
welcome screen, and the three steps are drawn on top of it.

Two things fall out of that, and both are the requirement rather than a nicety:

- **The last step is a hand-off, not a navigation.** Tapping START writes the setting,
  selects the timer tab and starts the session, and the overlay stops drawing itself. What
  the user is looking at a frame later is the timer that was there all along, with US-005's
  seed dropping into it. There is no route to pop and no screen to build.
- **The `Stack` is unconditional.** It has one child when onboarding is done and two or
  three while it is running. A version that returned the bare shell once onboarding
  finished would change the shape of the tree at exactly the moment the user's first
  session is one minute old — rebuilding the shell's element, and dropping the seed a
  second time in front of the one user in the world who has never seen it before. There is
  a test for that specific frame in `test/features/onboarding/`.

## The coach marks point at the real widgets, and block nothing

`CoachMarkTargets` holds three `GlobalKey`s, carried by the session ring and by two of the
four `NavigationDestination`s. A mark reads the target's rect off the render tree and
draws an outline around it — so "over the live UI" is literal, and the outline's presence
is what a test asserts to prove the mark found its target rather than merely drawing a
card somewhere.

There is **no barrier**. The layer is a `Stack` with an outline and a card in it, and
every pixel neither covers belongs to the app underneath: PAUSE works while a coach mark
is up, and so does everything else. That is the ticket's "never blocking the session", and
it is why this is not a `showDialog` — a modal route would absorb the whole screen and
would have to be dismissed before the user could touch their own session.

The card is pinned to the *top* edge when its target is in the upper half of the screen,
rather than sitting directly beneath it. What is beneath the ring is the plant and the two
controls, and a card that landed on PAUSE would be blocking the session it had just
congratulated the user for starting.

## Skipping means skipping the coach marks too

`skip` is on all three steps, and it leaves the whole of onboarding: no session is
started, the session length keeps whatever value it had, and the three coach marks never
appear — not on the way out, and not on the session the user starts for themselves five
minutes later.

The alternative — skip the welcome, still get taught over the app — was rejected because
it answers a user who said *no thank you* by continuing to talk. A skipped tutorial is a
tutorial the user declined, and the app has nowhere else it needs to say this.

## The flag is one bit in the settings row

PRD §4.3 puts `onboardingCompleted` in `settings`, and this ticket keeps it there for the
reason ticket 11's hint dismissal is there: this is the app's single-row store, and a
second table for one boolean is a table to migrate for the rest of the app's life. It
reaches the app through the same accessor as every other setting.

It is written when the flow is **left**, by either route — started or skipped — because
REQ-003's "shows once" is about the screen and not about the session. A user who taps
START has been through onboarding whatever happens to the app in the next second.

Two readings of the flag are not the same as the value in the column:

- **A settings row that predates this version reads as done.** The 12 → 13 migration
  backfills every existing row with an explicit `UPDATE`. A row on disk belongs to
  somebody who has been running sessions for weeks, and greeting them with a welcome
  screen would be the upgrade telling them they had never been here. The column's own
  default stays `false`, because false is what a *fresh install* means — and a fresh
  install has no row at all.
- **Settings that cannot be read at all read as done.** `SettingsController` already falls
  back to the defaults when the database will not answer; it falls back to the defaults
  *with onboarding completed*, because "we could not read it" and "this is a new install"
  are different claims. The flag written at the end of the flow could not be written
  either, so the honest fallback is the one the user can get past.

## Seeing it twice

Onboarding is shown once per install, which makes it the one screen in the app that nobody
can look at again — including the person reviewing it. The settings screen therefore has
an **Onboarding (debug)** section, compiled out of release builds by the same `kDebugMode`
guard as REQ-019's forced season, with one button that writes the flag back to false and
puts the flow on screen. `README.md` says where it is.

It writes rather than only re-showing, so what is being checked is a real first launch:
relaunching lands on the welcome too.

## The sixty seconds, and what the test actually proves

The ticket asks for a *measured* time from first launch to a session running, under sixty
seconds at a natural pace. What a widget test can measure honestly is the app's own share
of it: every frame spent opening, laying out and animating is real elapsed time on the
test binding's clock, and the human share is a budget — eight seconds per screen of two
sentences and one decision, four of them.

The test measures both together off one clock and asserts the total is under sixty
seconds; it also asserts the total is *over* the human budget, so that a clock which
stopped moving would fail rather than pass. What it proves is that the flow is four
decisions long and costs no meaningful time of its own. What it cannot prove is that eight
seconds is what a stranger takes, and that is the number to revisit if it ever turns out
to be wrong.

## The welcome garden is a picture

A first-run user's real garden is bare soil, so the preview is a fabricated
`GardenLayout` — eighteen plants across twenty plots, one of every type — drawn by the
real `GardenPainter` over the real sprites, and wrapped in an `IgnorePointer`. Nothing
about it is stored, so the garden the user opens a minute later is empty, and nothing in
it can be tapped: a card opened on a preview plant would be the app inventing an afternoon
the user never spent.
