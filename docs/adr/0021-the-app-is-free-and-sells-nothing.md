# The app is free, and sells nothing

PRD v2.0 shipped a freemium model: REQ-038's one-time $4.99 unlock, REQ-039's free tier,
REQ-040's premium tier and REQ-041's paywall. That is no longer the product. **Pomodoro
Garden is free, the whole of it, and there is no purchase in the app at all.**

This ADR records what that decision removed, what it deliberately did *not* remove, and
the two things it left standing that look like leftovers and are not.

## The decision

Everything the four requirements sold is now simply part of the app:

| What premium sold | What it is now |
|---|---|
| Tropical Greenhouse and Wildflower Meadow (REQ-034) | Two of the three themes in the picker, applied by tapping them |
| Decor placement (REQ-040) | The arranging control on the garden, present for every user |
| Ocean, Café and White noise (REQ-039) | Three of the six chips on the timer screen, unmarked |
| A watermark-free export (REQ-035) | The only kind of export there is |
| "Enchanted Garden" plants and session labels (REQ-040) | Never built. Dropped from the PRD rather than left as a promise |

And the machinery behind them is gone rather than dormant: `lib/src/premium/`,
`lib/src/features/premium/`, the domain's `Entitlement` and `EntitlementStore`, the
`entitlements` table, `test/premium/`, `docs/store-configuration.md`, ADR 0015, and the
`in_app_purchase` dependencies with the Play `BILLING` permission that came with them.

**Deleted rather than switched off, and that is the substance of the decision.** An
`isPremiumProvider` that returned `true` would have left every gate, every fallback and
every "what a free user sees" branch in the code, all of them now unreachable and none of
them obviously so. The next person to read `gardenThemeProvider` would have found a filter
that has no false case, and would have had to work out whether that was deliberate. What
is deleted asks nobody anything.

## What this cost, and who pays it

**A user who already bought premium.** Nobody did — the app has never shipped, and ticket
18's own status records that no purchase was ever made against either store — so this is
a cost the decision was allowed to take. Had there been paying users, the entitlement
table would have had to stay as a permanent no-op, because dropping it would be the app
forgetting a payment it took.

**Two KPIs.** PRD §11's premium-conversion targets are not missed, they are gone: there is
no conversion to measure. §7.1 loses `paywall_viewed` and `premium_purchased` with the
screens that emitted them, and `garden_exported` loses its `is_premium` parameter, which
separated two kinds of export that no longer differ.

## What survives, and why it is not a leftover

**The migration step that creates `entitlements`.** Version 15 still creates the table and
version 18 drops it, so a database old enough walks through both. The step could not be
deleted: every step in `AppDatabase.migration` leaves behind the shape of the version it
introduces, and a step edited to describe a later version breaks every step after it. The
table is created and dropped three versions later, and that is correct rather than untidy.

**The `decor` table, the arranging mode and the theme picker.** The paywall was removed;
the features it gated were not. Deleting a feature because it used to be sold would be
answering a business question with a delete key.

## The consequence worth writing down

**§7.2's privacy promise got simpler, and the app got smaller.** The three
`in_app_purchase` packages were the only dependencies in this project that talked to a
server — `test/analytics/nothing_leaves_the_device_test.dart` carried a four-paragraph
justification for why §7.2 survived them. It does not need one now: every remaining
package talks to this device and to nothing else, and the Play listing needs no billing
declaration, because there is no billing.

The one thing that did **not** get simpler is the store paperwork §7.2 and §6.1 still
require — a hosted privacy policy URL, Play's Data Safety form and the IARC rating. A free
app needs all three exactly as a paid one does.
