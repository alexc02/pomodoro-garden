# PRD v2.1 vs implementation: gap report

**Date:** 2026-10-10
**Scope:** every requirement in `PRD.md` v2.1 (§2–§9), checked against the code in `lib/`,
`packages/pomodoro_domain/`, `ios/` and `android/`. Ticket files were read for context, but
each finding below was confirmed in the source. No code was changed.

**Build health at time of review:** `flutter analyze --fatal-infos` clean · app tests
**958 passed** · domain tests **382 passed**.

---

## 1. Verdict

The functional product is broadly complete. Every epic has working code behind it, and the
main workflows run end to end: onboarding, then start, pause/cancel and complete, then plant
sown, then garden, card, journal, settings, reset and export.

What is missing falls into three groups:

| Group | Count | Nature |
|---|---|---|
| **A. Not implemented**: a PRD requirement with no code behind it | 4 | Fixable in this repo |
| **B. Implemented differently** from what the PRD says | 7 | Product decision needed: accept, or change PRD/code |
| **C. Blocked on external deliverables** (art, audio, devices, store work) | 6 | Cannot be closed in this repo |

---

## 2. A — Not implemented

### A1. Break-length presets are missing (REQ-007, US-010) — **Medium**
- **PRD:** "Break lengths — Presets: 5 min (Short), 10 min (Standard), 15 min (Long)."
- **Code:** Settings → Breaks has only a 1–30 min slider (`settings_screen.dart`,
  `_BreaksSection`). There is no break counterpart to the session-length `SessionPreset`.
- **Also:** the long-break length can't be set. It is hard-wired to 3× the break length,
  capped at 30 (`GardenSettings.longBreakLength`, `longBreakMultiple = 3`). The PRD's
  "Long" preset implies the user picks it.
- No ticket covered this. Ticket 03 implemented the *session* presets only.

### A2. The two top milestone plants have no special effect (REQ-021) — **Medium**
- **PRD:** 500 sessions → "Enchanted willow **(subtle glow)**"; 1000 sessions →
  "Golden garden **(all plants shimmer)**".
- **Code:** both species exist and are awarded (`milestone.dart`), but nothing draws a glow
  for the willow or makes the rest of the garden shimmer once the Golden Garden is earned.
  They render like any other bonus plant. Ticket 13's acceptance criteria never asked for
  either effect.

### A3. Force-quitting on iOS does not reliably void the session (REQ-013) — **Medium**
- **PRD:** "If user force-quits app during session: session is voided, seed does NOT grow."
- **Code:** voiding relies on `AppLifecycleState.detached` (`session_lifecycle.dart`). iOS
  does not send it when the user swipes away an app that is already suspended, which is the
  usual way to force-quit. The session is then **restored** on the next launch and can still
  earn its plant. Android behaves correctly.
- The team documented this and accepted it (ADR 0005, revisited in ticket 08 / ADR 0007),
  but it remains a PRD violation on one platform. Product should either accept it formally
  and amend REQ-013, or ask for a fix.

### A4. Theme changes are not logged (§7.1 `settings_changed`) — **Low**
- `SettingKey` in `analytics_event.dart` covers ten settings but not `gardenTheme`, so
  changing the theme in the Theme picker records no event. Every other user-facing setting
  is logged.

---

## 3. B — Implemented differently from the PRD

| # | PRD says | App does | Impact |
|---|---|---|---|
| B1 | REQ-005: completion is "guaranteed by a local notification **scheduled at start**" | The notification is scheduled when the app **leaves the foreground** and cancelled on return (`session_announcer.dart`). In the foreground, the app chimes itself | Low. Same outcome in normal use; it avoids a double chime. Worth noting because REQ-005 names the mechanism |
| B2 | REQ-032: auto-start break / auto-start next session | Works only while the app is running. If the app is closed, the cycle stops at the end of the current countdown and resumes on next open (ADR 0008; the Settings note says so) | Medium. A user expecting an unattended Pomodoro cycle with the phone locked won't get one |
| B3 | §5.2 Screen 1: the garden home shows the timer ring and **START** under the garden | Garden and Timer are separate tabs. The app opens on Garden, which has no start control, so starting takes a tab switch (onboarding handles this on first run) | Medium for US-006 "single tap". On every launch after the first, starting a session takes two taps |
| B4 | US-007 / §5.2 Screen 2: ring "around the garden plot", countdown plus **% complete** | Ring surrounds the countdown digits; the growing plant sits below the ring; no percentage | Low, visual only |
| B5 | REQ-008 / §5.4: sounds as **AAC**, ambient loops **60 s** | Ambient loops are lossless WAV (~15 s); end sounds are WAV. Lossy AAC can't loop within the <5 ms seam budget, and 60 s of WAV breaks the 8 MB audio budget (`docs/ambience.md`) | The PRD contradicts itself here; the code picks the seam and size budgets over the format. The PRD should be amended |
| B6 | §5.1: SF Pro / SF Pro Rounded | Nunito (headings, numbers) + Caveat (botanical labels), bundled, so both platforms look the same | Low, deliberate. PRD should be amended |
| B7 | §4.3: `plants.isBonusPlant` column | Not stored; a plant is a bonus plant exactly when `milestoneSessions` is set | None. Deliberate (ticket 13); PRD data model is out of date |

**Observation (not a PRD violation):** the journal heatmap (REQ-027) only shows the
**current month**, with no way to look at earlier months. The PRD doesn't require history,
but US-024 ("visualise my habit") will feel thin on the 1st of each month.

---

## 4. C — Blocked on external deliverables

These are tracked as open in tickets 23 and 24. They are listed here because the PRD's §8.1
release table marks all of them ✅ for v1.0.

| # | Requirement | State |
|---|---|---|
| C1 | **Final watercolour art** (REQ-022, §5.1, §9.1) | All plant, bonus and decor sprites are **placeholders**; the registry is wired for a file swap. **Soil tiles, seasonal overlays and theme backgrounds have no art seam at all**, so adding them needs code, not just assets. §9.1's summer "sun rays" overlay doesn't exist (summer has an empty sky). App icon is a generated, provisional seedling |
| C2 | **Final audio** (§5.4, §9.2) | All 15 sounds (5 end, 5 ambient, 4 micro, plus silence) are **synthesised placeholders** waiting on the sound designer. Delivery must be lossless (see B5) |
| C3 | **Performance targets** (§4.4) | Not measured on a device: 60 fps with 200 plants, cold launch <1.5 s, battery <3% per 25 min, ±1 s timer over a real 120-min backgrounded session, loop seam with real audio. Proxies exist and pass. Android release is 29.3 MB (under 50 MB); **iOS size unknown**. Open question #8 (reference Android device) is still unanswered |
| C4 | **iOS native code** (REQ-010 Live Activity / Dynamic Island, REQ-014 App Intent, export share sheet) | The Swift exists but has **never been compiled or run**; there's no macOS here. Android Kotlin builds but has not run on a device. Each platform surface needs a device pass, including at least one aggressive-OEM Android phone (§10) |
| C5 | **Store compliance** (§6.1, §7.2) | Privacy policy URL, Play Data Safety form and IARC rating: **not done, and no ticket owns them** (the PRD's own v2.1 changelog says so). Required for Play submission |
| C6 | **Store listing assets** (§6.3, §9.1) | No screenshots (6, with two variants of #3 per store), no Play feature graphic |

**Still-open PRD questions that affect release:** #3 (live-surface tutorial), #8 (reference
device for the 60 fps budget), #10 (whether the garden may look different per platform).

---

## 5. Confirmed implemented

| Area | Requirements | Evidence |
|---|---|---|
| Onboarding | REQ-001–004, US-001–005 | `features/onboarding/`: 3 steps (welcome + garden preview, 15/25/50 choice, start), coach marks over the live UI, 0.8 s seed drop with particle burst |
| Timer engine | REQ-005, REQ-006, REQ-009 | Wall-clock anchored `SessionMachine` with injected clock; presets 15/25/50 + 5–120 slider; pause at 50 % growth; cancel with confirmation |
| Interruption | REQ-013 (Android; iOS see A3) | `SessionLifecycle` voids on detach; backgrounding continues |
| Background + end | US-008, US-011, REQ-031, REQ-037 | Scheduled notification with the chosen sound; 6 end sounds incl. None, previewable; success + stage haptics, switchable |
| Breaks / cycle | REQ-030, REQ-032 (see A1, B2) | Break 1–30, long break after 2–6, both auto-start switches |
| Live surface | REQ-010, REQ-011, REQ-033 | iOS ActivityKit widget (compact/expanded/minimal/lock screen); Android foreground service with ongoing notification; toggle default ON |
| Ambient | REQ-012 | 6 options incl. Silence, bundled, looping, picker on the timer screen; audio-session interruption handling |
| Quiet mode | REQ-014 | Android `AutomaticZenRule` + permission flow; iOS App Intent + one-time Shortcuts hint; toggle Android-only |
| Garden | REQ-015–018, REQ-020, REQ-023, REQ-024 | 6 types by length, 17 species; 5 stages at 0/20/50/80/100 %; 12 → +4 per 10 sessions → 200 plots, centre-out; pan/zoom; tap → card with type, date, length, stage, quote; spring transitions, 4 s / 2° phase-randomised sway; Drift persistence |
| Seasons | REQ-019 | Device-date season (hemisphere-aware); blossom / leaves / snow particles; bare branches except evergreens; 3 s crossfade |
| Milestones | REQ-021 (see A2) | All 7 awarded once each, auto-placed, quiet celebration after the bloom, excluded from session stats |
| Journal | REQ-025–029 | Paper texture + handwritten headers; week card (sessions, focus time, plants, streak); month heatmap; lifetime (sessions, hours, plants, level, bonus); "Your garden rested for N days" |
| Themes / decor | REQ-034, REQ-040 | Zen / Tropical / Wildflower × 4 seasons; lantern, bench, birdbath, pond placeable, movable, removable, never taking a plant's plot |
| Export / reset | REQ-035, REQ-036 | High-res PNG of the whole garden, no watermark, platform share sheet; reset behind two confirmations with the PRD's exact wording |
| Free app | REQ-038, REQ-039 | No store SDK, no billing permission, no money in any string; every feature available |
| Privacy / analytics | §7.1, §7.2 (see A4) | All 11 events typed and logged to a bounded, pruned local table; debug-only viewer; no network dependency; INTERNET permission only in debug/profile manifests |
| Animations | §5.3 | All six: seed drop, growth spring, sway, bloom (2 s petals), garden entry fade/scale 0.95, seasonal crossfade |
| Micro-sounds | §5.4, §9.2 | Soil settle, growth shimmer, button tap, unlock, all wired (placeholder audio) |

---

## 6. PRD inconsistencies found along the way

- **REQ-008 vs REQ-031:** REQ-008 lists 3 end sounds; REQ-031 and §5.4 list 6. The code
  ships 6. Correct REQ-008.
- **§5.4:** "AAC, 60 s loop" can't meet both the §4.4 seam budget and the §5.4 8 MB
  budget (see B5).
- **§4.3:** `isBonusPlant` and the settings table no longer match the shipped schema
  (v19; it also stores `quietModeHintDismissed`).
- **§8.1:** marks art, performance and store readiness ✅ for v1.0; tickets 23 and 24 are
  open and C5 has no owner.

## 7. Suggested next steps

1. Decide A1–A4 and B2/B3 with Product. A1, A2 and A4 are small, self-contained tickets.
2. Assign an owner for C5 (privacy policy, Data Safety, IARC). It blocks Play submission.
3. Plan a device pass (macOS + iPhone, mid-range and aggressive-OEM Android) for C3/C4.
4. Amend the PRD for B5, B6, B7 and §6's inconsistencies so the document matches reality.
