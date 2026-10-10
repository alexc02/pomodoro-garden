# 📋 Product Requirements Document (PRD)

# Pomodoro Garden

**Version:** 2.2  
**Last Updated:** October 2026  
**Author:** Product Team  
**Status:** Draft  

---

## Changelog — v2.1 → v2.2

**Decisions from the v1.0 gap review** (`.scratch/pomodoro-garden/prd-gap-report.md`,
2026-10-10). The review checked every requirement against the code. v2.2 does two things:
it adds the work still owed before v1.0 ships, and it corrects the places where the PRD
described something the app deliberately does differently. **The goal is unchanged: v1.0
ships on both stores together.** There is no team beyond the owner, so art and audio are
produced in-repo rather than commissioned (§9).

| Section | Change |
|---|---|
| §3.2 REQ-005 | The completion notification is scheduled when the app **leaves the foreground**, not at session start; in the foreground the app plays the end sound itself. Same guarantee, no double chime |
| §3.2 REQ-007 | Break presets **5 / 10 / 15** are one-tap choices beside the slider — *new work*. The long break stays derived: 3× the break, capped at 30 min |
| §3.2 REQ-008 | Corrected to six end sounds, matching REQ-031 |
| §3.2 REQ-013 | **iOS caveat accepted:** a force-quit of an app iOS has already suspended sends no signal, so that session may be restored rather than voided. Android voids correctly |
| §3.3 REQ-021 | The willow's glow and the Golden Garden's shimmer ship **in v1.0** — *new work* — with a debug-only preview |
| §3.4 REQ-027 | The heatmap can step back to earlier months — *new work* |
| §3.5 REQ-032 | Auto-start break now replays the **break only** while the app is away — *new work*. A focus session is never started in the background |
| §3.5 US-006, §5.2 | A timer bar on the garden screen makes START one tap from launch — *new work*. Screen 2 is recorded as built |
| §4.3 | Data model brought up to the shipped schema (v19) |
| §4.4, §10 | Performance targets are **measured, not release-blocking**. Android is verified on an emulator only; the aggressive-OEM risk is accepted for v1.0 |
| §5.1 | Typography recorded as built: Nunito and Caveat, bundled |
| §5.1, §6.2, §9, REQ-022 | **The art style is paper-cut, not watercolour.** Art is produced by an in-repo generator; a watercolour version was built and rejected by the owner at the one-plant test (ticket 28). Audio is synthesis plus CC0 recordings; ambient loops are 15 s PCM WAV (ticket 37); end sounds are PCM |
| §6, §7.2 | Store-compliance texts are drafted in `docs/store/`; hosting the privacy policy and filling in the store forms is the owner's |
| §7.1 | `settings_changed` covers the garden theme — *new work* |
| §8.1 | Status column made honest; the remaining v1.0 work is listed in §8.1.1 |
| §12 | #8 resolved |

---

## Changelog — v2.0 → v2.1

**The app is free.** v2.0 specified a freemium product with a one-time $4.99 unlock;
v2.1 removes monetization from v1.0 entirely. Every feature premium gated is now part
of the app, the paywall and the purchase are gone, and no code in the app talks to
StoreKit or Play Billing. Product intent, design language, the garden, the timer and the
privacy stance are unchanged. See `docs/adr/0021-the-app-is-free-and-sells-nothing.md`.

| Section | Change |
|---|---|
| §2.1 | Monetization goal removed; §2.3 gains "charging for anything" as a non-goal |
| §3.5 | REQ-034 and REQ-035 no longer name a tier — all three themes and clean exports are everyone's |
| §3.6 | Epic 6 rewritten: the freemium epic becomes one requirement saying the app is free. REQ-038 is now "no monetization"; REQ-039, REQ-040 and REQ-041 are retired or repurposed — **REQ-040 is now garden decor**, which the tickets and the code had been citing as REQ-036 |
| §4.1 | The `in_app_purchase` row is gone from the stack |
| §4.3 | The `entitlements` table is dropped at schema version 18 |
| §5.4 | The export watermark is gone |
| §7.1 | `paywall_viewed` and `premium_purchased` removed; `garden_exported` loses `is_premium` |
| §7.2 | The three store packages were the only dependencies that reached a server; the privacy stance is now unqualified |
| §8.1 | Ticket 18 is withdrawn; tickets 19, 20 and 21 lose their gating |
| §9.1 | Alternate app icons were an iOS-only *premium* perk; they are simply out of v1 |
| §11 | Premium-conversion KPIs removed |
| §12 | Open question #9 (Play pricing) is moot |
| §13.2 | The competitive table's price column is now "Free" |

**One thing this does not change:** Play still requires a hosted privacy policy URL, a
Data Safety form and an IARC rating (§6.1, §7.2). A free app needs all three exactly as a
paid one does, and none of them is owned by a ticket yet.

---

## Changelog — v1.0 → v2.0

v1.0 specified an iOS-only product built on an Apple-native stack. v2.0 targets **iOS and Android at parity from a single Flutter codebase**. Product intent, design language, ASO strategy and success metrics are unchanged; only the technical and platform sections were rewritten.

| Section | Change |
|---|---|
| §2.3 | Android removed from non-goals — it is now a v1.0 target platform |
| §3.2 | REQ-005 timer engine rewritten (see risk note below); REQ-010/011 gained an Android live-timer surface; REQ-014 rewritten — see the platform-asymmetry note |
| §3.6 | REQ-039/040 revised: garden plots are uncapped for free users; premium sells decor placement instead |
| §4.1–4.3 | Stack, architecture diagram and data model rewritten for Flutter + Drift/SQLite |
| §7.2 | Analytics rewritten — Apple App Analytics has no Android counterpart; events are now local-only |
| §8, §9, §10, §11, §13 | Release plan, asset plan, risks, measurement and glossary updated for two platforms |
| §12 | Open questions 1, 2, 4 and 5 resolved |

**Two corrections of fact carried into v2.0:**

1. **v1.0 relied on `BGAppRefreshTask` for background timer accuracy (§4.1, §10).** That API is opportunistic background *refresh* scheduled at the system's discretion — it cannot be relied on to fire at a chosen moment, so a 25-minute session must not depend on it. Replaced by wall-clock-anchored elapsed time plus a scheduled local notification.
2. **v1.0's REQ-014 assumed an app can enable Focus Mode / DND on both platforms.** No public iOS API can activate a Focus mode; Apple's Focus APIs are read-only or reactive only. Android can, via `AutomaticZenRule`. The requirement is now deliberately asymmetric.

---

## 1. Executive Summary

### 1.1 Product Vision

> *"Cultivate focus, grow calm."*

Pomodoro Garden transforms the proven Pomodoro time-management technique into a visually therapeutic experience. Every focused session plants a seed in a living virtual garden that flourishes over days, weeks, and months. No AI, no notifications screaming for attention — just a calm, beautiful space that grows alongside your focus habits.

### 1.2 Problem Statement

| Problem | Impact |
|---|---|
| Focus apps are sterile and utilitarian | Users abandon them within weeks; timers feel like a chore |
| Gamification in productivity apps is shallow | Badges and streaks don't create emotional attachment |
| Digital wellness tools lack visual beauty | The therapeutic potential of "watching things grow" is untapped |
| Existing Pomodoro apps are feature-bloated | Users want simplicity but get dashboards, charts, and clutter |
| Screen time increases anxiety | People want tools that reduce stress, not add notifications |

### 1.3 Target Audience

| Persona | Description | Pain Point |
|---|---|---|
| **The Focus Seeker** | Students, writers, developers, remote workers who use or want to use the Pomodoro technique | Existing timers are ugly and unrewarding; motivation fades after a few days |
| **The Anxious Scroller** | People who want to reduce phone addiction and build healthier work rhythms | Needs a gentle, non-aggressive tool that feels therapeutic, not punitive |
| **The Visual Learner** | People motivated by visual progress and tangible (virtual) rewards | Streaks and numbers don't motivate; seeing a garden bloom does |
| **The Gift Shopper** | Aesthetically-driven users who appreciate beautiful, calming digital experiences | Most productivity apps look corporate and cold |

### 1.4 Unique Value Proposition

**Pomodoro Garden is the only focus timer that turns your concentration into a living, growing ecosystem.** It replaces the anxiety of productivity dashboards with the calm of watching a garden flourish — making focus feel less like work and more like tending to something alive.

### 1.5 Key Differentiators from Competitors

| Competitor | Their Approach | Our Advantage |
|---|---|---|
| Forest App | Tree grows during session; dies if you leave | **Persistent garden** that evolves over weeks/months, not just per-session |
| Focus Keeper | Basic timer with charts | **Living visual ecosystem** — charts are secondary to the garden |
| Be Focused | Task management + timer | **Simplicity-first** — no task management, just pure focus + beauty |
| Flora | Social focus with friends | **Solo-first experience** — no social pressure; garden is personal and meditative |

---

## 2. Goals & Objectives

### 2.1 Business Goals

| Goal | Metric | Target |
|---|---|---|
| Store visibility | Keyword ranking, both stores | Top 20 for "pomodoro timer" within 6 months |
| User acquisition | Downloads in first 3 months, both stores combined | 50,000 |
| User retention | 30-day retention rate | ≥ 35% — see §7.2, not measurable in v1 without a sink |
| User satisfaction | Average store rating, both stores | ≥ 4.6 stars |
| Daily engagement | Average sessions per user per day | ≥ 3 sessions |

### 2.2 Product Goals

| Goal | Description |
|---|---|
| **Beautiful by default** | Every screen should be screenshot-worthy and calming |
| **Zero-friction start** | From download to first completed session in under 60 seconds |
| **Emotional attachment** | Users should feel genuine sadness at the thought of abandoning their garden |
| **Offline-first** | Full functionality without internet; no account required to start |
| **Battery-conscious** | Timer runs efficiently; garden animations don't drain battery |

### 2.3 Non-Goals (v1.0)

| What We're NOT Doing | Why |
|---|---|
| AI features of any kind | Core philosophy: human, calm, simple |
| **Charging for anything** | The app is free. No purchase, no subscription, no ads, no tier — see §3.6 and `docs/adr/0021-…` |
| Social/multiplayer garden | v1 is personal; social adds pressure |
| Task management | We're a focus timer, not a to-do app |
| Cross-device sync | v1 is device-local; cloud sync is a v2 consideration |
| Web version | Mobile first; validate before expanding |
| Tablet-optimised layouts | Phones first on both platforms; iPad and Android tablet layouts are Phase 2 |
| Notifications during focus sessions | We block distractions; we don't add them |

---

## 3. User Stories & Requirements

### 3.1 Epic 1: Onboarding & First Experience

#### User Stories

| ID | Story | Priority |
|---|---|---|
| US-001 | As a new user, I want to start a focus session within 30 seconds of opening the app for the first time, so I don't lose motivation. | P0 |
| US-002 | As a new user, I want to see an empty garden plot with rich soil, so I understand what I'm building toward. | P0 |
| US-003 | As a new user, I want a gentle 3-step tutorial overlaid on the actual app (not a separate screen), so I learn by doing. | P1 |
| US-004 | As a new user, I want to choose my session length (15/25/50 min) without creating an account, so I can try the app frictionlessly. | P0 |
| US-005 | As a new user, I want to see a seed get planted the moment my first session starts, so the reward loop is immediately clear. | P0 |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-001 | No account creation required for v1 | All data stored locally on-device in SQLite via Drift |
| REQ-002 | Default session length | 25 minutes (classic Pomodoro), configurable in Settings |
| REQ-003 | Onboarding flow | Maximum 3 screens: (1) Welcome + garden preview, (2) Choose session length, (3) Start — that's it |
| REQ-004 | First-session seed animation | Seed drops into soil with a soft particle effect; soil settles around it |

---

### 3.2 Epic 2: Focus Timer Core

#### User Stories

| ID | Story | Priority |
|---|---|---|
| US-006 | As a user, I want to start a focus session with a single tap, so I can get to work instantly. *(v2.2: from the garden screen the app opens on, via its timer bar — see §5.2)* | P0 |
| US-007 | As a user, I want to see a circular progress ring around the garden plot showing time remaining, so I know how long without checking numbers. | P0 |
| US-008 | As a user, I want to hear a gentle, natural sound when my session ends (not an alarm), so I'm not startled out of flow. | P0 |
| US-009 | As a user, I want to pause a session if needed (emergencies happen), so I don't lose my progress unfairly. | P1 |
| US-010 | As a user, I want to optionally enable a short break timer after each session, so I can follow the full Pomodoro cycle. | P1 |
| US-011 | As a user, I want the app to work in the background and lock screen, so I can close the app and still get notified. | P0 |
| US-012 | As a user, I want to see the timer without opening the app — on the Dynamic Island / Live Activity on iOS, or in an ongoing notification on Android. | P1 |
| US-013 | As a user, I want to choose from ambient background sounds during my session, so I can create a focused atmosphere. | P1 |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-005 | Timer engine | Pure Dart state machine with an injectable clock. Elapsed time is **derived from a wall-clock anchor, never accumulated from ticks**, so it cannot drift when the UI stalls or the app is suspended. Background completion is guaranteed by a local notification, not by background execution. The notification is scheduled **when the app leaves the foreground** (for the session's end, and for the end of a break that will replay while away — REQ-032) and cancelled when the app returns; while the app is in front it plays the end sound itself, so the user never hears both |
| REQ-006 | Session lengths | Presets: 15 min (Short), 25 min (Classic), 50 min (Deep). Custom range: 5–120 min |
| REQ-007 | Break lengths | Presets: 5 min (Short), 10 min (Standard), 15 min (Long), as one-tap choices beside the 1–30 min slider, the same way REQ-006's presets sit beside theirs. The presets set the ordinary break; the **long break** is derived as 3× the break, capped at 30 min. Auto-start option toggle (REQ-032) |
| REQ-008 | End-of-session sound | 6 options, listed in REQ-031. Default: wind chime |
| REQ-009 | Pause behavior | Pause allowed; session resumes from paused time. Paused sessions still grow the plant but at reduced growth rate (50%) |
| REQ-010 | Live timer surface (iOS) | Dynamic Island — compact: tiny ring + plant icon; expanded: progress ring + time remaining + plant growth stage. Lock screen Live Activity shows minimal timer ring + garden icon, persisting for the active session. Built on ActivityKit behind a shared Dart port |
| REQ-011 | Live timer surface (Android) | **Android has no Dynamic Island and no ActivityKit equivalent.** A foreground service posts an ongoing, non-dismissable notification with a live countdown and the current growth stage, torn down on completion or cancellation. This additionally buys the background reliability iOS gets for free |
| REQ-012 | Background sounds | 6 ambient options: Rain, Forest, Ocean, Café, White Noise, Silence. Loop seamlessly. No streaming — bundled audio files |
| REQ-013 | Interruption handling | If user force-quits app during session: session is voided, seed does NOT grow. If app is backgrounded normally: session continues. **iOS caveat (accepted in v2.2):** iOS sends no signal when the user swipes away an app it has already suspended, so that force-quit looks like a system kill and the session is restored. The failure is deliberately the kind one — it can give a plant, never take one — see `docs/adr/0005-…` and `0007-…` |
| REQ-014 | Quiet mode | **Deliberately asymmetric — the platforms are not equally capable here.** *Android:* registers an `AutomaticZenRule` activated on session start and deactivated on end, behind the `ACCESS_NOTIFICATION_POLICY` permission the user grants in system settings. Note apps targeting Android 15+ cannot modify the global interruption filter — an app-owned zen rule is the only supported route. *iOS:* **no public API can activate a Focus mode.** Apple's Focus APIs are read-only (Focus Status) or reactive (`SetFocusFilterIntent`) only. iOS instead donates an App Intent the user can wire into a Shortcuts automation, plus a one-time hint. The settings toggle appears only where automation is real |

---

### 3.3 Epic 3: Garden System

#### User Stories

| ID | Story | Priority |
|---|---|---|
| US-014 | As a user, I want to see my plant grow in real-time during a focus session, so I feel rewarded for staying focused. | P0 |
| US-015 | As a user, I want my garden to persist between sessions and days, so it feels like a living thing I'm tending. | P0 |
| US-016 | As a user, I want different session lengths to grow different plants, so I have variety and visual reward tiers. | P0 |
| US-017 | As a user, I want to see my full garden from a top-down/isometric view, so I can admire my accumulated focus over time. | P0 |
| US-018 | As a user, I want to pan and zoom around my garden, so I can inspect individual plants. | P1 |
| US-019 | As a user, I want plants to have growth stages (seed → sprout → young → mature → flowering), so I can see incremental progress. | P0 |
| US-020 | As a user, I want my garden to change with real-world seasons, so it feels connected to the world outside. | P1 |
| US-021 | As a user, I want to tap a plant to see when it was planted and how long the session was, so each plant has a story. | P1 |
| US-022 | As a user, I want to earn rare/bonus plants for milestone achievements, so there's long-term motivation. | P1 |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-015 | Plant types | Mapped to session duration: |

| Session Length | Plant Type | Visual |
|---|---|---|
| 5–14 min | Wildflower | Small, colorful, quick bloom |
| 15–24 min | Herb (basil, mint, rosemary) | Medium, textured leaves |
| 25–34 min | Flower (sunflower, tulip, daisy) | Tall, vibrant bloom |
| 35–49 min | Bush/Shrub | Dense, leafy, medium height |
| 50–74 min | Small tree (cherry blossom, maple) | Structural, seasonal color |
| 75–120 min | Large tree (oak, willow, pine) | Grand, dominant garden feature |

| REQ-016 | Growth stages | Each plant has 5 visual stages: |
| Stage | Trigger | Visual |
|---|---|---|
| Seed | Session starts | Small dot in soil |
| Sprout | 20% of session complete | Tiny green shoot |
| Young | 50% of session complete | Recognizable plant shape |
| Maturing | 80% of session complete | Near-full size, pre-bloom |
| Mature | Session complete | Full bloom / full size |

| REQ-017 | Garden layout | Isometric grid view. New plants placed automatically in nearest available plot slot. Garden expands (more plots unlock) as user completes more sessions |
| REQ-018 | Garden capacity | Starts with 12 plot slots. Every 10 completed sessions unlocks +4 slots. Max: 200 slots |
| REQ-019 | Seasonal theming | App reads device date/month. Spring: cherry blossoms, green grass. Summer: vibrant flowers, bright sky. Autumn: orange/red leaves, falling particles. Winter: snowfall, bare branches, evergreens retain color |
| REQ-020 | Plant inspection | Tap any plant → modal card shows: plant type, date planted, session length, growth stage, a gentle quote about growth/patience |
| REQ-021 | Bonus/rare plants | Awarded at milestones: |

| Milestone | Bonus Plant |
|---|---|
| 10 sessions | Bonsai tree |
| 25 sessions | Wisteria arch |
| 50 sessions | Japanese maple |
| 100 sessions | Ancient oak |
| 250 sessions | Cherry blossom grove |
| 500 sessions | Enchanted willow (subtle glow) |
| 1000 sessions | Golden garden (all plants shimmer) |

**The two effects ship in v1.0 (v2.2).** The enchanted willow carries a soft halo of light
behind it; once the golden garden is earned, every plant in the garden takes a slow, gentle
brightness shimmer, each on its own phase as REQ-023's sway is. Both are drawn inside the
garden's single batched draw (`docs/adr/0020-…`), both hold still under the system's
reduce-motion setting, and both are tuned against the final art. A debug-only control
previews a garden at 500 and at 1000 sessions, alongside the existing debug season picker.

| REQ-022 | Plant rendering | Sprite-based 2D illustrations (not 3D). Each plant type × 5 stages, plus one shared bonus set = 35 illustrated assets. Paper-cut style (§5.1, v2.2). Delivered at the density buckets both platforms require, resolved at runtime through a sprite registry keyed by (type, stage) |
| REQ-023 | Animations | Smooth spring transitions between growth stages using Flutter's animation framework. Gentle sway animation on mature plants (ambient wind effect), phase-randomised per plant so a garden does not pulse in unison |
| REQ-024 | Garden persistence | All garden state stored in SQLite via Drift. Plant positions, types, growth stages, and metadata persist across app launches |

---

### 3.4 Epic 4: Statistics & Insights (Minimal, Beautiful)

#### User Stories

| ID | Story | Priority |
|---|---|---|
| US-023 | As a user, I want to see how many sessions I've completed this week, so I can track my consistency. | P1 |
| US-024 | As a user, I want to see a beautiful monthly calendar heatmap showing days I focused, so I can visualize my habit. | P1 |
| US-025 | As a user, I want to see total focus time accumulated, so I have a satisfying big number. | P1 |
| US-026 | As a user, I want my stats to feel like a botanical journal, not a corporate dashboard, so the aesthetic stays consistent. | P1 |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-025 | Stats screen | Single scrollable page, botanical journal aesthetic (paper texture, handwritten-style headers) |
| REQ-026 | Weekly summary | Card showing: sessions this week, total focus time, plants grown, streak days |
| REQ-027 | Calendar heatmap | Monthly grid; intensity of green = number of sessions that day. Empty days = bare soil color. Opens on the current month; previous/next arrows step through earlier months, never past the current one (v2.2) |
| REQ-028 | Lifetime stats | Total sessions, total focus hours, total plants, garden level, rare plants earned |
| REQ-029 | Streak tracking | Consecutive days with ≥1 completed session. Streak breaks shown gently — no guilt language. "Your garden rested for 2 days" instead of "Streak broken!" |

---

### 3.5 Epic 5: Settings & Customization

#### User Stories

| ID | Story | Priority |
|---|---|---|
| US-027 | As a user, I want to customize my timer lengths, so I can adapt to my own rhythm. | P0 |
| US-028 | As a user, I want to choose my end-of-session sound, so it matches my preference. | P0 |
| US-029 | As a user, I want to toggle auto-start of breaks, so I don't have to manually tap. | P1 |
| US-030 | As a user, I want to enable/disable the live timer surface, so I control what appears on my lock screen. | P1 |
| US-031 | As a user, I want to choose a garden theme (biome), so my garden feels personal. | P2 |
| US-032 | As a user, I want to export my garden as an image, so I can share my progress. | P1 |
| US-033 | As a user, I want to reset my garden (with confirmation), so I can start fresh if I want. | P1 |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-030 | Timer customization | Session: 5–120 min slider. Break: 1–30 min slider. Long break after N sessions: 2–6 |
| REQ-031 | Sound selection | End-of-session: Wind Chime (default), Soft Bell, Birdsong, Singing Bowl, Ocean Wave, None |
| REQ-032 | Auto-start toggles | Auto-start break: on/off. Auto-start next session: on/off. **While the app is away (v2.2):** with auto-start break on, a session that ends in the background is followed by its break anchored at the session's end, and the break's end is announced by a notification on time — the break replays because it earns nothing. The next **focus session is never started in the background**: replaying one would plant a reward for time the phone spent in a pocket. Auto-start next session therefore acts when the app is next awake, as `docs/adr/0008-…` (amended) describes |
| REQ-033 | Live timer surface | Toggle on/off in Settings. Default: ON. Disabling must not break background session completion on either platform |
| REQ-034 | Garden themes | 3 themes in v1: (1) Zen Garden [default], (2) Tropical Greenhouse, (3) Wildflower Meadow. Each theme reskins garden background, soil, and decor. All three are available to every user |
| REQ-035 | Garden export | Export as high-res PNG. No watermark — there is one kind of export, and it carries nothing of the app's |
| REQ-036 | Garden reset | Settings → Reset Garden → Double confirmation ("This will clear all plants and stats. This cannot be undone.") |
| REQ-037 | Haptic feedback | Gentle success haptic when session completes. Subtle haptic when plant grows to next stage. Configurable on/off |

---

### 3.6 Epic 6: The app is free

#### User Stories

| ID | Story | Priority |
|---|---|---|
| US-034 | As a user, I want full access to the timer, the garden and everything in them, without paying and without an account. | P0 |
| US-035 | As a user, I want to know there is nothing to buy, so I am never wondering what I am missing. | P0 |
| ~~US-036~~ | ~~As a user, I want a one-time purchase option~~ — **withdrawn in v2.1.** There is nothing to purchase | — |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-038 | Monetization model | **None.** The app is free in its entirety. NO purchase. NO subscription. NO ads. NO server. No store SDK ships in the binary, and no screen in the app mentions money. See `docs/adr/0021-…` |
| REQ-039 | What every user gets | Everything: full timer, full garden with uncapped plots (REQ-018 applies to everyone), all 6 plant types, all bonus/milestone plants, **all 3 garden themes** (REQ-034), **all 6 ambient sounds** (REQ-012), stats, live timer surface, **garden decor** (REQ-040) and an unmarked export (REQ-035) |
| REQ-040 | Garden decor | The user may stand four kinds of object — stone lantern, bench, birdbath, pond — in the empty plots of their garden, and rearrange or remove them. Decor is themed with the garden (REQ-034) and **never costs a completed session its plot**; see `docs/adr/0017-…`. *(This requirement was v2.0's premium tier. The tickets and the code had been citing decor as REQ-036, which is the garden reset; v2.1 gives decor a number of its own.)* |
| ~~REQ-041~~ | ~~Paywall screen~~ | **Withdrawn in v2.1.** There is no paywall, and no screen that sells anything |

**Two things v2.0 sold and v1.0 does not ship.** The "Enchanted Garden" glowing plant
variants and custom session labels/tags were listed in v2.0's premium tier and were never
built. They are dropped from v1.0 rather than carried as unbuilt promises; either could
return as a v1.1 feature on its own merits.

---

## 4. Technical Architecture

### 4.1 Technology Stack

| Layer | Technology | Rationale |
|---|---|---|
| Framework | **Flutter** (Dart) | One codebase, two platforms, at parity. Strong custom-painting story for the isometric garden; animation-friendly |
| Minimum versions | iOS 17.0 · Android API 26 (8.0), targeting the current API level Google Play requires | iOS 17 per Live Activity support; API 26 is the floor for `AutomaticZenRule` (REQ-014) and notification channels |
| State management | **Riverpod** | Compile-safe DI + reactive state. Provider overrides keep the timer state machine pure and testable with an injected clock |
| Data persistence | **SQLite via Drift** | Type-safe queries and migrations; on-device only; offline-first; identical on both platforms |
| Domain core | Pure Dart, no Flutter imports | Timer state machine, growth model, plot placement and milestone rules are platform- and UI-free, so they are unit-testable without a device |
| Timer | Wall-clock-anchored elapsed time + scheduled local notification | Cannot drift when suspended. **Explicitly not** a tick-accumulating timer, and not dependent on background execution |
| Live timer surface | ActivityKit (iOS, Swift) · foreground service (Android, Kotlin) | No cross-platform equivalent exists; two native implementations behind one Dart port |
| Quiet mode | `AutomaticZenRule` (Android, Kotlin) · App Intent for Shortcuts (iOS) | See REQ-014 — iOS cannot automate Focus |
| Audio | **just_audio + audio_session** | Seamless ambient looping plus correct iOS audio-session category and Android audio-focus handling: call interruptions, route changes, ducking under the end chime |
| Garden rendering | **`CustomPainter` + `Canvas.drawAtlas`** | Hundreds of sprites batched into a single draw call; full control over isometric depth sort and hit-testing; stays an ordinary widget |
| Graphics | 2D sprite assets at both platforms' density buckets | Paper-cut illustrations generated in the repo (§9.1), bundled in app, resolved via a sprite registry |
| Animations | Flutter animation framework (spring simulations) | Growth-stage transitions + ambient sway |
| Haptics | Flutter haptic feedback APIs | Tactile growth feedback on both platforms |
| Analytics | Local-only event log (see §7.2) | No SDK, no network — Apple App Analytics has no Android counterpart |

**Native code is confined to three places** — the iOS Live Activity, the Android foreground service, and the Android zen rule. Everything else is Dart.

### 4.2 Architecture Diagram (Text)

```
┌────────────────────────────────────────────────────────┐
│                    Flutter (Dart)                      │
│  ┌──────────┐  ┌──────────┐  ┌────────┐  ┌──────────┐  │
│  │  Garden  │  │  Timer   │  │Journal │  │ Settings │  │
│  │  Screen  │  │  Screen  │  │ Screen │  │  Screen  │  │
│  │(Custom-  │  │          │  │        │  │          │  │
│  │ Painter) │  │          │  │        │  │          │  │
│  └────┬─────┘  └────┬─────┘  └───┬────┘  └────┬─────┘  │
│       └─────────────┴────────────┴────────────┘        │
│  ┌──────────────────────────────────────────────────┐  │
│  │              Riverpod providers                  │  │
│  └────────────────────────┬─────────────────────────┘  │
│  ┌────────────────────────┴─────────────────────────┐  │
│  │        Domain core — pure Dart, no Flutter       │  │
│  │  ┌────────────┐ ┌──────────┐ ┌────────────────┐  │  │
│  │  │  Session   │ │  Growth  │ │ Plot placement │  │  │
│  │  │state machine│ │  model   │ │ + milestones   │  │  │
│  │  │(injected   │ │          │ │                │  │  │
│  │  │  clock)    │ │          │ │                │  │  │
│  │  └────────────┘ └──────────┘ └────────────────┘  │  │
│  └────────────────────────┬─────────────────────────┘  │
│  ┌────────────────────────┴─────────────────────────┐  │
│  │                Ports (abstract)                  │  │
│  │  live surface · quiet mode · audio · notifications│  │
│  │  · notifications · analytics · persistence       │  │
│  └──┬──────────────────────────────────────────┬────┘  │
│     │                                          │       │
│  ┌──┴───────────────────┐   ┌──────────────────┴────┐  │
│  │   Drift / SQLite     │   │  Plugins: just_audio, │  │
│  │  sessions · plants   │   │  audio_session,       │  │
│  │  settings · decor    │   │  local notifications  │  │
│  │  · analytics events  │   │  local notifications  │  │
│  └──────────────────────┘   └───────────────────────┘  │
└───────────────────────┬────────────────────────────────┘
                        │  platform channels
        ┌───────────────┴───────────────┐
┌───────┴─────────┐            ┌────────┴──────────────┐
│  iOS (Swift)    │            │  Android (Kotlin)     │
│  ActivityKit    │            │  Foreground service   │
│  Live Activity  │            │  ongoing notification │
│  + Dynamic Is.  │            │  AutomaticZenRule     │
│  App Intent     │            │  (quiet mode)         │
└─────────────────┘            └───────────────────────┘
```

The domain core has no Flutter, platform or wall-clock dependency — it is driven by an injected time source, which is what makes ±1s accuracy over a 120-minute session testable in milliseconds.

### 4.3 Data Model

Drift tables. Enums are stored as text and mapped to Dart enums at the repository boundary — no raw strings reach the domain core.

```
sessions
├── id: String (uuid)
├── startedAt: DateTime (UTC, wall-clock anchor)
├── durationSeconds: int          // seconds, not minutes — see ADR 0003
├── completed: bool
├── outcome: text enum? {completed, cancelled, voided}   // null while in flight — ADR 0005
├── pausedSeconds: int
├── pausedSince: DateTime?      // set while a pause is open
└── endedAt: DateTime?          // null while running

plants
├── id: String (uuid)
├── sessionId: String? → sessions.id   // null for bonus plants
├── type: text enum {wildflower, herb, flower, bush, smallTree, largeTree, bonus}
├── species: text                      // "sunflower", "basil", "cherry_blossom"
├── growthStage: int (0–4)
├── plotX: int?                        // null when unplaced (garden full) — ADR 0006
├── plotY: int?
├── plantedAt: DateTime
├── sessionDurationSeconds: int?       // null for bonus plants; seconds — ADR 0003
└── milestoneSessions: int?            // which milestone earned it; a plant is a bonus
                                       // plant exactly when this is set, so there is no
                                       // separate isBonusPlant flag (v2.2)

decor                                  // REQ-040
├── id: String (uuid)
├── kind: text
├── plotX: int
├── plotY: int
└── placedAt: DateTime

settings                               // single row
├── sessionLengthSeconds: int
├── breakLengthSeconds: int
├── longBreakAfterSessions: int
├── autoStartBreak: bool
├── autoStartSession: bool
├── endSound: text
├── ambientSound: text
├── hapticsEnabled: bool
├── liveSurfaceEnabled: bool
├── quietModeEnabled: bool             // Android only — see REQ-014
├── quietModeHintDismissed: bool       // iOS's one-time Shortcuts hint — REQ-014
├── gardenTheme: text
└── onboardingCompleted: bool

analyticsEvents                        // local only — §7.2
├── id: int (autoincrement)
├── name: text
├── parameters: text (json)
└── recordedAt: DateTime
```

The shipped schema is **version 19** (v2.2). Where this sketch and `lib/src/data/database.dart`
disagree, the code is right and this section should be corrected.

**Derived, never stored:** total sessions completed, garden level, unlocked plot count, streak length and lifetime focus time are all computed by query from `sessions`. Storing a running counter alongside the rows it counts is how the two disagree after a reset or a milestone replay.

### 4.4 Performance Requirements

| Metric | Target |
|---|---|
| App launch to garden visible | < 1.5 seconds |
| Timer accuracy | ±1 second over 120-minute session |
| Battery drain during active session | < 3% per 25-minute session |
| Garden render with 200 plants | 60fps, no frame drops — measured on a mid-range Android device and an older supported iPhone, not only on current flagships |
| Ambient sound loop seam | Inaudible (< 5ms gap) |
| App download size | < 50 MB per platform. Note Flutter carries an engine baseline, so this is tighter than it looks — verify against the App Store thinned size and the Play delivery size, not the raw build output |

**How these are verified for v1.0 (v2.2).** The targets stand, but **none of them blocks the
v1.0 release.** They are measured where the hardware allows and recorded in
`docs/performance-record.md`; a clear failure — visible jank, a slow launch — is fixed,
anything subtler is watched in the store consoles after launch. The reference devices are
the owner's **iPhone**, the **iOS Simulator** and the **Android emulator** (this resolves
open question #8). An emulator says nothing about frame rate, battery or OEM background
kills, so on Android those three are verified by design and by the in-repo proxy
measurements rather than on hardware.

---

## 5. Design Specifications

### 5.1 Visual Design Language

| Attribute | Specification |
|---|---|
| **Style** | **Paper-cut** meets modern UI (v2.2; was "hand-drawn watercolor"). Each plant is layers of coloured paper, cut with a slightly irregular edge and stacked, each layer casting a soft shadow on the one below, with a faint paper-fibre texture. Think *a cut-paper picture book* × *Apple Reminders minimalism* |
| **Color palette** | |

| Role | Color | Hex |
|---|---|---|
| Primary (garden green) | | `#6B8E5A` |
| Soil | | `#8B6F47` |
| Sky (day) | | `#B8D4E8` |
| Sky (golden hour) | | `#F5C99B` |
| Accent (bloom) | | `#E89B9B` |
| Background (dark mode) | | `#1C2B1C` |
| Text primary | | `#2D3A2D` |
| Text secondary | | `#6B7B6B` |

| **Typography** | |
|---|---|
| Headings | SF Pro Rounded (semibold) — warm, friendly |
| Body | SF Pro (regular) |
| Numbers (timer) | SF Pro Rounded (monospaced digits, tabular) |
| Botanical labels | Handwritten-style font (e.g., Caveat or similar) for plant names |

**As built (v2.2):** SF Pro is Apple-only, so both platforms bundle **Nunito** (headings,
body, and tabular timer digits) and **Caveat** (botanical labels). One rounded family on
both keeps the platforms at visual parity.

| **Iconography** | |
|---|---|
| App icon | A single paper-cut seedling in soil, rounded square. No text. Recognizable at all sizes. |
| Tab bar icons | Minimalist line icons: garden (home), clock (timer), journal (stats), gear (settings) |

### 5.2 Key Screen Layouts

#### Screen 1: Main Garden View (Home)

```
┌─────────────────────────────────┐
│  ☰        Pomodoro Garden    ⚙  │  ← Navigation bar (minimal)
│                                  │
│   ╭─────────────────────────╮   │
│   │                         │   │
│   │    🌳   🌸   🌿         │   │  ← Isometric garden
│   │         🌱    🌼        │   │     (pan/zoom)
│   │   🌿        🌳           │   │
│   │              🌱          │   │
│   │                         │   │
│   ╰─────────────────────────╯   │
│                                  │
│  ┌─────────────────────────────┐│
│  │     ⏱  25:00               ││  ← Timer ring (circular)
│  │    ╭───────────╮            ││     Tappable to start
│  │   │   START    │            ││
│  │    ╰───────────╯            ││
│  └─────────────────────────────┘│
│                                  │
│  🌿  🌸  📖  ⚙                   │  ← Tab bar
└─────────────────────────────────┘
```

**As built (v2.2):** Garden and Timer are separate tabs, and the app opens on the garden.
A compact **timer bar** along the bottom of the garden stands in for the ring above:
- **Idle:** the next session's length and START. One tap starts the session and moves to
  the Timer tab, so the user sees the seed drop.
- **Running or paused:** the live countdown; a tap moves to the Timer tab.
- **On a break:** the break's countdown.

The bar is hidden while the user is arranging decor (REQ-040).

#### Screen 2: Active Session View

```
┌─────────────────────────────────┐
│  Cancel              Pause  ⏸  │  ← Minimal controls
│                                  │
│   ╭─────────────────────────╮   │
│   │                         │   │
│   │         🌿              │   │  ← Growing plant
│   │        (young stage)      │   │     (animates in real-time)
│   │                         │   │
│   ╰─────────────────────────╯   │
│                                  │
│  ╭───────────────────────────╮  │
│  │    17:23 remaining        │  │  ← Countdown
│  │  ████████░░░░░░  62%       │  │     Progress ring
│  ╰───────────────────────────╯  │
│                                  │
│  🌧  Rain · Forest · Ocean  🔇   │  ← Ambient sound toggle
└─────────────────────────────────┘
```

**As built (v2.2), and accepted:** the ring surrounds the countdown digits and the growing
plant stands beneath it, with no percentage. US-007 asks to see progress "without checking
numbers", so a third number is not added; the ring is the time and the plant is the growth.
The ambient picker sits below the controls. Revisit the layout only if the final art looks
lost under the ring.

#### Screen 3: Dynamic Island States

```
COMPACT (closed):  [ 🌿 ◜◞ 17:23 ]
EXPANDED (tap):
┌──────────────────────────┐
│  🌿  Focusing              │
│  ◜━━━━━━━━━━━◝  17:23 left │
│  Young Sunflower          │
└──────────────────────────┘
```

#### Screen 4: Botanical Journal (Stats)

```
┌─────────────────────────────────┐
│  ←  Botanical Journal           │
│                                  │
│  ╭─────────────────────────────╮│
│  │  This Week                   ││
│  │  12 sessions · 5h 20m        ││
│  │  🌿🌿🌸🌿🌳🌿  (plants grown) ││
│  ╰─────────────────────────────╯│
│                                  │
│  ╭─────────────────────────────╮│
│  │  July 2026                   ││
│  │  Mo Tu We Th Fr Sa Su         ││
│  │   ·  ·  🟢 🟢 🟢 🟢 🟢        ││  ← Heatmap
│  │  🟢 🟢 🟢 ·  🟢 🟢 🟢         ││     (green intensity
│  │  🟢 🟢 🟢 🟢 🟢 ·  ·          ││      = sessions/day)
│  ╰─────────────────────────────╯│
│                                  │
│  ╭─────────────────────────────╮│
│  │  Lifetime                    ││
│  │  342 sessions · 143h focus   ││
│  │  342 plants · 7 bonus plants ││
│  │  Garden Level: 9              ││
│  ╰─────────────────────────────╯│
└─────────────────────────────────┘
```

### 5.3 Animation Specifications

| Animation | Trigger | Duration | Easing | Notes |
|---|---|---|---|---|
| Seed drops into soil | Session starts | 0.8s | ease-in-out | Small soil particle burst on landing |
| Growth stage transition | Stage threshold reached | 1.2s | Spring, underdamped (ratio ≈ 0.7) | Plant scales up with slight overshoot |
| Mature plant sway | Continuous (ambient) | 4s loop | ease-in-out | 2° rotation, randomized per plant |
| Session end celebration | Session completes | 2s | spring + ease | Plant blooms with particle petals/spores |
| Garden entry | App launches / returns | 0.5s | ease-out | Gentle fade-in + scale from 0.95 |
| Seasonal transition | Real-world season change detected | 3s | ease-in-out | Background color crossfade; leaves fall/don't |

### 5.4 Sound Design

| Sound | Context | Source | Format |
|---|---|---|---|
| Wind Chime | Session end (default) | Recorded real wind chimes | AAC, 3s |
| Soft Bell | Session end (option) | Tibetan bowl | AAC, 4s |
| Birdsong | Session end (option) | Blackbird phrase, public-domain field recording (v2.2: the only CC0 robin found was an unusable phonograph transfer) | AAC, 3s |
| Singing Bowl | Session end (option) | Singing bowl strike | AAC, 5s |
| Ocean Wave | Session end (option) | Single wave | AAC, 3s |
| Rain (ambient) | During session (option) | Seamless loop | AAC, 60s loop |
| Forest (ambient) | During session (option) | Seamless loop | AAC, 60s loop |
| Ocean (ambient) | During session (option) | Seamless loop | AAC, 60s loop |
| Café (ambient) | During session (option) | Seamless loop | AAC, 60s loop |
| White Noise (ambient) | During session (option) | Seamless loop | AAC, 60s loop |
| Soil settle | Seed planted | Foley | AAC, 0.5s |
| Growth shimmer | Stage transition | Soft chime | AAC, 0.8s |

All audio files bundled in-app (no streaming). Total audio budget: < 8 MB.

**Formats and sources as decided in v2.2.** The "Format" column above is superseded. AAC
pads every file with encoder delay, so an AAC loop joins itself with tens of milliseconds
of silence, ten times §4.4's 5 ms seam budget. And 60 s of any lossless format breaks the
8 MB budget. Loop length is what gives (`docs/ambience.md`):

| Sound | Format | Length |
|---|---|---|
| Ambient beds (5) | **PCM WAV**, mono, 44.1 kHz, 16-bit, built to loop | **15 s** each |
| End-of-session sounds (5) | PCM WAV, mono, 22.05 kHz (iOS notifications accept only PCM) + an AAC copy as an Android notification-channel resource | 3–5 s |
| Micro-sounds (4) | AAC | < 1 s |

Beds are chosen to have no memorable events (steady rain, distant surf, a dense café murmur
with no distinct voices), so a 15 s loop does not draw attention to itself. *(Ticket 37
kept the beds as WAV rather than the 20 s FLAC first planned: the loop-seam tests read PCM,
and FLAC would have needed a decoder in them. See `docs/ambience.md`.)* **Fallback:**
if a bed still sounds looped, it is built from two layers of coprime length (e.g. 17 s and
23 s) that only repeat together after several minutes. That costs a second player per bed,
and is used only for the beds that need it.

**Sources:** there is no sound designer (§9.2). Tonal and noise-based sounds — the chimes,
bell, bowl, ocean wave, micro-sounds, rain, ocean and white noise — are **synthesised in the
repo**. Birdsong, forest and café use **public-domain (CC0) field recordings** where a good
one is freely downloadable, and are synthesised otherwise. No licence that requires
attribution is used, so the app needs no credits screen.

---

## 6. App Store Optimization (ASO) Strategy

### 6.1 App Metadata

| Field | App Store | Google Play |
|---|---|---|
| **App Name** | Pomodoro Garden — Focus Timer | Pomodoro Garden — Focus Timer (30 char limit) |
| **Subtitle / Short description** | Grow your garden by staying focused | Grow your garden by staying focused (80 char limit) |
| **Primary Category** | Productivity | Productivity |
| **Secondary Category** | Health & Fitness | — (Play has no secondary category) |
| **Keywords** | pomodoro, focus, timer, garden, plants, concentration, study, deep work, mindfulness, grow, nature, calm, productivity, tomato, study timer, work timer | Play has no keyword field — the same terms must be worked naturally into the long description, which *is* indexed |
| **Content Rating** | 4+ | Everyone (via the IARC questionnaire) |
| **Description** | *(see below)* | *(same copy; Play indexes it, so keyword placement matters more)* |

**Store-specific work that has no iOS equivalent:** the IARC content-rating questionnaire, a Data Safety form (distinct from Apple's privacy labels but answered from the same facts — see §7.2), a feature graphic, and a privacy policy URL, which Play requires.

### 6.2 App Store Description

```
Grow your focus. Grow your garden.

Pomodoro Garden turns every focused session into a living, breathing garden. 
Set your timer, stay focused, and watch your seeds bloom into flowers, 
herbs, and trees — one session at a time.

No AI. No clutter. No noise. Just you, your focus, and a garden that grows 
as beautifully as your habits do.

🪴 HOW IT WORKS
• Choose your session length (15, 25, or 50 minutes)
• Focus — and watch your plant grow in real-time
• Complete the session to plant it in your garden permanently
• Return tomorrow, next week, next month — your garden keeps growing

🌸 YOUR GARDEN GROWS OVER TIME
• Short sessions grow wildflowers and herbs
• Deep sessions grow majestic trees
• Bonus plants unlock at milestones (10, 50, 100, 500 sessions)
• Seasons change your garden — cherry blossoms in spring, snowfall in winter

🌬 DESIGNED FOR CALM
• A garden of layered paper-cut illustrations
• Gentle ambient sounds (rain, forest, ocean, café)
• Wind chime end-of-session sounds — never startling
• Watch your plant grow without opening the app — Dynamic Island on iPhone, a live notification on Android

📊 KNOW YOUR HABITS
• Botanical journal shows your focus history
• Monthly calendar heatmap — green days are focus days
• Lifetime stats: total sessions, focus hours, plants grown

🌱 FREE — ALL OF IT
• Full timer, full garden, every plant type, every garden theme
• Decorate your garden, and export it without a watermark
• No subscription, no purchase, no ads, no account

Cultivate focus. Grow calm. 🌿
```

### 6.3 Screenshots Plan

| Screenshot | Content | Caption |
|---|---|---|
| 1 | Full garden view in spring, lush with plants | "Your garden grows with every focused session" |
| 2 | Active session with plant mid-growth + timer ring | "Watch your plant grow in real-time as you focus" |
| 3 | iOS: Dynamic Island expanded showing timer + plant. Android: live ongoing notification | "Track progress without opening the app" — **two variants required**, one per store |
| 4 | Botanical journal with heatmap | "See your focus habits bloom over time" |
| 5 | Seasonal variety (4 seasons split-screen) | "Your garden changes with the seasons" |
| 6 | The three garden themes side by side | "Three gardens to grow in — all of them free" |

**Who takes them (v2.2):** the owner, from the iOS Simulator (an iPhone 15 Pro or later
simulator shows the Dynamic Island) and the Android emulator, once the final art is in. The
app icon and the Play feature graphic are generated by the art pipeline (§9.1).

---

## 7. Analytics & Telemetry

### 7.1 Key Events to Track

| Event | Parameters | Purpose |
|---|---|---|
| `session_started` | duration, is_custom | Understand preferred session lengths |
| `session_completed` | duration, paused_count | Completion rate by session type |
| `session_abandoned` | duration, elapsed_before_abandon | Drop-off analysis |
| `session_paused` | duration, pause_count | Pause behavior patterns |
| `plant_grown` | species, stage_reached | Garden engagement |
| `garden_viewed` | time_spent, zoom_level | Garden engagement depth |
| `garden_exported` | *(none)* | Sharing behavior |
| `ambient_sound_toggled` | sound_type, enabled | Most popular sounds |
| `settings_changed` | setting_key, old_value, new_value | Customization patterns. Covers every user-chosen setting, the garden theme included (v2.2) |
| `app_opened` | days_since_last_open, streak_days | Retention tracking |
| `onboarding_completed` | steps_completed, time_to_first_session | Onboarding friction |

### 7.2 Privacy

| Requirement | Specification |
|---|---|
| Analytics provider | **None.** Apple's App Analytics has no Android counterpart, and any cross-platform SDK would break the no-third-party-SDK rule. The §7.1 events are written to a local SQLite table behind an analytics port, with a debug-only viewer. The log is bounded and pruned |
| Consequence | §11's KPIs are **not remotely measurable in v1** beyond what App Store Connect and Play Console report on their own (downloads, ratings, crashes). Retention targets are aspirational until a sink is added. This is a deliberate trade for the privacy stance — accept it knowingly |
| Future-proofing | Because every call site talks to a port, adding a real sink later is a one-file change with no re-instrumentation |
| User data | All stored on-device. No server, no cloud, no account, and **no network calls at all** — as of v2.1 the store SDKs are gone with the purchase, so nothing in the binary can open a connection |
| Apple privacy labels | Data NOT collected: name, email, location, browsing history, contacts, identifiers, usage data — nothing leaves the device |
| Play Data Safety form | Must match the above: no data collected, no data shared. Play requires this form and a hosted privacy policy URL regardless of how little you collect |
| ATT prompt | NOT required (no cross-app tracking) |
| Android permissions | `POST_NOTIFICATIONS` (13+), `ACCESS_NOTIFICATION_POLICY` (quiet mode, optional), foreground-service permissions for the live timer surface. Each must be justified in the Play listing |
| Privacy policy | Clearly states: no account, no server, no third-party data sharing, analytics never leave the device |
| Who does it (v2.2) | The privacy policy, the Play Data Safety answers, the IARC questionnaire answers and the App Store privacy-label answers are **drafted in `docs/store/`**. The owner **hosts the privacy policy at a public URL** (a website or GitHub Pages, chosen later but before submission) and enters the answers in Play Console and App Store Connect |

---

## 8. Release Plan

### 8.1 Phase 1 — MVP (v1.0)

| Feature | Status |
|---|---|
Both platforms ship together at parity. Ticket numbers refer to `.scratch/pomodoro-garden/issues/`.

| Feature | Status | Tickets |
|---|---|---|
| Core timer (start, pause, complete) | ✅ v1.0 both | 02, 05 |
| Background reliability + end sound + haptics | ✅ v1.0 both | 06 |
| 6 plant types × 5 growth stages (30 sprite assets) | ✅ v1.0 both | 04 |
| Garden view (isometric, pan/zoom) | ✅ v1.0 both | 07 |
| Seasonal theming | ✅ v1.0 both | 14 |
| Plant inspection modal | ✅ v1.0 both | 12 |
| Bonus/milestone plants (7 types) | ✅ v1.0 both | 13 |
| Live timer surface | ✅ v1.0 — Dynamic Island + Live Activity on iOS, foreground-service notification on Android | 08 |
| Break timer / full Pomodoro cycle | ✅ v1.0 both | 09 |
| Ambient sounds (all 6) | ✅ v1.0 both | 10 |
| Quiet mode | ⚠️ v1.0 **Android only** — iOS gets a Shortcuts recipe, not automation | 11 |
| Botanical journal (stats) | ✅ v1.0 both | 15 |
| Settings & customization | ✅ v1.0 both | 03 |
| Local analytics event log | ✅ v1.0 both | 17 |
| ~~Freemium model~~ | ❌ **withdrawn in v2.1** — the app is free | ~~18~~ |
| Garden themes + decor | ✅ v1.0 both | 19, 20 |
| Garden export | ✅ v1.0 both | 21 |
| Garden reset | ✅ v1.0 both | 22 |
| Onboarding (3 steps) | ✅ v1.0 both | 16 |
| Final art + performance hardening | ⏳ **not done** — art and audio are placeholders; performance is measured but non-blocking (§4.4). See §8.1.1 | 23, 24 |
| Store compliance (privacy policy, Data Safety, IARC, App Store privacy label) | ⏳ **not done** — see §7.2 and §8.1.1 | — |

**v2.2 correction:** the ✅ rows above mean *the feature is built and tested in the repo*.
They do not mean *verified on a device*: the iOS code has not yet been compiled, and nothing
has run on a phone. That happens in §8.1.1's last step.

### 8.1.1 Remaining v1.0 work (added in v2.2)

Each item becomes a ticket in `.scratch/pomodoro-garden/issues/`, numbered from 28. Work
runs in this order, so that steps needing the owner's judgement start first and the code
work fills the waiting time:

| # | Work | Requirement | Owner's part |
|---|---|---|---|
| 1 | **One-plant art test:** the sprite generator, one plant through all five stages, shown in a real garden beside the current soil and sky | REQ-022, §9.1 | ✅ Done: watercolour rejected, **paper-cut chosen** over flat illustration |
| 2 | **Sound sourcing:** CC0 recordings for birdsong, forest and café, or synthesis where none fits | §5.4, §9.2 | None |
| 3 | Theme changes logged in `settings_changed` | §7.1 | None |
| 4 | Break presets 5 / 10 / 15 | REQ-007 | None |
| 5 | Heatmap previous/next month | REQ-027 | None |
| 6 | Garden timer bar | US-006, §5.2 | None |
| 7 | Break-only replay while the app is away, with an ADR amending 0008 | REQ-032 | None |
| 8 | Full art set (35 sprites), soil/sky/weather restyled to match, app icon, Play feature graphic | REQ-022, §9.1 | Spot-check |
| 9 | Enchanted willow glow and Golden Garden shimmer, with the debug preview | REQ-021 | Look at them |
| 10 | All audio produced and bundled; layering fallback if a bed sounds looped | §5.4, §9.2 | Listen |
| 11 | Store-compliance drafts in `docs/store/` | §6.1, §7.2 | Host the policy; fill in both stores' forms |
| 12 | **Hand-off:** build iOS on the owner's Mac and fix what the compiler finds; exercise every feature on the iPhone, the iOS Simulator and the Android emulator; take the store screenshots | §4.4, §6.3, REQ-010/011/014 | All of it — the fixes come back to the repo |

### 8.2 Phase 2 — v1.1 (Post-launch polish)

| Feature | Target |
|---|---|
| Widgets — WidgetKit on iOS, Glance on Android | Q1 2027 |
| Cloud sync (garden across devices) — needs a cross-platform backend, no longer an iCloud freebie | Q1 2027 |
| Additional garden themes | Q1 2027 |
| Tablet-optimized layout (larger garden canvas) — iPad **and** Android tablets | Q1 2027 |
| Localization (EN, RO, ES, FR, DE, JA, ZH) | Q1 2027 |

### 8.3 Phase 3 — v2.0 (Exploration)

| Feature | Target |
|---|---|
| Weather-integrated garden (reads real weather API) | Q2 2027 |
| Watch companions — Apple Watch and Wear OS (glanceable timer + garden) | Q2 2027 |
| ~~Focus mode integration (auto-enable DND)~~ — **shipped on Android in v1.0** (REQ-014); revisit iOS only if Apple opens the API | — |
| Garden sharing (export animated garden video) | Q3 2027 |
| Community gardens (opt-in, see friends' gardens) | Q3 2027 — explore social cautiously |

---

## 9. Asset Production Plan

### 9.1 Illustration Assets

| Asset Category | Count | Notes |
|---|---|---|
| Plant sprites (6 types × 5 stages) | 30 | Paper-cut (v2.2), transparent background. Deliver at the **highest** density needed and downscale at build time — Android's density buckets (mdpi→xxxhdpi) are wider than iOS's @1x–@3x, so commission at the top end once rather than per-platform |
| Bonus plant sprites (7 types × 5 stages) | 35 | Same style, slightly more elaborate |
| Soil/plot tiles | 4 | Empty soil, freshly planted, growing, matured plot |
| Garden background themes | 3 | Zen (default), Tropical, Wildflower — each with seasonal variants (12 total) |
| Seasonal overlays | 4 | Spring blossoms, summer sun rays, autumn leaves, winter snow |
| UI elements | ~20 | Buttons, timer ring, progress bar, tab icons, etc. |
| App icon | 1 | Main icon only. Android additionally needs adaptive-icon foreground/background layers and a Play feature graphic. *(v2.0 listed 3 alternates as an iOS-only premium perk; with nothing to sell they are out of v1.0 entirely.)* |
| **Total illustration assets** | **~100** | Budget: $2,000–$4,000 for freelance illustrator |

**How the art is produced (v2.2).** There is no illustrator. The art comes from a
**procedural generator in the repo** (`tool/generate_sprite_art.dart`), in a **paper-cut**
style: flat coloured layers with slightly irregular cut edges, a soft shadow wherever one
layer lies over another, and a faint fibre texture. It writes each drawing together with the
role mask that lets seasons and themes recolour it (`docs/art-pipeline.md`), and re-runs
whenever a sprite changes. The style was chosen by the owner at the one-plant test (ticket
28): a watercolour version was built first and rejected, then paper-cut was picked over a
flat-illustration version. No image-generation model is used: the store copy says "No AI",
and it stays true of the pictures too.

What changes against the table above:
- **Bonus sprites:** the registry shares **one bonus set of 5 stages** across the seven
  bonus species, so the delivery is 35 sprites, not 65.
- **Soil tiles, backgrounds and seasonal overlays stay code-painted.** They are drawn from
  the season × theme colour table, so the 12 background variants are 12 palettes rather than
  12 images, and a season change keeps its 3 s colour crossfade. They are restyled to the
  paper-cut look (soil tiles as cut paper with a cast shadow, a fibre texture on the sky,
  petals, leaves and flakes as small paper cut-outs) so they match the plants. The summer "sun rays" overlay is dropped: summer has a clear sky.
- **App icon and Play feature graphic** come from the same generator.
- **Budget:** none needed.

### 9.2 Audio Assets

| Asset Category | Count | Notes |
|---|---|---|
| End-of-session sounds | 5 | Wind chime, bell, birdsong, bowl, wave |
| Ambient loops | 6 | Rain, forest, ocean, café, white noise, silence |
| UI micro-sounds | 4 | Soil settle, growth shimmer, button tap, unlock |
| **Total audio assets** | **15** | Budget: $500–$1,000 for sound designer / licensed assets |

**How the audio is produced (v2.2):** synthesised in the repo, plus public-domain (CC0)
recordings for birdsong, forest and café where a good one is available. Formats, loop
lengths and sourcing rules are in §5.4. Silence is a setting, not a file, so there are 14
files. **Budget:** none needed.

---

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Illustration production delays | Medium | High | Build against a sprite registry fed by placeholder shapes (ticket 04). Only tickets 23 and 24 slip if art is late — no logic depends on final assets. *(v2.2: art is now generated in-repo; the risk becomes that the generated style is not good enough, and the one-plant test in §8.1.1 catches that before the full set is drawn)* |
| Store rejection | Low | High | Follow both HIG and Material guidance; no external links in v1; no account = no data-collection concerns. Play additionally requires the Data Safety form, IARC rating and a privacy policy URL — see §7.2 |
| Timer inaccuracy in background | Medium | High | **Do not rely on background execution.** Elapsed time is derived from a wall-clock anchor and recomputed on resume; completion is guaranteed by a local notification scheduled as the app leaves the foreground (REQ-005). Android's foreground service adds a second guarantee. Test a full 120-minute backgrounded session on the owner's iPhone and on the Android emulator (§4.4) |
| Android background-execution fragmentation | High | High | Aggressive OEM battery managers (Xiaomi, Samsung, Huawei) kill background work unpredictably. The wall-clock design means a killed process still produces a correct result on next open; the foreground service and scheduled notification are belt-and-braces. **v2.2: accepted for v1.0 without an aggressive-OEM test device.** Android is verified on the emulator only; watch Play Console vitals after launch |
| iOS force-quit does not void a session | High | Low | **Accepted (v2.2).** See REQ-013. The failure gives the user a plant rather than taking one away |
| Flutter cannot meet a platform requirement natively | Low | Medium | Already scoped: three native surfaces (Live Activity, foreground service, zen rule) sit behind Dart ports. Any further gap follows the same pattern rather than forking the app |
| Low discoverability (61.6% of apps unrated) | Medium | Medium | ASO-optimized metadata; reach out to productivity reviewers; ProductHunt launch |
| Battery drain concerns | Low | Medium | Profile timer + animations; use efficient rendering; test on older devices |
| User perception of similarity to Forest app | Medium | Medium | Emphasize persistent garden (vs. Forest's per-session tree); different aesthetic; no guilt mechanics |
| No revenue at all | High | Medium | Accepted knowingly: v1.0 is free and monetization is not a v1 goal (§2.3). The cost of revisiting it later is one ticket, because nothing in the app is shaped around the absence — see `docs/adr/0021-…` |

---

## 11. Success Metrics & KPIs

### 11.1 Launch Metrics (First 30 Days)

Per §7.2, v1 collects no remote telemetry. Rows marked ⛔ are **not measurable in v1** — they become measurable the moment an analytics sink is plugged into the existing port.

| KPI | Target | How to Measure |
|---|---|---|
| Downloads | 10,000 combined | App Store Connect + Play Console |
| Session completion rate | ≥ 70% | ⛔ local event log only |
| Average sessions per user (daily) | ≥ 2.5 | ⛔ local event log only |
| 7-day retention | ≥ 40% | ⛔ partially inferable from Play Console; not comparable across stores |
| 30-day retention | ≥ 25% | ⛔ as above |
| Store rating | ≥ 4.3 | App Store Connect + Play Console |
| Crashes | < 0.5% of sessions | Xcode Organizer + Play Console vitals |

### 11.2 Long-term Metrics (6 Months)

| KPI | Target |
|---|---|
| Total downloads | 75,000 |
| App Store rating | ≥ 4.6 |
| 30-day retention | ≥ 35% |
| Monthly active users | 20,000 |
| App Store keyword "pomodoro" ranking | Top 20 |

---

## 12. Open Questions

| # | Question | Status |
|---|---|---|
| 1 | Landscape/tablet layouts in v1? | ✅ **Resolved** — deferred to Phase 2, for iPad and Android tablets alike |
| 2 | Are bonus plants user-placed or auto-placed? | ✅ **Resolved** — auto-placed, consistent with REQ-017 |
| 3 | Do we need a tutorial for the live timer surface? | 🔲 Open — Product, Sprint 2 |
| 4 | Should the free tier cap garden plots? | ✅ **Resolved, then moot** — no cap, and as of v2.1 there is no tier to cap |
| 5 | Minimum viable plant illustration count — ship 4 types instead of 6? | ✅ **Resolved** — all 6 ship. Placeholder sprites decouple code from art, so the count costs nothing until ticket 23 |
| 6 | Custom ambient sound uploads? | 🔲 Open — v1.1 decision |
| 7 | "Garden of the day" seasonal store screenshots? | 🔲 Open — Marketing, pre-launch. Note both stores now need screenshot sets |

**Newly open, introduced by the v2.0 platform change:**

| # | Question | Owner | Needed By |
|---|---|---|---|
| ~~8~~ | ~~What is the minimum Android device we commit to for the 60fps / 200-plant target?~~ | — | ✅ **Resolved (v2.2)** — no physical Android device. The references are the owner's iPhone, the iOS Simulator and the Android emulator, and performance does not block v1.0 (§4.4) |
| ~~9~~ | ~~Is $4.99 the right price on Play?~~ | — | ✅ **Moot** — the app is free (v2.1) |
| 10 | Does the garden render identically on both platforms, or do we accept minor divergence where a platform convention conflicts? | Design | Before ticket 07 |

---

## 13. Appendix

### 13.1 Glossary

| Term | Definition |
|---|---|
| **Pomodoro Technique** | Time management method using focused intervals (traditionally 25 min) followed by short breaks |
| **Garden plot** | A slot in the isometric garden grid where a plant can grow |
| **Growth stage** | One of 5 visual states a plant progresses through during a session |
| **Bonus plant** | Special plant awarded at session count milestones |
| **Garden level** | Derived from total sessions completed; determines available plot count |
| **Live timer surface** | The umbrella term for showing an active session outside the app. Implemented differently per platform — see the two rows below |
| **Live Activity** | iOS feature showing real-time app activity on lock screen and Dynamic Island |
| **Dynamic Island** | iPhone 14 Pro+ interactive area at top of screen. **No Android equivalent exists** |
| **Foreground service** | Android's mechanism for user-visible ongoing work, backed by a persistent notification. Carries the live timer on Android |
| **Quiet mode** | The app's DND/Focus integration. Automated on Android via a zen rule; user-configured via Shortcuts on iOS (REQ-014) |
| **Port** | An abstract Dart interface the domain depends on, with platform or plugin implementations behind it. Keeps native divergence out of the core |

### 13.2 Competitive Analysis Deep Dive

| App | Platforms | Price | Garden? | Persistent? | Live timer surface? | Seasons? | Bonus Plants? | Subscription? |
|---|---|---|---|---|---|---|---|---|
| **Forest** | iOS + Android | $3.99 (one-time) | Per-session tree | No (resets each session) | No | No | No | No |
| **Focus Keeper** | iOS | Free + $1.99/mo | No | N/A | No | No | No | Yes (subscription) |
| **Be Focused** | iOS/macOS | Free + $4.99 | No | N/A | No | No | No | No (one-time) |
| **Flora** | iOS | Free + $1.99/mo | Per-session tree | No | No | No | No | Yes (subscription) |
| **Pomodoro Garden** | **iOS + Android** | **Free** | **Persistent garden** | **Yes** | **Yes (both platforms)** | **Yes** | **Yes (7 types)** | **No — nothing to buy** |

Note that shipping Android puts us head-to-head with **Forest**, our closest competitor, on its own turf — where iOS-only rivals like Flora and Focus Keeper are absent. The persistent-garden differentiator matters more there, not less, and as of v2.1 we are the only app in this table with nothing to buy.

---

**End of PRD — Pomodoro Garden v2.1**

This document is a living artifact. Update version, date, and status as requirements evolve. All stakeholders should review and approve before sprint planning begins.
