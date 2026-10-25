# 39 — Hand-off: build, try and photograph on real devices

**What to build:** the steps that need the owner's Mac, iPhone and simulators. They can't be done on this machine. PRD v2.2 §4.4, §6.3 and §8.1.1, step 12. **Nothing here blocks the release** (PRD v2.2 §4.4): a clear failure gets fixed; anything subtler is watched after launch.

**Blocked by:** 30–38.

**Status:** not started. This is the owner's ticket; fixes found here come back into the repo as new work.

- [ ] **iOS build on the Mac:** `flutter build ios` with Xcode. The Swift (Live Activity, Dynamic Island widget, App Intent, share sheet, quiet-mode plugin) has never been compiled; expect compiler errors, and bring each one back to be fixed
- [ ] iOS app size measured in App Store Connect (thinned) against 50 MB
- [ ] **Exercise every feature** on the iPhone, the iOS Simulator and the Android emulator, using `docs/platforms.md` as the checklist. In particular:
  - live surface on both platforms (Dynamic Island compact/expanded, lock screen, Android ongoing notification)
  - completion and break-end notifications with the chosen sound, while backgrounded (ticket 34)
  - Android quiet mode, including the permission flow
  - the export share sheet
  - a 120-minute session backgrounded the whole time, ending on time
- [ ] Cold launch and garden smoothness looked at on the iPhone with a 200-plant garden; recorded in `docs/performance-record.md`
- [ ] **Store screenshots:** six, per PRD §6.3, from the iOS Simulator (iPhone 15 Pro or later, for the Dynamic Island) and the Android emulator, after tickets 35 and 36
- [ ] Ticket 24's open criteria annotated with what was measured and where
