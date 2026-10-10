# 0017 — Decor never costs a plant its plot

**Status:** accepted, ticket 20 · amended by
[ADR 0021](0021-the-app-is-free-and-sells-nothing.md)

> **Read "a premium user" below as "the user", and "REQ-036" as "REQ-040".** The app is
> free and decor is placed by everybody; decor also has a requirement number of its own
> now, where this ADR was written citing the garden reset's. The sowing rule this ADR
> decides is untouched by either, because it was never about who owned what.

## The question

REQ-036 lets a premium user stand objects in the empty plots of a garden that
also grows a plant every time they finish a session. Both want the same soil,
and the garden stops at two hundred plots (REQ-018). So: what happens when a
session completes and the plot it would have taken has a bench in it?

The ticket rules out one answer outright — *failing* — and names the two that
are left: expand capacity, or displace decor by a documented rule. This is that
rule.

## The decision

**A plant is never turned away for furniture, and an arrangement is never
disturbed while the garden has soil left.** `GardenPlots.sow` answers in three
steps:

1. **The nearest plot holding neither a plant nor an object.** Decor is stepped
   *over*, not pushed aside. The garden reaches one plot further out than it
   would have, and what the user composed is exactly as they left it. This is
   the case every real garden lives in: two hundred plots is four hundred and
   seventy completed sessions away, and a user with an arrangement has by
   definition left themselves room to see it.
2. **The outermost occupied plot, when every one of the two hundred holds
   something.** The object standing there is taken out of the garden and the
   plant stands where it stood. The *outermost* — last in the placement order —
   because a garden fills from the middle outwards, so what a user arranged
   deliberately is nearest the middle and the thing furthest from it is the
   thing they will miss least.
3. **No plot at all, when two hundred *plants* are already in the ground.** ADR
   0006's case, untouched: the plant is recorded and counted, and the garden
   says it is holding it.

The guarantee that falls out is narrow and exact, and it is worth stating as
what it is rather than as what it sounds like: **decor is never the reason a
completed session goes unplaced.** A plant that has no plot in a garden with
decor in it would have had no plot without it either.

## Why an object is deleted where a plant is kept

ADR 0006 keeps a plant the garden has no room for — recorded, counted, not
drawn — and it would have been consistent-looking to do the same here: a
`plot`-less `Decor` row, waiting for space.

It would also have been useless. A plant is the record of an afternoon somebody
sat through, and the app has no business losing one. A lantern is a decision the
user can make again in two taps: it has no history, no session behind it, and
nothing about it distinguishes it from the next lantern. An invisible row the
user can neither see nor restore is not a kept thing, it is litter — so `Decor`
has a non-nullable plot, and displacement removes the row.

## Why not expand capacity instead

The other answer the ticket offers is to let the garden grow past two hundred
plots when decor is in the way. Rejected, on two counts:

- **Two hundred is a rendering budget, not a rule about gardens.** Ticket 24
  has to hold sixty frames with the whole thing on screen, and ticket 21 has to
  export it. A cap that decor could lift is a cap that a user with fifty
  lanterns has lifted, and neither of those tickets would know.
- **It would sell plots.** Capacity is earned — four per ten completed sessions
  — and a premium purchase that quietly made the garden bigger would be REQ-040
  selling the thing REQ-018 gives away for work. Decor *holds open* a plot the
  schedule has already unlocked, which is what `GardenLayout` does for anything
  standing in the ground, and it unlocks none.

## What this costs

A user who has done four hundred and seventy sessions and arranged their garden
will, eventually, watch objects disappear one per session from the outside in.
There is no notification and no undo. That is the honest end of a finite garden,
and it is the same end their plants meet one session later — at which point the
garden starts holding plants it cannot show. The alternative was a completed
session that grew nothing because of a bench, and nothing in this app is allowed
to cost somebody work they actually did.

## Where it lives

- `GardenPlots.sow` — the rule, and the only place it is written down.
- `SessionController._sow` and `MilestoneAwards._award` — the two callers. Both
  ask it; neither has an opinion of its own.
- `packages/pomodoro_domain/test/garden/garden_plot_test.dart` — the rule
  exercised to its edge, including two hundred sessions into a garden with fifty
  objects in it.
- `test/garden/decor_never_blocks_a_plant_test.dart` — the wiring, through the
  app.
