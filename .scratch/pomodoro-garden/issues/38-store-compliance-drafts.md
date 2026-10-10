# 38 — Store-compliance drafts

**What to build:** the texts both stores require before submission, drafted into `docs/store/` for the owner to host and enter. PRD v2.2 §6.1, §7.2 and §8.1.1, step 11. Found by the gap review (finding C5): nobody owned these, and Google Play will not accept the app without them.

**Blocked by:** nothing. Do it after 37, so the permission justifications describe the final app.

**Status:** done. The drafts are written; hosting the policy and entering the answers are the owner's (ticket 39 and `docs/store/README.md`'s checklist).

- [x] `docs/store/privacy-policy.md`: no account, no server, no network, no third-party sharing, analytics stored on the device only and never sent; what each permission is for; how to delete everything (uninstall, or Settings → Reset garden). Placeholders for the **policy URL** and a **contact email**, both the owner's to fill in
- [x] `docs/store/play-data-safety.md`: every answer on Play's Data Safety form ("no data collected, no data shared"), plus the justification for each Android permission (`POST_NOTIFICATIONS`, `ACCESS_NOTIFICATION_POLICY`, foreground-service special use, exact alarms) taken from the manifest's own comments
- [x] `docs/store/iarc-questionnaire.md`: answers for the content-rating questionnaire (no violence, no user-generated content, no purchases, no ads, no data sharing), targeting **Everyone** / 4+
- [x] `docs/store/app-store-privacy.md`: App Store Connect's App Privacy answers, "Data Not Collected"
- [x] Every claim checked against the code and the manifests, not copied from the PRD. If the code says otherwise, it's a finding, not a draft
- [x] A short checklist at the top of `docs/store/` of what the owner has to do and in which console

## What was built

| File | What |
|---|---|
| `docs/store/README.md` | What is ready, and the owner's checklist for both consoles |
| `docs/store/privacy-policy.md` | The policy: no account, no server, no network, on-device storage only, what each permission is for, how to delete everything. Placeholders: date, developer name, contact email |
| `docs/store/play-data-safety.md` | "No data collected, no data shared", with the reasons |
| `docs/store/play-declarations.md` | **Not in the ticket, and needed:** Play's exact-alarm and special-use foreground-service declarations, with suggested answers and the emulator video Play may ask for |
| `docs/store/iarc-questionnaire.md` | IARC and App Store age-rating answers (Everyone / 4+), and the target-audience choice (recommended 13+, to stay out of the Families policy) |
| `docs/store/app-store-privacy.md` | "Data Not Collected", export compliance, and App Review notes covering the Live Activity and the audio background mode |

**Checked against the build, not the PRD:** the permission list comes from the release
build's **merged** manifest, which differs from the source one. Plugins add
`POST_NOTIFICATIONS`, `VIBRATE` and **`ACCESS_NETWORK_STATE`** (from the audio library).
The last is disclosed in the policy and the Data safety notes. It grants no internet access,
and the release build has no `INTERNET` permission. No networking code exists in `lib/`.

**One correction made while checking:** the app asks for notification permission when the
first session *starts*, not before it.

**Verification gap:** the forms themselves (field names change between console versions);
the owner enters them. The IARC category's exact label is not known from here.
