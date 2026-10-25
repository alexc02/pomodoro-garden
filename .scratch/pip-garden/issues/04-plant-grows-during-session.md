# 04 — A plant grows through five stages while you focus

**What to build:** The moment a session starts, a seed drops into the soil. As the session progresses the plant visibly advances through sprout, young, maturing and mature — and *which* plant it is depends on how long the session is, so a 15-minute session grows an herb and a 90-minute session grows a large tree.

The plant art does not exist yet. Build against a sprite registry keyed by plant type and growth stage, fed by simple placeholder shapes. Ticket 23 swaps the real watercolour art in through that same registry with no logic changes, so the registry seam is the most important thing this ticket delivers.

**Blocked by:** 02

**Status:** completed

- [x] Session duration maps to plant type per REQ-015 across all six bands, with the boundary values (14/15, 24/25, 34/35, 49/50, 74/75) each covered by a test
- [x] Growth stage is a pure function of elapsed fraction, advancing at 0%, 20%, 50%, 80% and 100% — tested at and either side of each threshold
- [x] A species is chosen within the type at plant time and stays stable for the life of that plant
- [x] Stage transitions animate with a spring that overshoots slightly; the seed drop animates into the soil at session start
- [x] Mature plants have a continuous gentle sway, randomised per plant so a garden of them does not pulse in unison
- [x] All sprites resolve through a registry keyed by (type, stage); no view code references an image directly
- [x] Plant records persist with type, species, stage, planted date and originating session duration
- [x] Renders identically on both platforms

## What was built

**The growth model, in the domain core** (`packages/pomodoro_domain/lib/src/garden/`).
`PlantType.forSessionLength` is REQ-015's table as data, walked in ascending
order and total at both ends. `GrowthStage.forProgress` is REQ-016's five
stages as a pure function of progress — nothing advances a stage and nothing
fires at a threshold, so a plant looks right whether the app watched the whole
session or has just been reopened.

**A plant is decided by its session, not rolled for.** The type comes from the
planned duration; the species comes from a hash of the session's id, so the
choice is made when the seed drops and every later ask re-derives the same
answer. That is what makes the plant on screen and the plant in the garden the
same plant without any state passing between them. The hash — `stableFraction`
— is written out rather than taken from `hashCode`, because the same session
has to choose the same species on both platforms and in every future Dart.

**The registry seam** (`lib/src/garden/plant_sprite.dart`). Thirty sprites, six
types by five stages, behind `PlantSpriteRegistry.spriteFor(type:, stage:)`.
Placeholders are drawn from circles and lines;
`test/garden/sprites_are_the_only_art_test.dart` fails on any view code that
names an image, and was verified to go red on a real violation. Ticket 23
supplies a different registry and touches nothing else. Species varies colour
rather than shape, which is consistent with ticket 23 delivering 6 × 5 drawings
rather than one per species.

**The animations** are §5.3's, driven off the session snapshot: a 0.8s seed
drop with a soil burst on landing, a 1.2s underdamped spring (ratio 0.7) on
each stage change, and a 4s ±2° sway on mature plants, offset per plant from
the same hash so a garden does not pulse in unison. The sway eases in, so a
plant that matures mid-swing drifts into its lean instead of snapping to it.

**Persistence.** Schema version 3 adds `plants`, with a unique index on
`sessionId` so one session grows one plant however many times its completion is
noticed. Nothing is backfilled for an upgrading user: their old sessions grew
plants nobody ever chose a species for, and inventing a garden is worse than
starting one.

## Decisions worth knowing downstream

- **`SessionSnapshot` gained `growing`.** What a session is growing is part of
  what the timer *is* at an instant, and putting it there avoided handing the
  running session out to be re-read.
- **A mature plant never settles, so `pumpAndSettle` cannot be used on one.**
  The harness grew `settle(tester)`, which pumps a bounded run of frames;
  `tapTab` uses it. Any new helper should.
- **`AppShell` now wraps each tab in a `TickerMode`.** This ticket introduced
  the app's first continuous animation, and an `IndexedStack` would otherwise
  keep it repainting on tabs nobody is looking at.
- **Ticket 13's milestone plants** arrive as new `PlantType` members, not as a
  third registry key: the placeholder registry is built from `PlantType.values`
  and picks them up on its own.
