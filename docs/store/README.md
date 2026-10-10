# Store submission: what's ready and what you do

Drafted by ticket 38 (PRD v2.2 §6.1, §7.2). Every claim in these files was checked against
the code and the release build's merged `AndroidManifest.xml`, not copied from the PRD.

## Files

| File | For |
|---|---|
| `privacy-policy.md` | The privacy policy both stores require. Fill in the placeholders and host it |
| `play-data-safety.md` | Google Play's Data safety form |
| `play-declarations.md` | Google Play's exact-alarm and foreground-service declarations. **Needed and easy to miss** |
| `iarc-questionnaire.md` | Content rating (Play) and age rating (App Store), plus the target-audience choice |
| `app-store-privacy.md` | App Store Connect's App Privacy, export compliance and review notes |
| `feature-graphic.png` | Play's 1024 × 500 feature graphic (`tool/generate_store_art.dart`) |

## Your checklist

**Before either store**
- [ ] Fill in the placeholders in `privacy-policy.md`: date, your name or studio, contact email
- [ ] Host it at a public URL (your website, or GitHub Pages) and note the URL in
      `play-data-safety.md` and `app-store-privacy.md`
- [ ] Decide the Play target audience (`iarc-questionnaire.md` recommends 13 and over)
- [ ] Take the six screenshots (PRD §6.3) from the iOS Simulator and the Android emulator

**Google Play Console**
- [ ] App content → Privacy policy: the URL
- [ ] App content → Ads: No
- [ ] App content → Data safety: as `play-data-safety.md`
- [ ] App content → Content rating: as `iarc-questionnaire.md`
- [ ] App content → Target audience and content
- [ ] App content → **Exact alarm permission** and **Foreground service permissions**: as
      `play-declarations.md` (a short emulator video may be requested)
- [ ] Store listing: name, short and full description (PRD §6.1–6.2), feature graphic,
      screenshots, app icon (from `android/…/mipmap-xxxhdpi`, or the 512 px export)

**App Store Connect**
- [ ] App Privacy: as `app-store-privacy.md`
- [ ] Age rating: as `iarc-questionnaire.md`
- [ ] Privacy policy URL
- [ ] Optional: add `ITSAppUsesNonExemptEncryption = NO` to `ios/Runner/Info.plist`
- [ ] Review notes: as `app-store-privacy.md`
- [ ] Screenshots, description, keywords (PRD §6.1–6.2)
