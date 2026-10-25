# App Store Connect: App Privacy and other questions

App Store Connect → your app → **App Privacy**.

## Data collection

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |

Result on the product page: **"Data Not Collected"**.

Apple's "collect" means transmitting data off the device in a way that lets you or a third
party access it beyond what's needed to serve the request in real time. Everything this app
stores stays in its on-device database, and the app makes no network requests. Checked
2026-10-11: no networking code in `lib/`, no analytics, ads or crash-reporting SDK in
`pubspec.yaml`.

## Privacy policy URL

Required by App Store Connect too. Use the same hosted page as Play. **[TO DO: the URL]**

## Other questions the submission will ask

| Question | Answer | Note |
|---|---|---|
| Export compliance: does the app use encryption? | **No** (only encryption built into iOS) | `ITSAppUsesNonExemptEncryption` is already `NO` in `Info.plist`, so this isn't asked per upload |
| Advertising identifier (IDFA) | **No** | No tracking; no ATT prompt needed |
| Sign-in required for review? | **No** | No account exists |
| Uses Live Activities | **Yes** | Lock screen and Dynamic Island timer; mention it in review notes so the reviewer knows to start a session |
| Background mode: audio | **Yes** | Ambient sounds keep playing with the screen locked. Say so in review notes: the reviewer may ask why `UIBackgroundModes` contains `audio` |
| Photo library access | **Add only** | `NSPhotoLibraryAddUsageDescription`: saving a garden picture |

**Suggested App Review notes:**

> Pip Garden is a free focus timer with no account and no network access. To see its
> main features: tap Start on the garden screen; the session's countdown appears in a Live
> Activity on the lock screen and in the Dynamic Island. Choose an ambient sound on the timer
> screen; it keeps playing with the screen locked, which is why the app declares the audio
> background mode. Settings → Session length can be set to 5 minutes for a quicker review.
