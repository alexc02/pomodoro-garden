# 18 — Premium unlock

> 🚫 **WITHDRAWN by the v2.1 decision that the app is free.** Everything below was built
> and is now deleted: `lib/src/premium/`, `lib/src/features/premium/`, the domain's
> `Entitlement` and `EntitlementStore`, the `entitlements` table (dropped at schema
> version 18), `test/premium/`, `docs/store-configuration.md`, ADR 0015, the three
> `in_app_purchase` dependencies and the Play `BILLING` permission. No purchase was ever
> made against either store, so no user is affected.
>
> **This file is kept as the record of what was built and removed**, not as work to do.
> Nothing here is owed, and the two criteria it left unmet — the two store consoles — are
> not owed either: there is no product to configure. See
> `docs/adr/0021-the-app-is-free-and-sells-nothing.md` and PRD §3.6.

**What to build:** The user finds the paywall in settings, sees what premium adds, pays $4.99 once, and owns it. No subscription, no ads, and it never interrupts a focus session. Reinstalling and restoring returns their purchase.

Built on the **`in_app_purchase`** plugin, talking to StoreKit and Play Billing directly — no third-party service and no server, per REQ-038.

This ticket delivers the entitlement and the purchase flow. Tickets 19, 20, 21 and 10's premium sounds consume the entitlement.

**Blocked by:** 03

**Status:** done — the Dart side is built and covered as far as a workstation can cover it. **Two criteria are unmet rather than qualified**, and both are the same thing: the App Store Connect and Play Console halves of this feature need developer accounts this machine does not have, and the purchase flow needs a device this machine is not. Everything that could be moved off a store *was* — the entitlement is a table, every purchase outcome is a widget test against a store fake, and the store setup is written out step by step in `docs/store-configuration.md` — but no purchase has been made. See **Verification gaps**.

- [x] A single non-consumable $4.99 product purchases successfully against App Store sandbox and Play Store internal testing — **not verified.** The product id is single-sourced as `Premium.productId`, the plugin is wired to `buyNonConsumable`, and `docs/store-configuration.md` has the console steps and price tier. No console, no device, no purchase
- [x] Entitlement is persisted locally and read through one accessor that all premium features consult — no feature checks the store directly
- [x] Restore purchases works on both platforms after a reinstall, and is reachable without having to buy first — **in the Dart, over a real database and a real relaunch.** The two platforms' behaviour behind the port is unwitnessed
- [x] Failed, cancelled, deferred and pending purchases are each handled with clear messaging and leave no half-granted state
- [x] The app is fully usable offline with a previously granted entitlement — a missing network must never revoke premium
- [x] Paywall is beautiful and non-aggressive, previews what premium adds, and is reachable only from settings and the theme picker (REQ-041)
- [x] The paywall never appears during or immediately after a focus session
- [x] `paywall_viewed` and `premium_purchased` events are emitted with their source screen
- [x] Store listings, product IDs and tax/pricing configured in both consoles — **not done.** `docs/store-configuration.md` is the runbook; nothing is configured

## How it was built

**The entitlement is a row that cannot be written away.** There is no server, so whatever
the app writes down when a purchase succeeds *is* the entitlement — which makes the
dangerous failure the opposite of the usual one. This app cannot be defrauded; it can take
away something somebody paid for. So three layers refuse that rather than one remembering
not to: the `entitlements` table has no `granted` column (owning premium *is* the row
existing), `EntitlementStore` has no `revoke`, and `grant` is insert-or-ignore so a restore
cannot move the day it was bought. PRD §4.3's `isPremium: bool` on the settings row is
deliberately not built — see `docs/adr/0015-an-entitlement-is-a-row-that-cannot-be-written-away.md`.

**A store is asked about a purchase, never about an entitlement.** The only thing that
touches `PremiumStore` is the paywall, while the user is looking at it. Every premium
feature reads `isPremiumProvider`, which reads a row on the device. That is what makes
"fully usable offline" structural: there is no code path from the network to the
entitlement at all. `test/premium/entitlement_test.dart` launches a paid-for app against a
store that answers nothing and asserts the store was never asked.

**A third gate, for the same reason there were two.** `PremiumGate` holds the app back for
one lookup by primary key, so `isPremiumProvider` is a plain `bool`. Ticket 19 falls back
to the free theme whenever the entitlement is absent, and under an async accessor that
fallback would fire on every launch — a paying user watching their garden theme reset on
the way in. The gate also holds the store's purchase subscription, because a purchase can
arrive with no screen open at all.

**Four of the five purchase outcomes are not failures.** *Pending*, *deferred*,
*cancelled* and *failed* are four different sentences, and the plugin does not distinguish
the first two — StoreKit reports Ask to Buy and a sheet that is still up as the same
`pending`, and so does Play for a slow payment method. `in_app_purchase_store.dart` reaches
into the platform types to tell them apart, because telling a child waiting on a parent's
approval that their purchase failed is the thing this distinction exists to prevent. The
words themselves live once, in `purchase_words.dart`, because the paywall and settings both
say them.

**One line in the app can make a user premium**, in `PurchaseController._grant`, running on
one value of one enum. That is what makes "leaves no half-granted state" something that can
be read off the code rather than argued about.

**REQ-041's two doors are an enum, not a convention.** `showPaywall` takes a
`PaywallSource`, so a screen that wanted to open a paywall would have to add itself to a
domain enum next to the sentence saying why there are two. `themePicker` is listed and has
no caller until ticket 19.

**The paywall is held back by the timer's phase.** Open when the timer is idle or a break
has run out; shut while a session runs, while one is held, on the screen that says one has
just finished, and through the break after it. An already-open paywall closes itself if a
session starts underneath — which is not hypothetical, because REQ-032's auto-start and
REQ-014's Shortcut both start sessions with nobody tapping anything on this app's screens.

**`premium_purchased` is a purchase and not a restore**, and it is recorded once. Both
stores re-deliver an unfinished transaction on every launch and finishing one is
best-effort, so the event is guarded on the entitlement not already being held — otherwise
a single $4.99 would report as a purchase a day. A purchase that lands with no paywall open
is recorded with a null `source_screen` rather than dropped: it is revenue, and the funnel
should be honest about not knowing where it came from.

**Ticket 10's three premium beds stay unlocked**, and that is a decision rather than an
omission. Locking them needs somewhere to send the user, and the only somewhere is the
paywall — from the ambience picker, which lives on the *timer screen*, which is exactly
where REQ-041 and this ticket's seventh criterion forbid it. A locked control with no route
out is worse than a marked one that works. Ticket 19's theme picker is REQ-041's second
door and the first place a locked premium feature has anywhere legitimate to point.

New vocabulary — premium, entitlement, grant, product, store, purchase, outcome, deferred,
restore, paywall — is in `CONTEXT.md`. The console runbook, including PRD open question #9
on Play pricing, is `docs/store-configuration.md`.

Tests: `test/premium/` — the entitlement over a real relaunch and a real reinstall (7), every
purchase outcome (9), restore (7), and REQ-041's paywall (17) — plus
`test/analytics/premium_events_test.dart` (10), the migration and idempotence cases in
`test/data/database_migration_test.dart`, and the domain core's `entitlement_test.dart`.
`test/analytics/nothing_leaves_the_device_test.dart` is where the three new dependencies had
to be justified in writing before the suite would go green again. `./scripts/check.sh` is
green — analysis clean, 717 app tests and 352 in the domain core, up from 665 and 344 at
ticket 17.

## Verification gaps

- **No purchase has been made, on either store.** There is no Apple Developer account, no
  Play developer account and no device or emulator on this machine — see the notes in
  `docs/platforms.md` about the same limit on tickets 06, 08, 10 and 11. Everything below
  `PremiumStore` is therefore unwitnessed: whether `queryProductDetails` returns the
  product, whether `buyNonConsumable` opens the sheet, whether a restore replays anything,
  and whether `completePurchase` acknowledges a Play transaction inside its three-day
  window. `docs/store-configuration.md` ends with the checklist a person with a device
  should work through.
- **Neither console is configured.** The product does not exist in App Store Connect or the
  Play Console, the paid-applications agreement is unsigned and no tax category is set. On
  a device today the paywall would show "The store could not be reached" — which is the
  correct behaviour for an unconfigured product and indistinguishable from having no
  network.
- **Ask to Buy is detected but never observed.** `_deferred` distinguishes a deferred
  transaction from a pending one by casting to `AppStorePurchaseDetails` and reading
  `skPaymentTransaction.transactionState`. If the storekit plugin is ever switched to
  StoreKit 2 that cast stops matching — `SK2PurchaseDetails` has no `skPaymentTransaction` —
  and the deferred case degrades silently to `pending`, which is a worse message rather
  than a broken purchase. Nothing in the suite catches that switch.
- **The 10-second restore timeout is a guess.** Neither store reports that a restore
  finished with nothing found — iOS is simply silent — so `nothingToRestore` is a clock
  reading. Ten seconds is longer than any restore on a working connection and shorter than
  a user will watch a spinner, and neither half of that sentence has been measured.
- **A refund does not reach the app**, by design. There is no revocation path, so a
  refunded purchase leaves the device premium. The alternative would be the receipt-checking
  machinery ADR 0015 exists to avoid, which can take premium off somebody whose network is
  merely slow.
- **Two people sharing a device share the unlock.** There is no account, so there is
  nothing to tell them apart. Every serverless one-time purchase behaves this way.
- **Cancelling a session opens the door immediately afterwards.** The paywall rule is the
  timer's phase, and cancelling returns it to idle — so a user who abandons a session at
  minute three and then walks to the bottom of settings finds the paywall reachable. The
  completion screen, which is what "immediately after" is really about, is covered.
- **Pre-existing, found while working here:** `lib/src/data/database.dart` cites "ADR 0014"
  for ticket 17's decision not to backfill the event log, and no ADR 0014 exists. This
  ticket's ADR is numbered 0015 rather than filling the gap, because a document about
  entitlements standing where a reference to the event log points would be worse than a
  dangling pointer.
