# Google Play: Data safety form

Play Console → your app → **Policy and programs → App content → Data safety**.
Checked against the code and the release build's merged `AndroidManifest.xml` on
2026-10-11.

## Data collection and security

| Question | Answer | Why it's true |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No** | Nothing leaves the device. The release build has no `INTERNET` permission, there is no networking code in `lib/`, and no analytics, ads or crash-reporting SDK is in `pubspec.yaml` |
| Is all of the user data collected by your app encrypted in transit? | *Not asked when the answer above is No* | |
| Do you provide a way for users to request that their data be deleted? | *Not asked when the answer above is No* | (If asked: data is on-device only; Settings → Reset garden, or uninstall) |

Play's definition of "collect" is transmitting data off the device. Data that stays on the
device, like this app's database and local event log, is **not** collection.

With "No", the store listing shows **"No data collected"** and **"No data shared with third
parties"**.

## Things that might make a reviewer ask

- **`ACCESS_NETWORK_STATE`** is in the merged manifest, added by the audio library. It can
  only check whether a network exists; it grants no internet access. Without `INTERNET` the
  app cannot send anything.
- **The garden export** uses the system share sheet at the user's request. Data the user
  chooses to share through another app is not collection by this app.

## Privacy policy URL

Play requires one even when nothing is collected. Host `docs/store/privacy-policy.md` (with
its placeholders filled in) at a public URL and enter it under **App content → Privacy
policy**. **[TO DO: the URL]**
