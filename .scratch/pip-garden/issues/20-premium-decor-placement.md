# 20 — Premium decor placement

> ⚠️ **Amended by the v2.1 decision that the app is free.**
> **The title is now wrong: decor is not premium.** Three criteria are void — *premium
> users can place decor*, *free users see decor in the paywall preview but cannot place
> it*, and *losing the entitlement leaves existing decor visible* — because there is no
> entitlement to have or lose. The arranging control is on the garden for every user.
> Everything about *placement* — the sowing rule, the one-pass draw, ADR 0017 — is
> unchanged. This ticket's feature is now **REQ-040**, which is also the number the code
> cites; it had been citing REQ-036, which is the garden reset.
> See `docs/adr/0021-the-app-is-free-and-sells-nothing.md` and PRD §3.6.

**What to build:** Premium users can place decorative items — a stone lantern, a bench, a birdbath, a pond — into empty plots and arrange them, making the garden feel personally composed rather than merely accumulated.

This is the deliberate alternative to capping free users' plots: the free garden stays uncapped per REQ-018, and premium sells expression rather than access.

**Blocked by:** 18, 7

**Status:** done — every criterion is built and covered. Two are qualified and both are named on their own lines: **ticket 21's export does not exist yet**, so what is delivered against it is a structural guarantee and a test that pins it rather than an exported image anybody has looked at; and **nobody has seen the four placeholder objects on a device**, which is ticket 19's gap inherited — this machine has no phone and no emulator. Nothing here is native, talks to a store or talks to the OS. The Dart side is 51 new app tests and 20 in the domain core: **809 and 382**, against 758 and 362 after ticket 19.

- [x] Premium users can place decor items into empty plots from a picker
- [x] Decor can be moved and removed; placement persists across relaunch
- [x] Decor occupies a plot but never blocks a plant — a completed session always finds a home, expanding capacity or displacing decor by a documented rule rather than failing. The rule is `GardenPlots.sow` and `docs/adr/0017-…`: **an object is stepped over while the garden has soil left, and gives way only when all two hundred plots hold something** — the outermost one first
- [x] Decor respects isometric depth ordering and does not break plant hit-testing from ticket 12 — one ordered walk for both, in the painter and in the hit-test, because a separate pass would put every object on one side of every plant
- [x] Decor is themed consistently with the active garden theme and season — the **material** is the biome's and holds still all year (ADR 0016); what a season reaches is what an object *holds*: a pond's water, the shadow under a bench, a lantern's light
- [x] Free users see decor in the paywall preview but cannot place it — the four objects are **drawn** on the paywall through the same registry the garden uses, not listed in a sentence. **The garden offers a free user no door at all**, and that is REQ-041 rather than an oversight; see the decision below
- [x] Placed decor is included in the garden export from ticket 21 — **ticket 21 has not been built.** What is delivered is the reason it will not have to think about decor: an export is `GardenPainter` at a whole-garden projection, and decor is in the batch that painter produces. Pinned by a test written in the export's own shape; see **Verification gaps**
- [x] Losing the entitlement leaves existing decor visible rather than deleting the user's arrangement
- [x] Placeholder decor art until ticket 23 — behind `DecorSpriteRegistry`, the same seam ticket 04 gave the plants

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/garden/decor.dart` | `DecorKind` — REQ-040's four — and `Decor`, one object in one plot |
| `packages/pomodoro_domain/lib/src/garden/decor_repository.dart` | The port. Nothing in it asks who owns anything |
| `packages/pomodoro_domain/lib/src/garden/garden_plot.dart` | `GardenPlots.sow` and `Sowing`: where a plant goes, and what leaves for it |
| `packages/pomodoro_domain/lib/src/garden/garden_layout.dart` | The garden now holds decor too — `decorIn`, `hasPlot`, `isEmpty`, and an `emptyPlots` that counts a bench as occupied |
| `lib/src/data/database.dart` | Schema 17: the `decor` table, one thing to a plot, and the step that creates it |
| `lib/src/data/drift_decor_repository.dart` | The round trip, and the rule about a kind this build has never heard of |
| `lib/src/garden/decor_sprite.dart` | `DecorSprite` + `DecorSpriteRegistry` + `DecorPalette` — ticket 23's seam |
| `lib/src/garden/placeholder_decor_sprites.dart` | Four objects drawn from ovals and rectangles |
| `lib/src/garden/garden_atlas.dart` | Was `plant_atlas.dart`. Now bakes the plants *and* the decor into one texture |
| `lib/src/garden/garden_painter.dart` | One walk, one batch: ground, then whatever is standing on it |
| `lib/src/garden/garden_hit_test.dart` | `GardenTarget` — plant, decor or bare soil — with `plantAt` unchanged over the top |
| `lib/src/garden/decor_providers.dart` | The arrangement, the registry, `mayArrangeDecorProvider`, and `DecorArranger` |
| `lib/src/session/session_providers.dart` | `_sow` asks the rule with the arrangement in hand |
| `lib/src/garden/milestone_providers.dart` | And so does an award — a bonus plant has the same claim on a plot |
| `lib/src/features/garden/decor_picker.dart` | The picker sheet, the arranging bar, and `DecorMark` — one object drawn small |
| `lib/src/features/garden/garden_screen.dart` | The way in, and the arrangement in the sentence a screen reader hears |
| `lib/src/features/garden/garden_view.dart` | What a tap means, which depends on what the user is doing |
| `lib/src/features/premium/paywall_screen.dart` | The four objects, previewed as pictures |
| `docs/adr/0017-decor-never-costs-a-plant-its-plot.md` | The displacement rule, and why an object is deleted where a plant is kept |
| `CONTEXT.md` | Four words: decor (widened), decor item, arrangement, arranging — and sowing |

## The five things worth knowing before picking up ticket 21 or 23

**A plot holds a plant or an object, never both — and that is what makes the depth
sort free.** Both come out of one walk over one ordered list of plots, in the painter
and in the hit-test alike. A separate pass over the furniture, whether before the plants
or after them, would put every object in front of every tree or behind every tree; there
is no third option, because a batch is an order. The atlas bakes both kinds of picture
into one texture for the same reason: two textures would be two `drawAtlas` calls and so
two batches. `PlantAtlas` was renamed `GardenAtlas` to stop the name lying about what is
in it — six files, and the analyzer would have caught any miss.

**A plant is never turned away for furniture, and the rule is narrower than it
sounds.** ADR 0017: an object is *stepped over* while the garden has soil left, so an
arrangement is exactly as the user composed it for the whole life of every real garden;
only when all two hundred plots hold something does the outermost object give way, and
then it is deleted rather than kept. The guarantee is therefore exact — **decor is never
the reason a completed session goes unplaced.** A plant that has no plot in a garden with
decor in it would have had no plot without it either. ADR 0006's case is untouched.

**The entitlement decides what the user may change, never what the garden draws.**
`decorProvider` and `GardenLayout` never ask who owns anything, so a device whose
entitlement goes absent opens the garden it arranged; the arranging control disappears
and every write is refused until premium is back. This is ticket 19's split said again in
a sharper form: there is no method anywhere that deletes an arrangement for want of an
entitlement, deliberately, on the same reasoning `EntitlementController` has no way to
take premium away.

**The garden has no paywall door, and that is REQ-041.** The paywall opens from settings
and the theme picker *and nowhere else*, so a locked arranging control here could not do
what a locked theme card does — it would have refused with nowhere to send anybody. So a
free user meets decor where REQ-041 puts it: **drawn** on the paywall, through the same
registry the garden draws its own from, rather than named in a list. Ticket 23 replaces
both at once by replacing neither.

**Decor art is behind the same seam the plants are.** `DecorSpriteRegistry`, keyed by
kind rather than by type and stage, overridden in one line in `decor_providers.dart`, and
enforced by `test/garden/sprites_are_the_only_art_test.dart` alongside the plant one.
Ticket 23's "decor art replaced" should be the same swap it already is for the thirty
plant sprites.

## Two smaller decisions

**The plot is chosen first and the object second.** The picker opens *for a plot the user
has already tapped*, which is the opposite of how a palette usually works and is the right
way round on a surface somebody is composing on: nothing can be armed and forgotten, and a
stray tap on the garden cannot leave a lantern somewhere they have to go and find. It also
removes a state — there is no "a bench is armed, waiting for a plot".

**Arranging is a mode, and it announces itself.** A garden where a tap might open a card
*or* pick up a bench is a garden to be careful in, and being somewhere to look at is what
this screen is for. So the mode is entered deliberately, the bar says what a tap will do
in the state the user is actually in, and a session starting underneath ends it — the same
judgement REQ-041 makes about the paywall, for the same reason.

## Verification gaps

- **Ticket 21's export does not exist, so nothing has been exported.** What is asserted
  is the structural claim the criterion actually rests on: `GardenPainter`, at a
  projection fitted to the whole garden with no camera involved, produces a batch
  containing every plot, every plant and every object and nothing twice. When ticket 21
  lands it should need no decor-specific code at all; if it finds itself reaching for
  `decorProvider` separately, something has gone wrong upstream of it.
- **Nobody has looked at the four objects.** They are asserted to be distinct pictures,
  to stand on the bottom of their cells, to stay inside them, and to be shorter than the
  tallest plant — which is the rule they were drawn to, so that an ornament never upstages
  the oak a ninety-minute session grew. What none of that says is whether a bench *reads*
  as a bench at a zoomed-out garden's scale. A designer should sit with the picker on a
  device. Ticket 23 replaces all four anyway, which is why the shapes were kept crude.
- **The displacement rule has been run to its edge in the domain and twice through the
  app, and no user has ever seen it.** It takes four hundred and seventy completed
  sessions to reach in real life. The tests fill a garden by writing plants straight into
  the ground rather than sitting through them.
- **No analytics event.** PRD §7.1's table has no `decor_placed` in it and this ticket was
  not asked to add one, so nothing here is recorded. If arranging turns out to be worth
  measuring, it is a new `AnalyticsEvent` member and one call site in `DecorArranger`.
- **Pre-existing, still open:** `lib/src/data/database.dart` cites "ADR 0014" for ticket
  17's decision not to backfill the event log, and no ADR 0014 exists. This ticket's ADR
  is 0017 rather than filling the gap, for the reason tickets 18 and 19 gave when they
  chose 0015 and 0016.
