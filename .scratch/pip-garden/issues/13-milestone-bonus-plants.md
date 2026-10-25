# 13 — Milestone bonus plants

**What to build:** At 10, 25, 50, 100, 250, 500 and 1000 completed sessions, the user is awarded a special plant — a bonsai, a wisteria arch, an ancient oak — placed into their garden with a quiet celebration. These are the long-horizon reason to keep coming back.

Bonus plants are auto-placed, consistent with REQ-017 (this resolves PRD open question #2).

**Blocked by:** 07

**Status:** done — every criterion is built and covered, and this is the first ticket since 05 with **no device-shaped verification gap**: nothing here is native, nothing here makes a sound and nothing here talks to the OS, so a workstation can witness all of it. The Dart side is 23 new app tests and 30 in the domain core: 515 and 260 now, against 492 and 230 after ticket 12. One deliberate departure from the PRD is written up below — **§4.3's `isBonusPlant` column does not ship** — and one product consequence at the 200-plant cap is flagged for ticket 22.

- [x] All seven milestones from REQ-021 award their plant when the session count crosses the threshold
- [x] Awarding happens exactly once per milestone and is idempotent — no duplicate plant if the check runs twice
- [x] Milestones are evaluated against the total completed-session count, so a user who already has 30 sessions receives the 10 and 25 awards rather than nothing
- [x] The bonus plant is auto-placed into an available plot, expanding capacity if the garden is full so an award is never silently lost
- [x] Bonus plants are visually distinct from session plants and identified as such in the inspection card, with the milestone that earned them
- [x] The award is celebrated gently — no modal interrupts an active session; if a milestone is reached at session completion, the celebration follows the session's own completion animation rather than competing with it
- [x] Bonus plants are recorded as bonus and excluded from session statistics
- [x] Placeholder sprites are used until ticket 23

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/garden/milestone.dart` | The seven, and the whole awarding rule: `reachedBy` and `dueFrom` |
| `packages/pomodoro_domain/lib/src/garden/plant_type.dart` | `PlantType.bonus`, and the seven species one per milestone |
| `packages/pomodoro_domain/lib/src/garden/plant.dart` | `Plant.forMilestone`, `isBonus`, and `sessionId`/`sessionDuration` made nullable |
| `packages/pomodoro_domain/lib/src/garden/garden_layout.dart` | `bonusPlants` — the awards named apart from what was grown |
| `packages/pomodoro_domain/lib/src/garden/plant_repository.dart` | `awardedMilestones()`: what is already in the ground |
| `lib/src/data/database.dart` | Schema 11 — `milestone_sessions`, its unique index, and the table rebuild that lets a duration be null |
| `lib/src/data/drift_plant_repository.dart` | The count ↦ milestone mapping, in both directions, at the boundary |
| `lib/src/garden/milestone_providers.dart` | `MilestoneAwards`: the catch-up, the queue, and the serialising of two runs |
| `lib/src/garden/milestone_keeper.dart` | When a celebration may rise, and how long it waits |
| `lib/src/features/garden/milestone_card.dart` | The sheet that says what happened |
| `lib/src/features/garden/plant_card.dart` | The **Awarded at** row, where a session's plant says how long it took |
| `lib/src/features/garden/garden_screen.dart` | The garden's sentence, with the awards counted out separately |
| `lib/src/garden/placeholder_plant_sprites.dart` | `_Crown.aura` — a canopy inside a ring of blooms, until ticket 23 |
| `CONTEXT.md` | The four words this ticket introduced: milestone, bonus plant, award, celebration |

## The one thing worth knowing before picking up a dependent ticket

**A milestone's identity is its session count, and that is what makes the awarding idempotent
in the database rather than only in the code.** `plants.milestone_sessions` stores the
integer — 10, 25, 1000 — under a `UNIQUE` index, so a second award of the same milestone is
a write SQLite refuses. Renaming a member of `Milestone` therefore costs nothing and
*changing a number* is a migration.

That index is deliberately the backstop and not the mechanism. The mechanism is
`Milestone.dueFrom`, a **set difference** against the milestones actually standing in the
garden:

```dart
static List<Milestone> dueFrom({
  required int completedSessions,
  required Set<Milestone> awarded,
}) => reachedBy(completedSessions).where((m) => !awarded.contains(m));
```

Two properties follow, and both are acceptance criteria. The answer is the same however many
times it is asked, so a check that runs twice hands out nothing the second time. And it is
derived from the *total*, so a user arriving at this build with thirty sessions behind them
collects the ten and the twenty-five rather than nothing — which a high-water mark or a
threshold crossing would both get wrong, because the app was not running when the number
went past.

**Nothing here fires at a threshold**, for the same reason nothing in this app fires at the
end of a session: completion is noticed by asking, not by an event. The catch-up runs at
launch and again after every completion, which between them are every moment the count can
have moved.

**Ticket 22 (garden reset) inherits this directly.** A reset that clears `plants` but leaves
`sessions` will re-award every milestone on the next launch, because the garden is the only
record that an award was made. That is arguably correct — the user asked for their garden
back at zero — but it is a decision ticket 22 has to make on purpose rather than discover.

## Four decisions

**§4.3's `isBonusPlant` column does not ship.** The PRD carries both an `isBonusPlant`
boolean and a `milestoneSessions` integer on the plant. Only the second is here: a plant is a
bonus plant exactly when the milestone column is set, and two columns that can disagree about
the same fact are one column too many. `Plant.isBonus` is a getter over `milestone != null`,
so every caller reads it as a flag anyway. **This is a departure from the PRD text**, and the
PRD should be corrected rather than the schema.

**`sessionDuration` became nullable rather than zero.** A bonus plant has no session under
it, and "no session" and "a session of no length" are different claims — a card reading the
second would say **0 minutes** about an award earned by a thousand of them. SQLite cannot
drop a `NOT NULL` with `ALTER TABLE`, so migration 10 → 11 is the one step in this app that
rebuilds a table by copy-and-swap. `test/data/database_migration_test.dart` now carries a
version-10 fixture whose whole job is to prove the garden survives it.

**Bonus plants take plots from the same placement order as everything else, and the garden
grows to hold them.** No separate reservation and no special region: an award asks
`GardenPlots.nextFree` exactly as a session's plant does. The unlock schedule is a floor and
not a ceiling (ADR 0006), so an award into a garden whose unlocked plots are all full expands
the garden rather than being turned away — twenty sessions unlock exactly twenty plots and
grow exactly twenty plants, and the tenth-session award makes it twenty-one.

**Nothing has to subtract bonus plants from a statistic.** Every count of sessions in this app
counts the `sessions` table, and no award ever writes a row there — so "excluded from session
statistics" is a property of where the numbers come from rather than a filter someone has to
remember. `GardenLayout.bonusPlants` exists so the garden can *name* the awards ("11 plants
in 16 plots, 1 bonus plant among them"), not so a count can exclude them.

## How the celebration stays out of the way

Two rules, both in `MilestoneKeeper`, and the plant is in the ground before either applies —
only the *card* waits.

**Nothing rises over a countdown.** A session running, a session held, a break: none is a
moment to put a sheet in front of somebody. A user who completes their tenth session and
starts straight into their eleventh is owed a card that waits however long that takes.

**A milestone reached at the end of a session follows that session's ending rather than
competing with it.** The completing session already has a chime, a haptic and §5.3's growth
spring, and a sheet sliding up through the middle of that would make two events out of one
moment. The celebration hangs back 1500 ms — a little past the 1.2 s spring — and only then
rises. A backlog is shown one card at a time, oldest milestone first, which is what a launch
after an upgrade looks like for a user owed two.

A card is owed once. It is dropped from the queue however it was dismissed, and the plant is
the award — so a celebration the user swiped away, or one the app was killed in the middle
of, costs them the animation and not the plant.

## Two things ticket 23 and ticket 22 should know

**The placeholder bonus sprite is a fifth crown, not a recoloured tree.** `_Crown.aura` is a
canopy inside a ring of blooms: the same height as a large tree and wider than one, because
the criterion is that a user can *pick it out* of a full garden, and a bonus plant that was
merely another large tree would be the reward for a hundred sessions that nobody could find.
The registry is keyed by `(PlantType, GrowthStage)` and `PlantType.bonus` is a member like
any other, so ticket 23 picks it up as seven more cells with no change to the seam — but the
"visually distinct" criterion is a *product* claim about the real art, and this ticket only
proved the geometry.

**At the 200-plot cap an award is recorded unplaced.** This is ADR 0006 working as written —
the plant is kept and counted rather than dropped — but it is the one case where the "never
silently lost" criterion is satisfied by the ledger rather than by the garden: a user at 210
sessions has four awards nobody can see, and the caption says *"Your garden is full. 6 more
plants are waiting for space."* without distinguishing them. Reaching it takes two hundred
completed sessions. Flagged rather than fixed, because fixing it means deciding whether an
award may evict a session's plant, and that is ticket 20's question about decor rather than
this one's.

## Verification

`./scripts/check.sh` green: analyzer clean under `--fatal-infos`, 515 app tests, 260 domain
tests.

The awarding, the placement, the idempotence, the card and the celebration timing are all
driven through the real app in `test/garden/milestone_test.dart` — including one test per
milestone, the thousandth included, against a seeded count rather than a simulated year. Two
mutations were run against the suite to confirm it is not passing vacuously: collapsing the
celebration's 1500 ms wait to zero fails exactly the two timing tests, and removing the
`awarded` term from `dueFrom` fails nineteen.

No gap of the kind tickets 06 and 08 through 11 carry: there is no native code in this
ticket, so nothing here is waiting on hardware.
