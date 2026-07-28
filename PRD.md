# 📋 Product Requirements Document (PRD)

# Pomodoro Garden

**Version:** 1.0  
**Last Updated:** July 2026  
**Author:** Product Team  
**Status:** Draft  

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
| App Store visibility | App Store keyword ranking | Top 20 for "pomodoro timer" within 6 months |
| User acquisition | Downloads in first 3 months | 50,000 |
| User retention | 30-day retention rate | ≥ 35% |
| Monetization | Freemium conversion rate | ≥ 4% |
| User satisfaction | Average App Store rating | ≥ 4.6 stars |
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
| Social/multiplayer garden | v1 is personal; social adds pressure |
| Task management | We're a focus timer, not a to-do app |
| Cross-device sync | v1 is device-local; iCloud sync is a v2 consideration |
| Web or Android version | iOS/iPadOS first; validate before expanding |
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
| REQ-001 | No account creation required for v1 | All data stored locally on-device via Core Data |
| REQ-002 | Default session length | 25 minutes (classic Pomodoro), configurable in Settings |
| REQ-003 | Onboarding flow | Maximum 3 screens: (1) Welcome + garden preview, (2) Choose session length, (3) Start — that's it |
| REQ-004 | First-session seed animation | Seed drops into soil with a soft particle effect; soil settles around it |

---

### 3.2 Epic 2: Focus Timer Core

#### User Stories

| ID | Story | Priority |
|---|---|---|
| US-006 | As a user, I want to start a focus session with a single tap, so I can get to work instantly. | P0 |
| US-007 | As a user, I want to see a circular progress ring around the garden plot showing time remaining, so I know how long without checking numbers. | P0 |
| US-008 | As a user, I want to hear a gentle, natural sound when my session ends (not an alarm), so I'm not startled out of flow. | P0 |
| US-009 | As a user, I want to pause a session if needed (emergencies happen), so I don't lose my progress unfairly. | P1 |
| US-010 | As a user, I want to optionally enable a short break timer after each session, so I can follow the full Pomodoro cycle. | P1 |
| US-011 | As a user, I want the app to work in the background and lock screen, so I can close the app and still get notified. | P0 |
| US-012 | As a user, I want to see the timer on my Dynamic Island / Live Activity, so I can monitor progress without opening the app. | P1 |
| US-013 | As a user, I want to choose from ambient background sounds during my session, so I can create a focused atmosphere. | P1 |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-005 | Timer engine | Built on `Timer.publish` with background task support via `BGAppRefreshTask` |
| REQ-006 | Session lengths | Presets: 15 min (Short), 25 min (Classic), 50 min (Deep). Custom range: 5–120 min |
| REQ-007 | Break lengths | Presets: 5 min (Short), 10 min (Standard), 15 min (Long). Auto-start option toggle |
| REQ-008 | End-of-session sound | 3 gentle sound options: wind chime, soft bell, birdsong. Default: wind chime |
| REQ-009 | Pause behavior | Pause allowed; session resumes from paused time. Paused sessions still grow the plant but at reduced growth rate (50%) |
| REQ-010 | Dynamic Island | Compact: tiny ring + plant icon. Expanded: progress ring + time remaining + plant growth stage |
| REQ-011 | Live Activity | Lock screen shows minimal timer ring + garden icon. Persists during active session |
| REQ-012 | Background sounds | 6 ambient options: Rain, Forest, Ocean, Café, White Noise, Silence. Loop seamlessly. No streaming — bundled audio files |
| REQ-013 | Interruption handling | If user force-quits app during session: session is voided, seed does NOT grow. If app is backgrounded normally: session continues |
| REQ-014 | Do Not Disturb integration | Optionally toggle Focus Mode (DND) automatically when session starts. Revert when session ends |

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

| REQ-022 | Plant rendering | Sprite-based 2D illustrations (not 3D). Each plant type × 5 stages = ~36 illustrated assets. Hand-drawn watercolor style |
| REQ-023 | Animations | Smooth transitions between growth stages using SwiftUI animations. Gentle sway animation on mature plants (ambient wind effect) |
| REQ-024 | Garden persistence | All garden state stored in Core Data. Plant positions, types, growth stages, and metadata persist across app launches |

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
| REQ-027 | Calendar heatmap | Monthly grid; intensity of green = number of sessions that day. Empty days = bare soil color |
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
| US-030 | As a user, I want to enable/disable Dynamic Island and Live Activities, so I control what appears on my lock screen. | P1 |
| US-031 | As a user, I want to choose a garden theme (biome), so my garden feels personal. | P2 (Premium) |
| US-032 | As a user, I want to export my garden as an image, so I can share my progress. | P1 |
| US-033 | As a user, I want to reset my garden (with confirmation), so I can start fresh if I want. | P1 |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-030 | Timer customization | Session: 5–120 min slider. Break: 1–30 min slider. Long break after N sessions: 2–6 |
| REQ-031 | Sound selection | End-of-session: Wind Chime (default), Soft Bell, Birdsong, Singing Bowl, Ocean Wave, None |
| REQ-032 | Auto-start toggles | Auto-start break: on/off. Auto-start next session: on/off |
| REQ-033 | Dynamic Island / Live Activity | Toggle on/off in Settings. Default: ON |
| REQ-034 | Garden themes (Premium) | 3 themes in v1: (1) Zen Garden [default, free], (2) Tropical Greenhouse [premium], (3) Wildflower Meadow [premium]. Each theme reskins garden background, soil, and decor |
| REQ-035 | Garden export | Export as high-res PNG with watermark removed for premium users. Free users: small watermark in corner |
| REQ-036 | Garden reset | Settings → Reset Garden → Double confirmation ("This will clear all plants and stats. This cannot be undone.") |
| REQ-037 | Haptic feedback | Gentle success haptic when session completes. Subtle haptic when plant grows to next stage. Configurable on/off |

---

### 3.6 Epic 6: Monetization (Freemium)

#### User Stories

| ID | Story | Priority |
|---|---|---|
| US-034 | As a free user, I want full access to the core timer and garden, so I can enjoy the app without paying. | P0 |
| US-035 | As a premium user, I want exclusive garden themes and bonus plant types, so my garden feels special. | P1 |
| US-036 | As a user, I want a one-time purchase option (not a subscription), so I can own the app outright. | P0 |

#### Requirements

| ID | Requirement | Specification |
|---|---|---|
| REQ-038 | Monetization model | Freemium with one-time premium unlock. NO subscription. NO ads. |
| REQ-039 | Free tier includes | Full timer, full garden, all 6 plant types, all bonus/milestone plants, basic Zen Garden theme, stats, Dynamic Island, ambient sounds (3 of 6) |
| REQ-040 | Premium tier ($4.99 one-time) includes | All garden themes (Tropical, Wildflower), all 6 ambient sounds, watermark-free garden export, exclusive premium-only plant type: "Enchanted Garden" plants (glowing variants), custom session labels/tags, calendar export to Apple Calendar |
| REQ-041 | Paywall screen | Beautiful, non-aggressive. Shows premium themes as preview. "Unlock the full garden" messaging. Appears only in Settings and theme picker, never interrupts a focus session |

---

## 4. Technical Architecture

### 4.1 Technology Stack

| Layer | Technology | Rationale |
|---|---|---|
| UI Framework | SwiftUI | Native, declarative, animation-friendly, modern |
| Minimum iOS | iOS 17.0 | Dynamic Island + Live Activities support (iOS 16.1+), WidgetKit improvements |
| Data persistence | Core Data (local) | Robust on-device storage; no server dependency; offline-first |
| Audio | AVFoundation | Ambient sound looping + end-of-session chimes |
| Timer | Combine `Timer.publisher` + `BGAppRefreshTask` | Foreground precision + background reliability |
| Live Activity | ActivityKit | Dynamic Island + lock screen timer |
| Haptics | UIKit `UIImpactFeedbackGenerator` | Tactile growth feedback |
| Graphics | 2D sprite assets (PNG @3x) | Hand-drawn watercolor illustrations, bundled in app |
| Animations | SwiftUI `withAnimation` + `CAKeyframeAnimation` | Smooth plant growth transitions + ambient sway |

### 4.2 Architecture Diagram (Text)

```
┌──────────────────────────────────────────────┐
│                   SwiftUI App                │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐  │
│  │  Garden   │  │  Timer   │  │  Settings  │  │
│  │   View    │  │   View   │  │    View    │  │
│  └────┬─────┘  └────┬─────┘  └─────┬──────┘  │
│       │              │              │         │
│  ┌────┴──────────────┴──────────────┴──────┐  │
│  │            ViewModel Layer              │  │
│  │  ┌──────────┐  ┌───────────────────┐   │  │
│  │  │  Timer    │  │  Garden Manager    │   │  │
│  │  │  Engine   │  │  (plant placement, │   │  │
│  │  │          │  │   growth, seasons)  │   │  │
│  │  └────┬─────┘  └────────┬──────────┘   │  │
│  │       │                  │               │  │
│  │  ┌────┴──────────────────┴──────────┐   │  │
│  │  │         Core Data Layer            │   │  │
│  │  │  ┌─────────┐  ┌────────────────┐  │   │  │
│  │  │  │ Session  │  │  Plant Entity   │  │   │  │
│  │  │  │ Entity   │  │  (type, stage,  │  │   │  │
│  │  │  │          │  │   position,     │  │   │  │
│  │  │  │          │  │   date)         │  │   │  │
│  │  │  └─────────┘  └────────────────┘  │   │  │
│  │  └───────────────────────────────────┘   │  │
│  └──────────────────────────────────────────┘  │
│                                                  │
│  ┌──────────────────────────────────────────┐  │
│  │         Background Services               │  │
│  │  ┌──────────┐  ┌─────────────────────┐   │  │
│  │  │ActivityKit│  │  AVFoundation       │   │  │
│  │  │(Live Act.) │  │  (ambient sounds)   │   │  │
│  │  └──────────┘  └─────────────────────┘   │  │
│  └──────────────────────────────────────────┘  │
└──────────────────────────────────────────────┘
```

### 4.3 Data Model

```
SessionEntity
├── id: UUID
├── startDate: Date
├── durationMinutes: Int16
├── completed: Bool
├── pausedDurationSeconds: Int32
└── plant: PlantEntity (one-to-one)

PlantEntity
├── id: UUID
├── type: String (enum: wildflower, herb, flower, bush, smallTree, largeTree, bonus)
├── species: String (e.g., "sunflower", "basil", "cherry_blossom")
├── growthStage: Int16 (0-4)
├── plotX: Int16
├── plotY: Int16
├── plantedDate: Date
├── sessionDurationMinutes: Int16
└── isBonusPlant: Bool

SettingsEntity
├── sessionLengthMinutes: Int16
├── breakLengthMinutes: Int16
├── longBreakAfterSessions: Int16
├── autoStartBreak: Bool
├── autoStartSession: Bool
├── endSound: String
├── ambientSound: String
├── hapticsEnabled: Bool
├── dynamicIslandEnabled: Bool
├── dndIntegrationEnabled: Bool
├── gardenTheme: String
├── isPremium: Bool
└── totalSessionsCompleted: Int32
```

### 4.4 Performance Requirements

| Metric | Target |
|---|---|
| App launch to garden visible | < 1.5 seconds |
| Timer accuracy | ±1 second over 120-minute session |
| Battery drain during active session | < 3% per 25-minute session |
| Garden render with 200 plants | 60fps, no frame drops |
| Ambient sound loop seam | Inaudible (< 5ms gap) |
| App binary size | < 50 MB |

---

## 5. Design Specifications

### 5.1 Visual Design Language

| Attribute | Specification |
|---|---|
| **Style** | Hand-drawn watercolor meets modern UI. Think *Studio Ghibli garden* × *Apple Reminders minimalism* |
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

| **Iconography** | |
|---|---|
| App icon | A single watercolor seedling in soil, rounded square. No text. Recognizable at all sizes. |
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
| Growth stage transition | Stage threshold reached | 1.2s | spring(response: 0.6, dampingFraction: 0.7) | Plant scales up with slight overshoot |
| Mature plant sway | Continuous (ambient) | 4s loop | ease-in-out | 2° rotation, randomized per plant |
| Session end celebration | Session completes | 2s | spring + ease | Plant blooms with particle petals/spores |
| Garden entry | App launches / returns | 0.5s | ease-out | Gentle fade-in + scale from 0.95 |
| Seasonal transition | Real-world season change detected | 3s | ease-in-out | Background color crossfade; leaves fall/don't |

### 5.4 Sound Design

| Sound | Context | Source | Format |
|---|---|---|---|
| Wind Chime | Session end (default) | Recorded real wind chimes | AAC, 3s |
| Soft Bell | Session end (option) | Tibetan bowl | AAC, 4s |
| Birdsong | Session end (option) | Robin chirp recording | AAC, 3s |
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

---

## 6. App Store Optimization (ASO) Strategy

### 6.1 App Metadata

| Field | Value |
|---|---|
| **App Name** | Pomodoro Garden — Focus Timer |
| **Subtitle** | Grow your garden by staying focused |
| **Primary Category** | Productivity |
| **Secondary Category** | Health & Fitness |
| **Keywords** | pomodoro, focus, timer, garden, plants, concentration, study, deep work, mindfulness, grow, nature, calm, productivity, tomato, timer, study timer, work timer |
| **Content Rating** | 4+ (No objectionable content) |
| **App Store Description** | *(see below)* |

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
• Beautiful hand-drawn watercolor illustrations
• Gentle ambient sounds (rain, forest, ocean, café)
• Wind chime end-of-session sounds — never startling
• Dynamic Island shows your growing plant without opening the app

📊 KNOW YOUR HABITS
• Botanical journal shows your focus history
• Monthly calendar heatmap — green days are focus days
• Lifetime stats: total sessions, focus hours, plants grown

🌱 FREE FOREVER (core experience)
• Full timer, full garden, all plant types — free
• Premium themes & extras available as one-time purchase (no subscription!)

Cultivate focus. Grow calm. 🌿
```

### 6.3 Screenshots Plan

| Screenshot | Content | Caption |
|---|---|---|
| 1 | Full garden view in spring, lush with plants | "Your garden grows with every focused session" |
| 2 | Active session with plant mid-growth + timer ring | "Watch your plant grow in real-time as you focus" |
| 3 | Dynamic Island expanded showing timer + plant | "Track progress right from your Dynamic Island" |
| 4 | Botanical journal with heatmap | "See your focus habits bloom over time" |
| 5 | Seasonal variety (4 seasons split-screen) | "Your garden changes with the seasons" |
| 6 | Premium themes preview | "Unlock beautiful garden themes" |

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
| `garden_exported` | is_premium | Sharing behavior |
| `ambient_sound_toggled` | sound_type, enabled | Most popular sounds |
| `paywall_viewed` | source_screen | Conversion funnel |
| `premium_purchased` | source_screen | Revenue attribution |
| `settings_changed` | setting_key, old_value, new_value | Customization patterns |
| `app_opened` | days_since_last_open, streak_days | Retention tracking |
| `onboarding_completed` | steps_completed, time_to_first_session | Onboarding friction |

### 7.2 Privacy

| Requirement | Specification |
|---|---|
| Analytics provider | Apple's App Analytics + custom telemetry (no third-party SDK in v1) |
| User data | All stored on-device. No server, no cloud, no account |
| Privacy labels | Data NOT collected: name, email, location, browsing history, contacts |
| Privacy labels | Data collected (anonymous, for analytics only): usage data, diagnostics |
| ATT prompt | NOT required (no cross-app tracking) |
| Privacy policy | Clearly states: no account, no server, no third-party data sharing |

---

## 8. Release Plan

### 8.1 Phase 1 — MVP (v1.0)

| Feature | Status |
|---|---|
| Core timer (start, pause, complete) | ✅ v1.0 |
| 6 plant types × 5 growth stages (30 sprite assets) | ✅ v1.0 |
| Garden view (isometric, pan/zoom) | ✅ v1.0 |
| Seasonal theming | ✅ v1.0 |
| Plant inspection modal | ✅ v1.0 |
| Bonus/milestone plants (7 types) | ✅ v1.0 |
| Dynamic Island + Live Activity | ✅ v1.0 |
| Ambient sounds (3 free, 3 premium) | ✅ v1.0 |
| Botanical journal (stats) | ✅ v1.0 |
| Settings & customization | ✅ v1.0 |
| Freemium model ($4.99 one-time) | ✅ v1.0 |
| Garden export | ✅ v1.0 |
| Onboarding (3 steps) | ✅ v1.0 |

### 8.2 Phase 2 — v1.1 (Post-launch polish)

| Feature | Target |
|---|---|
| Widget (home screen garden mini-view) | Q1 2027 |
| iCloud sync (garden across devices) | Q1 2027 |
| Additional garden themes | Q1 2027 |
| iPad-optimized layout (larger garden canvas) | Q1 2027 |
| Localization (EN, RO, ES, FR, DE, JA, ZH) | Q1 2027 |

### 8.3 Phase 3 — v2.0 (Exploration)

| Feature | Target |
|---|---|
| Weather-integrated garden (reads real weather API) | Q2 2027 |
| Apple Watch companion (glanceable timer + garden) | Q2 2027 |
| Focus mode integration (auto-enable DND) | Q2 2027 |
| Garden sharing (export animated garden video) | Q3 2027 |
| Community gardens (opt-in, see friends' gardens) | Q3 2027 — explore social cautiously |

---

## 9. Asset Production Plan

### 9.1 Illustration Assets

| Asset Category | Count | Notes |
|---|---|---|
| Plant sprites (6 types × 5 stages) | 30 | Hand-drawn watercolor, PNG @3x, transparent background |
| Bonus plant sprites (7 types × 5 stages) | 35 | Same style, slightly more elaborate |
| Soil/plot tiles | 4 | Empty soil, freshly planted, growing, matured plot |
| Garden background themes | 3 | Zen (default), Tropical, Wildflower — each with seasonal variants (12 total) |
| Seasonal overlays | 4 | Spring blossoms, summer sun rays, autumn leaves, winter snow |
| UI elements | ~20 | Buttons, timer ring, progress bar, tab icons, etc. |
| App icon variants | 1 + 3 alt | Main + alternate icons (premium feature) |
| **Total illustration assets** | **~100** | Budget: $2,000–$4,000 for freelance illustrator |

### 9.2 Audio Assets

| Asset Category | Count | Notes |
|---|---|---|
| End-of-session sounds | 5 | Wind chime, bell, birdsong, bowl, wave |
| Ambient loops | 6 | Rain, forest, ocean, café, white noise, silence |
| UI micro-sounds | 4 | Soil settle, growth shimmer, button tap, unlock |
| **Total audio assets** | **15** | Budget: $500–$1,000 for sound designer / licensed assets |

---

## 10. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Illustration production delays | Medium | High | Start asset production in parallel with code; use placeholder shapes first |
| App Store rejection | Low | High | Follow HIG; avoid any external links in v1; no account = no data collection concerns |
| Timer inaccuracy in background | Medium | High | Use `BGAppRefreshTask` + local notifications as fallback; test extensively |
| Low discoverability (61.6% of apps unrated) | Medium | Medium | ASO-optimized metadata; reach out to productivity reviewers; ProductHunt launch |
| Battery drain concerns | Low | Medium | Profile timer + animations; use efficient rendering; test on older devices |
| User perception of similarity to Forest app | Medium | Medium | Emphasize persistent garden (vs. Forest's per-session tree); different aesthetic; no guilt mechanics |
| Premium conversion too low | Medium | Medium | Generous free tier builds trust; one-time purchase (not subscription) is a selling point |

---

## 11. Success Metrics & KPIs

### 11.1 Launch Metrics (First 30 Days)

| KPI | Target | How to Measure |
|---|---|---|
| Downloads | 10,000 | App Store Connect |
| Session completion rate | ≥ 70% | `session_completed / session_started` |
| Average sessions per user (daily) | ≥ 2.5 | Analytics |
| 7-day retention | ≥ 40% | Analytics |
| 30-day retention | ≥ 25% | Analytics |
| App Store rating | ≥ 4.3 | App Store Connect |
| Premium conversion | ≥ 2% | StoreKit transactions |
| Crashes | < 0.5% of sessions | Crash logs |

### 11.2 Long-term Metrics (6 Months)

| KPI | Target |
|---|---|
| Total downloads | 75,000 |
| App Store rating | ≥ 4.6 |
| 30-day retention | ≥ 35% |
| Premium conversion | ≥ 4% |
| Monthly active users | 20,000 |
| App Store keyword "pomodoro" ranking | Top 20 |

---

## 12. Open Questions

| # | Question | Owner | Needed By |
|---|---|---|---|
| 1 | Should we support landscape mode for iPad in v1 or defer to v1.1? | Product | Sprint 0 |
| 2 | Should bonus plants be placeable by the user or auto-placed? | Design | Sprint 1 |
| 3 | Do we need a tutorial for the Dynamic Island, or is it discoverable? | Product | Sprint 2 |
| 4 | Should the free tier limit the number of garden plots to create urgency for premium? | Product/Business | Sprint 0 |
| 5 | What's the minimum viable number of plant illustrations for launch (can we ship with 4 types instead of 6)? | Design | Sprint 0 |
| 6 | Should we support custom ambient sound uploads (user's own audio)? | Product | v1.1 decision |
| 7 | Do we want a "garden of the day" screenshot for App Store featuring different seasons? | Marketing | Pre-launch |

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
| **Live Activity** | iOS feature showing real-time app activity on lock screen and Dynamic Island |
| **Dynamic Island** | iPhone 14 Pro+ interactive area at top of screen |

### 13.2 Competitive Analysis Deep Dive

| App | Price | Garden? | Persistent? | Dynamic Island? | Seasons? | Bonus Plants? | Subscription? |
|---|---|---|---|---|---|---|---|
| **Forest** | $3.99 (one-time) | Per-session tree | No (resets each session) | No | No | No | No |
| **Focus Keeper** | Free + $1.99/mo | No | N/A | No | No | No | Yes (subscription) |
| **Be Focused** | Free + $4.99 | No | N/A | No | No | No | No (one-time) |
| **Flora** | Free + $1.99/mo | Per-session tree | No | No | No | No | Yes (subscription) |
| **Pomodoro Garden** | Free + $4.99 | **Persistent garden** | **Yes** | **Yes** | **Yes** | **Yes (7 types)** | **No (one-time)** |

---

**End of PRD — Pomodoro Garden v1.0**

This document is a living artifact. Update version, date, and status as requirements evolve. All stakeholders should review and approve before sprint planning begins.
