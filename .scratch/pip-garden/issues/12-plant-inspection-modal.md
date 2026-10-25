# 12 — Tap a plant to hear its story

**What to build:** The user taps any plant in the garden and a card rises showing what it is, when it was planted, how long that session was, and a gentle line about growth or patience. Every plant becomes a memory of an afternoon's work rather than an anonymous sprite.

**Blocked by:** 07

**Status:** done — every criterion is built and covered. One is qualified, and it is ticket 06's gap inherited rather than a new one: **this machine has no iOS device, no Android device and no emulator**, so the back *gesture* has been driven through the platform channel it arrives on rather than by a thumb. The Dart side is 39 new tests — 16 through the real app, 15 on the hit-test arithmetic, 5 at the pixels and 3 on the atlas — less the 3 that covered the projection method this ticket deleted, plus 7 in the domain core: 492 and 230 now, against 456 and 223 before.

- [x] Tapping a plant opens a modal card with species name, planted date, session length, and growth stage (REQ-020)
- [x] Hit-testing is accurate in isometric space — the plant the user visually taps is the one that opens, including where sprites overlap
- [x] Tapping empty soil does nothing; tapping a locked plot does nothing
- [x] A quote about growth or patience is shown, drawn from a bundled set and stable for a given plant rather than reshuffling on each open
- [x] Species names use the handwritten botanical label treatment from §5.1
- [x] The card dismisses by swipe, backdrop tap and the platform back gesture
- [x] Works at every zoom level

## What was built

| Where | What |
|---|---|
| `packages/pomodoro_domain/lib/src/garden/plant_quote.dart` | The bundled lines, and the rule that a plant always says the same one |
| `lib/src/garden/plant_sprite.dart` | `footprintIn` on the sprite seam: how much of its box a plant actually fills |
| `lib/src/garden/placeholder_plant_sprites.dart` | The placeholders' answer to it, measured off the same geometry they paint from |
| `lib/src/garden/plant_atlas.dart` | `footprintFor`, baked alongside each cell — the picture the garden draws, and its extent, decided together |
| `lib/src/garden/garden_hit_test.dart` | A tap ↦ the plant the user could see there |
| `lib/src/garden/garden_projection.dart` | `plotAt` deleted: nothing calls it now, and its doc described the approach this ticket rejected |
| `lib/src/features/garden/plant_card.dart` | REQ-020's card, and the three dismissals |
| `lib/src/features/garden/garden_view.dart` | The tap, and the gestures moved inside §5.3's entry |
| `CONTEXT.md` | The three words this ticket introduced: footprint, card, quote |

## The one thing worth knowing before picking up a dependent ticket

**A sprite now says how much of its box it fills, and ticket 23 has to answer.** Ticket 07
left hit-testing as "the tile under the finger, not the plant standing on it", and suggested
refining it by walking the plots front to back against `spriteBounds`. That is half the
answer and the half that is wrong on its own: a plant's box is a square as wide as a tile
and as tall as a large tree, so a wildflower's box covers the trunk of the tree two rows
behind it. Walking front to back against the *boxes* would hand the wildflower every tap
meant for that trunk — the exact failure this ticket's second criterion names.

So the box is not what is tested; the plant's **footprint** is, and only the picture knows
what that is. `PlantSprite` gained one method, `footprintIn(Rect bounds)`. The placeholders
compute it from the same `_Anatomy` their `paint` draws from, so the two cannot drift, and
`test/garden/plant_footprint_test.dart` renders every one of the thirty sprites and checks
the claim against the pixels actually inked — in both directions, because a footprint that
is too small leaves an untappable edge and one that is too large steals its neighbour's
taps.

**Ticket 23 inherits this**: real watercolour art supplies `footprintIn` as the tight bounds
of its own ink. It is still an asset-and-registry swap — no growth, timer, layout or
hit-test logic changes — but it is one more line per sprite than it was before this ticket,
and a registry that returned the whole box would silently undo the second criterion above.

The footprint is asked of the **atlas**, not of the registry, and that is deliberate:
`PlantAtlas.bake` is the one place that decides which sprite goes into a plant's cell —
today `(species.type, mature)`, because only a completed session earns a plant. A hit-test
that asked the registry for a sprite of its own would be a second copy of that decision,
and the first garden to hold something that is not a mature plant of its own species' type
— ticket 13's milestone plants are the obvious candidate — would start sending taps to the
wrong plant, with nothing on screen to show for it. So the atlas bakes each cell's
footprint beside its picture, as a fraction of the cell, and hands both out.

## Four smaller decisions

**REQ-020's growth stage is on the card and always says "Mature".** Not an oversight: a
plant only reaches the garden by completing, so `Plant.stage` is mature for every one of
them, and `Plant` says so. The field is shown because the requirement asks for it and
because ticket 13 or a future half-grown plant would make it carry information; today it is
an honest constant rather than a missing row.

**The card draws the plant at the top of itself.** Neither the ticket nor REQ-020 asks for
that — the ticket asks for the facts and the quote. It is here because the ticket's own
sentence is "every plant becomes a memory of an afternoon's work rather than an anonymous
sprite", and a card about a plant with no plant on it argues the opposite. Drawn through
the registry like everything else, so ticket 23 gets it for free.

**A tap that lands on no plant's picture falls through to the plot underneath.** Otherwise a
stem three pixels wide would be the whole target. This is also why "tapping empty soil does
nothing" and "tapping a locked plot does nothing" are not two branches: both come out of
`GardenLayout.plantIn`, which answers null for bare soil and for a plot the garden does not
have.

**The gestures moved inside §5.3's entry animation.** They were wrapped around the fade and
scale, which meant that for the half-second the garden is arriving, a touch was read in the
*parent's* coordinates while the garden was drawn 5% smaller in the child's. Nothing before
this ticket noticed, because a pan is a delta and a delta scaled by 0.95 still pans. A tap
is an absolute point, and it would have landed a few pixels from where the user put it.

## Verification gap

**The back gesture has not been made by a thumb.** The card is a route, so it is popped by
whatever the platform sends — and what the platform sends is `popRoute` on the navigation
channel, which is what `test/garden/plant_card_test.dart` drives. That is the same message
Android's back gesture and back button both produce, and on iOS a modal sheet has no back
gesture other than the swipe, which is tested for real. What is unwitnessed is the same
thing tickets 06, 08, 10 and 11 could not witness: no phone has run this. Ticket 24 is where
the hardware arrives.

Worth flagging for that ticket while it is here: the app targets SDK 36, where Android's
**predictive** back is the default and the legacy `onBackPressed` path is gone. Flutter
routes the new callback to the same `popRoute`, so the card should dismiss either way — but
"should" is doing work in that sentence, and it is a one-minute check on a real device.
