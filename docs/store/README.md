# Store submission

Answers for the store forms, checked against the code and the release build's merged
`AndroidManifest.xml`.

## Files

| File | For |
|---|---|
| `privacy-policy.md` | The privacy policy both stores require. Fill in the placeholders and host it |
| `play-data-safety.md` | Google Play's Data safety form |
| `play-declarations.md` | Google Play's exact-alarm and foreground-service declarations (easy to miss) |
| `iarc-questionnaire.md` | Content rating (Play) and age rating (App Store), plus the target-audience choice |
| `app-store-privacy.md` | App Store Connect's App Privacy, export compliance and review notes |
| `feature-graphic.png` | Play's 1024 × 500 feature graphic (`tool/generate_store_art.dart`) |
| `screenshots/` | App Store screenshots, captioned: `iphone-6.3` (1206 × 2622, required), `iphone-6.9` (1320 × 2868, optional), `ipad-13` (2064 × 2752, required) |

## Checklist

**Before either store**
- [ ] Fill in the placeholders in `privacy-policy.md`: date, your name or studio, contact email
- [ ] Host it at a public URL (your website, or GitHub Pages) and note the URL in
      `play-data-safety.md` and `app-store-privacy.md`
- [ ] Decide the Play target audience (`iarc-questionnaire.md` recommends 13 and over)
- [x] iOS screenshots: `screenshots/` (see below)
- [ ] Android screenshots from the emulator

**Google Play Console**
- [ ] App content → Privacy policy: the URL
- [ ] App content → Ads: No
- [ ] App content → Data safety: as `play-data-safety.md`
- [ ] App content → Content rating: as `iarc-questionnaire.md`
- [ ] App content → Target audience and content
- [ ] App content → **Exact alarm permission** and **Foreground service permissions**: as
      `play-declarations.md` (a short emulator video may be requested)
- [ ] Store listing: name, short and full description, feature graphic,
      screenshots, app icon (from `android/…/mipmap-xxxhdpi`, or the 512 px export)

**App Store Connect**
- [ ] App Privacy: as `app-store-privacy.md`
- [ ] Age rating: as `iarc-questionnaire.md`
- [ ] Privacy policy URL
- [ ] Review notes: as `app-store-privacy.md`
- [ ] Screenshots, description, keywords

## Building the iOS upload

There are no registered devices on the account, so archive unsigned and let the export sign with the
distribution certificate (an App Store profile needs no device):

```
flutter build ipa --release --no-codesign
xcodebuild -exportArchive -archivePath build/ios/archive/Runner.xcarchive \
  -exportPath build/ios/ipa -exportOptionsPlist ios/ExportOptions.plist -allowProvisioningUpdates
```

Upload `build/ios/ipa/Pip Garden.ipa` with Transporter. Bump the build number after `+` in
`pubspec.yaml` for every upload.

## Regenerating the App Store screenshots

```
tool/screenshots/capture.sh          # raw captures from the iOS Simulator
python3 tool/screenshots/compose.py  # captioned store images (needs Pillow)
```

`capture.sh` launches the app through `tool/screenshots/main.dart`, which seeds an 80-session
garden in memory, so your own data on the simulator is never touched. Shot 3 shows the garden timer bar
instead of the Dynamic Island, because the simulator can't capture an expanded Live Activity.
Which set goes in which App Store Connect slot:

| Folder | Slot | |
|---|---|---|
| `iphone-6.3` | iPhone, Dynamic Island (medium), 1206 × 2622 | required |
| `iphone-6.9` | iPhone, Dynamic Island (large), 1320 × 2868 | optional, falls back to medium |
| `ipad-13` | iPad 13", 2064 × 2752 | required |
