# The app is free

The original plan was freemium: a one-time unlock for the extra themes, decor, three of
the ambient sounds and a watermark-free export. I dropped that. Everything is included
and there's no purchase in the app.

| Used to be premium | Now |
|---|---|
| Tropical Greenhouse and Wildflower Meadow themes | in the theme picker for everyone |
| Decor placement | the arrange button on the garden |
| Ocean, Café and White noise | regular chips on the timer screen |
| Export without a watermark | the only export there is |

The premium code was deleted, not switched off: `lib/src/premium/`, the `Entitlement`
types, the `entitlements` table, the premium tests and the `in_app_purchase` packages
(plus the Play `BILLING` permission). Leaving an `isPremium` that always returns true
would have kept a lot of dead branches around.

No one had bought anything (the app hadn't shipped), so nothing needed to be kept for
existing customers.

## What's left on purpose

- Migration step 15 still creates `entitlements` and step 18 drops it. Migration steps
  can't be edited after the fact, so a database old enough goes through both.
- The analytics events `paywall_viewed` and `premium_purchased` are gone, and
  `garden_exported` no longer has an `is_premium` parameter.

## Side effect

`in_app_purchase` was the only dependency that talked to a server. Without it nothing in
the app leaves the device, which made the Play Data Safety form and the privacy policy
simpler. Those still have to exist, as does the IARC rating.
