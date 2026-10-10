# Pomodoro Garden — v1.0 ticket breakdown

> ⚠️ **PRD v2.1: the app is free.** Ticket 18 is **withdrawn** and tickets 10, 17, 19, 20,
> 21 and 22 each carry an amendment note at the top saying which of their criteria the
> decision voided. Nothing was un-built except the purchase machinery itself — every
> feature premium gated ships, to everybody. See
> `docs/adr/0021-the-app-is-free-and-sells-nothing.md`.

Derived from `PRD.md`, which has been updated to **v2.0** to match these tickets. The two documents now agree; where they ever disagree, the ticket wins and the PRD should be corrected.

## Stack

| Concern | Choice |
|---|---|
| Framework | **Flutter / Dart**, one codebase, iOS + Android at parity |
| State management + DI | **Riverpod** — provider overrides keep the domain testable |
| Domain core | **Pure Dart, no Flutter imports** — timer state machine, growth model, plot placement, milestones |
| Persistence | **SQLite via Drift** |
| Timing | **Wall-clock anchor + scheduled local notification.** Never tick accumulation, never dependent on background execution |
| Garden rendering | **`CustomPainter` + `Canvas.drawAtlas`** — batched sprites, hand-rolled isometric depth sort and hit-test |
| Audio | **`just_audio` + `audio_session`** — the latter handles iOS audio-session category and Android audio focus |
| Minimum versions | iOS 17.0 · Android API 26 |

**Native code is confined to three places.** Everything else is Dart:

| Surface | Platform | Ticket |
|---|---|---|
| Live Activity + Dynamic Island | iOS, Swift | 08 |
| Foreground service + ongoing notification | Android, Kotlin | 08 |
| `AutomaticZenRule` quiet mode | Android, Kotlin | 11 |

## Decisions that are not in the PRD's original text

| Area | v1.0 PRD said | Decision |
|---|---|---|
| Platforms | Android an explicit non-goal | **iOS and Android**, shipped together |
| Stack | SwiftUI + Core Data + AVFoundation + UIKit | **Flutter** as above |
| Background timing | `BGAppRefreshTask` | **Wrong API** — it is opportunistic refresh, not a guaranteed wake. Replaced by wall-clock + scheduled notification |
| Live timer | Dynamic Island | iOS as specced; Android has **no equivalent** — foreground service instead |
| Focus/DND (REQ-014) | Auto-toggle on both | **Android only.** No public iOS API can activate a Focus mode. iOS ships a Shortcuts-wireable App Intent. See ticket 11 |
| Analytics | Apple App Analytics | **Local-only event log** behind a port. Consequence: most §11 KPIs are unmeasurable in v1 — accepted knowingly |
| Free tier plots | Open question #4, unanswered | **Uncapped** — and, as of v2.1, there is no tier: the app is free and every feature is every user's |
| Derived counters | `totalSessionsCompleted` stored in settings | **Derived by query** from `sessions`, along with garden level, plot count and streaks — a stored counter drifts from the rows it counts after a reset or milestone replay |

## PRD open questions

Resolved: **#1** tablets deferred to Phase 2 · **#2** bonus plants auto-placed · **#4** plots uncapped · **#5** all 6 plant types ship.

Still open, and now recorded in PRD §12: **#3** live-surface tutorial · **#6** custom ambient uploads · **#8** the reference Android device the 60fps budget is measured against · **#10** whether the garden may diverge visually between platforms. **#9** (Play pricing) is moot — the app is free.

## Skills

`/domain-modeling` and `/tdd` apply to the Dart domain core — heaviest on tickets 02, 04 and 05. `/prototype` before 07 and 08. `/code-review` and `/qa` close each ticket. `/setup-ts-deep-modules` and `/migrate-to-shoehorn` do **not** apply; they are TypeScript-only.

## Version control

**Since 2026-10-11 this is a git repository**, pushed to the private GitHub repo
`alexc02/pomodoro-garden` (branch `main`) at the owner's request. Tickets 01–39 were worked
without version control, and their issue files remain the record of what each did; from
here on, work is committed. Build output, caches and the regenerated art previews are in
`.gitignore`.

## Order

Files are numbered in dependency order. Work the frontier: any ticket whose blockers are all done. Ticket 01 is the only one with no blockers; 03 and 04 open in parallel once 02 lands.

## Tickets 25 to 27 — found by review, not by planning

01 to 24 were derived from the PRD up front. **25, 26 and 27 were not**: they are PRD requirements that the original breakdown never assigned to anybody, found by reading §3, §5.3 and §5.4 back against the code once 22 had landed. Each one names, at the top, why no existing ticket covered it.

| | | |
|---|---|---|
| 25 | Choose the end-of-session sound | REQ-031, REQ-008, **US-028 is P0**. The app ships one sound of six and has no control at all |
| 26 | The four micro-sounds | §9.2's soil settle, growth shimmer, button tap and unlock — counted in its fifteen assets, two of them specced in §5.4, owned by nothing |
| 27 | The plant blooms when the session ends | §5.3's fourth animation, the only one of its six never built |

All three are leaf tickets and every blocker they have is done, so all three were on the frontier together. **25 and 26 are done**; 27 is the only one left, and it is buildable today. **25 and 26 needed PRD §9.2's sound designer** the way 23 needs §9.1's illustrator — they were built against placeholders so that the delivery is a file swap, which is the strategy that has already worked for the art: five synthesised one-shots behind `endSoundAsset` and four more behind `MicroSound.asset`, with the real recordings dropping in over them.

**Store compliance is deliberately not a ticket here.** The privacy policy URL, the Play Data Safety form and the IARC rating that PRD §6.1 and §7.2 require — and which the v2.1 changelog notes nobody owns — are being tracked separately. *(Superseded: it is now ticket 38.)*

## Tickets 28 to 39 — from the v1.0 gap review (PRD v2.2)

The gap review (`../prd-gap-report.md`, 2026-10-10) checked every PRD requirement against the code, and the decisions taken on it are PRD **v2.2**. These twelve tickets are the work still owed before v1.0 ships on both stores. There is no illustrator or sound designer, so **28, 35 and 37 produce the art and audio in this repo**, and they take over most of what tickets 23 and 24 were waiting for. Numbered in working order (PRD §8.1.1): the steps that need the owner's judgement come first.

| | | Blocked by |
|---|---|---|
| 28 | One-plant art test. **Done:** watercolour rejected, **paper-cut** chosen | — |
| 29 | Sound sourcing: CC0 recordings for birdsong, forest and café. **Done:** all three found; birdsong is a blackbird | — |
| 30 | Log garden-theme changes (§7.1). **Done** | — |
| 31 | Break presets 5 / 10 / 15 (REQ-007). **Done** | — |
| 32 | Browse earlier months in the heatmap (REQ-027). **Done** | — |
| 33 | A timer bar on the garden: one tap to start (US-006). **Done** | — |
| 34 | The break runs while the phone is locked (REQ-032), with an ADR amending 0008. **Done** | 33 |
| 35 | The full art set, scenery restyle, icon and feature graphic. **Done:** approved by the owner | 28 |
| 36 | The willow glows and the golden garden shimmers (REQ-021). **Done** | 35 |
| 37 | The final audio. **Done:** approved by the owner | 29 |
| 38 | Store-compliance drafts in `docs/store/`. **Done** | 37 |
| 39 | Hand-off: iOS build, device checks and screenshots. **Owner's ticket** | 30–38 |

On the frontier now: **39**, the owner's: the iOS build, device checks, screenshots and the store checklist.
