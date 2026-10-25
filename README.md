# Pip Garden

A focus timer that grows a garden. Finish a session, get a plant.

Flutter app for iOS and Android. The core logic (sessions, growth, garden layout,
journal) is plain Dart in `packages/pomodoro_domain`, with no Flutter dependency.

## Requirements

- Flutter 3.44.8 / Dart 3.12.2 or newer
- iOS: macOS with Xcode and CocoaPods
- Android: Android SDK platform 36, JDK 17+ (I use 21)
- Python 3 and ffmpeg, only if you want to regenerate the sounds

```sh
flutter pub get
flutter run
```

Minimums are iOS 17.0 and Android API 26. See `docs/platforms.md`.

## Checks

```sh
./scripts/check.sh
```

Runs `flutter analyze --fatal-infos`, the app tests, then the domain package tests
(`dart test` in `packages/pomodoro_domain`). The lints in `analysis_options.yaml` report
as infos, hence `--fatal-infos`.

## Generated files

Everything in `assets/`, the app icons and the Play feature graphic come from scripts in
this repo. The output is checked in, so you don't need to run any of them to build.
They're deterministic, so a re-run only changes files if the recipe changed.

```sh
flutter test tool/generate_sprite_art.dart   # plants, decor, role masks, manifest
flutter test tool/generate_icons.dart        # app icons
flutter test tool/generate_store_art.dart    # Play feature graphic
flutter test tool/render_art_preview.dart    # preview renders (not committed)

python3 scripts/make_synth_beds.py           # rain, ocean, white noise
python3 scripts/make_synth_end_sounds.py     # end-of-session chimes (needs ffmpeg)
python3 scripts/make_synth_micro_sounds.py   # UI sounds (needs ffmpeg)
python3 scripts/make_recorded_sounds.py      # café, forest, birdsong from CC0 recordings
```

More detail in `docs/art-pipeline.md` and `docs/ambience.md`.

The Drift code in `lib/src/data/database.g.dart` is checked in too. After changing a
table:

```sh
dart run build_runner build
```

Store screenshots: `tool/screenshots/capture.sh` drives the iOS Simulator through each
shot using the seeded entry point in `tool/screenshots/main.dart`, and `compose.py` adds
the frames and captions.

## Versioning

`version: 1.0.0+1` in `pubspec.yaml` (name+build). Bump the build number for every store
upload, or pass `--build-name` / `--build-number` to `flutter build`.

## Android

```sh
flutter build appbundle --release             # build/app/outputs/bundle/release/app-release.aab
flutter build apk --release --split-per-abi   # per-ABI APKs for sideloading
```

Application ID `com.pipgarden.pip_garden`. Gradle 9.1.0, AGP 9.0.1, Kotlin 2.3.20.
`android/gradle.properties` gives the Gradle daemon 8 GB; lower it if your machine
doesn't have that. Core library desugaring is on (`flutter_local_notifications` needs it).

**Release signing isn't set up yet.** `android/app/build.gradle.kts` still signs release
builds with the debug key, and Play will reject that. To fix:

1. Create an upload key and keep it outside the repo:
   ```sh
   keytool -genkey -v -keystore ~/pip-garden-upload.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```
2. Add `android/key.properties` (already git-ignored):
   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/Users/<you>/pip-garden-upload.jks
   ```
3. Load it in `android/app/build.gradle.kts`:
   ```kotlin
   import java.util.Properties

   val keystoreProperties = Properties().apply {
       val file = rootProject.file("key.properties")
       if (file.exists()) file.inputStream().use { load(it) }
   }

   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String?
               keyPassword = keystoreProperties["keyPassword"] as String?
               storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
               storePassword = keystoreProperties["storePassword"] as String?
           }
       }
       buildTypes {
           release {
               signingConfig = signingConfigs.getByName("release")
           }
       }
   }
   ```
4. Enrol in Play App Signing on the first upload.

Play Console also needs the exact-alarm and special-use foreground service declarations,
the Data safety form and the content rating. Drafts are in `docs/store/`.

## iOS

Open `ios/Runner.xcworkspace` (not the `.xcodeproj`).

| Target | Bundle ID | |
|---|---|---|
| `Runner` | `com.pipgarden.pipGarden` | the app, the Shortcuts intent and native plugins |
| `LiveSessionWidget` | `com.pipgarden.pipGarden.LiveSessionWidget` | Live Activity / Dynamic Island |

No entitlements file. Live Activities are switched on with `NSSupportsLiveActivities`,
and all notifications are local. `Info.plist` also declares the `audio` background mode,
the `pipgarden://` URL scheme and the photo-library add permission.

```sh
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Upload with Transporter, or from Xcode's Organizer. A physical device needs Developer
Mode turned on.

The app currently allows iPad and landscape (`TARGETED_DEVICE_FAMILY = "1,2"`). That
means App Store Connect also wants iPad screenshots (in `docs/store/screenshots/ipad-13/`).

## Debug-only settings

Debug builds have extra sections at the bottom of Settings:

- **Onboarding**: show the first-launch flow again
- **Event log**: the local analytics events, newest first. They're stored in SQLite
  (capped at 500 rows) and never leave the device. `test/analytics/nothing_leaves_the_device_test.dart`
  checks for that.
- **Season** and **Milestone effects**: force a season, preview the glow and shimmer

## Project layout

```
lib/src/
  app.dart, shell/       MaterialApp, tab shell
  design/                colours, type, spacing, themes, paper textures
  data/                  Drift database and repositories
  session/               session controller and app lifecycle handling
  garden/                garden rendering: atlas, sprites, hit-testing, sway, seasons
  features/              screens: garden, timer, journal, settings, onboarding
  ambience/, audio/, feedback/   ambient loops, end sounds, haptics
  live/, quiet/, notifications/  Live Activity / foreground service, DND, notifications
  export/                garden image export and share sheet
  analytics/             local event log
packages/pomodoro_domain/  pure Dart domain logic and its tests
tool/                    art, icon and screenshot generators
scripts/                 check script, sound generators
docs/                    platform and asset notes, a few ADRs, store paperwork
```

`docs/adr/` has short notes on the decisions that aren't obvious from the code, mostly
around how sessions are timed and stored.
