# 01 — Project scaffold, app shell, and design tokens

**What to build:** A Flutter app that launches and runs on both an iOS simulator and an Android emulator, showing a four-tab shell — garden, timer, botanical journal, settings — that navigates between placeholder screens. The visual language from PRD §5.1 exists as reusable tokens so no later ticket hardcodes a colour or a font size.

This ticket also fixes the project's structural decisions, which every later ticket inherits: **Riverpod** for state management and dependency injection, and a **pure-Dart domain package with no Flutter imports** for the timer, growth, placement and milestone logic. That separation is what makes ticket 02's state machine testable with an injected clock, so establish it before there is any logic to move.

**Blocked by:** None — can start immediately.

**Status:** done — with one acceptance criterion unverified on this machine, see *Verification gap* below.

- [~] `flutter run` produces a working app on both an iOS simulator and an Android emulator — **not verified here**, see *Verification gap*
- [x] Riverpod is wired up, with at least one provider consumed by a screen and overridden in a test — proving the override path works before ticket 02 depends on it
- [x] A domain layer exists that imports no Flutter libraries, enforced by lint or a test so the boundary cannot rot silently
- [x] Minimum versions set: iOS 17.0 and Android API 26, targeting the API level Play currently requires for new apps
- [x] Four-tab bottom navigation (garden / timer / journal / settings) with minimalist line icons; tapping each tab shows a distinct placeholder screen and preserves per-tab state
- [x] Colour tokens for the full §5.1 palette, including the dark-mode background, with light and dark themes both resolving
- [x] Type ramp tokens: rounded semibold headings, regular body, and tabular monospaced digits for timer numerals — the digits token must not shift width as numbers change
- [x] Spacing and corner-radius tokens used by the placeholder screens
- [x] Static analysis passes with no warnings, and a trivial widget test runs green via the project's test command
- [x] A single documented command runs analyze + tests, ready for CI

---

## What was built

`./scripts/check.sh` — analyze + both test suites, the one command for CI. Green: `flutter analyze --fatal-infos` clean across the workspace, 41 app tests, 7 domain tests.

**Riverpod.** `clockProvider` (`lib/src/time/clock_provider.dart`) serves the domain's `Clock`. `TimerScreen` consumes it; `test/time/clock_provider_test.dart` overrides it three ways — container-level, through the real screen, and not at all — so ticket 02's state machine inherits a proven injection path.

**Domain boundary.** `packages/pomodoro_domain` is a pure-Dart workspace member with no `flutter` dependency, holding `Clock` / `SystemClock` / `FixedClock`. Enforced twice: `depend_on_referenced_packages` promoted to an analyzer **error**, plus a test that scans `lib/` and the pubspec. Both were confirmed to go red against a planted violation, not merely green on a clean tree.

**Platform minimums.** iOS 17.0 across all three Xcode configurations and in a checked-in `Podfile` (with a `post_install` pin, since `flutter_additional_ios_build_settings` only raises pods to Flutter's lower floor). Android `minSdk` 26, `targetSdk`/`compileSdk` 36 — verified in the merged manifest of a real build. `test/platform/minimum_versions_test.dart` pins all of it; `docs/platforms.md` explains it.

**Shell.** `IndexedStack` over four `NavigationDestination`s using outlined (line) icons. Per-tab state preservation is tested by the visible thing rather than the mechanism: scroll one tab, leave, come back, assert the offset and the `State` identity survived.

**Tokens.** `lib/src/design/` — `palette.dart` (the eight §5.1 hexes plus clearly-labelled derived tokens for the gaps §5.1 leaves: a light canvas, dark-mode text, error colours), `typography.dart`, `spacing.dart`, `garden_colors.dart` (soil/sky/bloom as a `ThemeExtension`, ready for ticket 14's seasonal swap), `theme.dart`. A test asserts every colour the light and dark schemes resolve traces back to a token, so the "no hardcoded colours" rule is enforced rather than merely stated.

**Tabular digits.** `GardenTypography.timerDigits` uses `FontFeature.tabularFigures()`. The test loads the real bundled TTF — widget tests otherwise render with a stand-in font whose glyphs are all the same width, which would have made the assertion pass for the wrong reason — and proves the font loaded before measuring `00:00` / `11:11` / `88:88` / `25:00` / `09:59` at equal width.

## Decisions worth knowing downstream

**Nunito is bundled and used on both platforms.** §5.1 asks for SF Pro Rounded, which exists only on iOS. One bundled rounded family keeps iOS and Android at parity and keeps first launch working offline. §5.1's handwritten face for plant names is **Caveat**, bundled as one token (`botanicalLabel`) so ticket 15 does not hardcode it. Both are confirmed present inside the built APK.

**`targetSdk = 36`, one level above what Play requires today.** Play requires API 35 for new apps as of 11 Aug 2026 and API 36 from 31 Aug 2026. Since this app ships after that date, targeting 36 now avoids taking the bump as a late release blocker. Re-check before submitting.

**`GardenColors.of` throws rather than falling back.** A missing theme extension is a wiring bug; a silent fallback would render the light palette on a dark screen. Throws in release too, for the same reason `MediaQuery.of` does.

## Verification gap

`flutter run` on a simulator and an emulator could **not** be executed on this machine:

- **iOS** — the simulator requires macOS and Xcode; this is Linux.
- **Android** — no `/dev/kvm` (the host does not expose virtualisation to this container) and no system images installed, so no emulator can start regardless of images.

What *was* verified in place of a run: `flutter build apk --debug` succeeds; the merged manifest carries `minSdkVersion="26" targetSdkVersion="36"`; the app label reads "Pomodoro Garden"; the bundled fonts are present inside the APK; and the widget tests pump the real `PomodoroGardenApp` — themes, fonts, navigation and all — rather than a test double.

**Still to do on suitable hardware:** run the app on an iOS 17 simulator and an API 26 emulator, and confirm the shell renders and navigates. The iOS side additionally needs a first `pod install` on a Mac, which will generate `Podfile.lock` against the checked-in `Podfile`.

*Per `issues/README.md`, nothing was committed — the work is left in the working tree, and no git repository was created.*
