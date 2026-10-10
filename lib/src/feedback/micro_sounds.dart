/// PRD §9.2's four UI micro-sounds, and the one place their files are named.
///
/// **Cited across two sections, because the PRD splits them.** §9.2 counts the
/// four and names them; §5.4 specs only two — the soil settle and the growth
/// shimmer get a context, a source and a format there, and the button tap and
/// the unlock get a word each in §9.2 and nothing else. Which section a value
/// below cites is which section actually says anything about it.
///
/// **A closed set of four, from §9.2, and not a sound on everything.** The app
/// has a great many buttons and PRD §2 sells one that does not chatter — *no
/// notifications screaming for attention*, *calm*. So a fifth micro-sound is a
/// new requirement rather than a natural extension of this one, and the whole
/// of what these four answer to is written down beside each value below.
///
/// Unlike `EndSound` this is **not a setting and not in the domain**: nobody
/// chooses between these, there is no row to store, and nothing outside
/// `lib/src/feedback/` has an opinion about which one plays. A user who wants
/// them quieter turns their phone down — see [MicroSounds] for why there is no
/// switch.
enum MicroSound {
  /// §5.4's "soil settle", at §5.4's moment: seed planted.
  ///
  /// Which §5.3 puts at the *end* of the 0.8-second drop rather than the start
  /// of it — the seed is planted when it lands, and the sound goes where
  /// `PlantPainter`'s particle burst is already drawn.
  soilSettle('soil_settle'),

  /// §5.4's "growth shimmer", at a stage transition — the same moment REQ-037's
  /// subtler haptic fires.
  ///
  /// Not behind REQ-037's switch, though it fires beside it: that switch is
  /// about whether the app talks to the user's *hand*, and a user who turned
  /// off the buzzing did not thereby ask for silence.
  growthShimmer('growth_shimmer'),

  /// §9.2's "button tap", on the five actions that start or end something:
  /// START, Pause, Resume, a confirmed Cancel, and accepting a break.
  ///
  /// The list is the requirement, because "button tap" on its own cannot be
  /// finished. What is deliberately *not* on it: every settings control, the
  /// tabs, the theme and ambience pickers, dismissing a card — and **skipping a
  /// break**, which is the one omission worth naming. `SessionMachine.endBreak`
  /// already puts a skipped break in `idle` rather than `breakOver` precisely so
  /// that walking out of a break makes no sound; a tap sound on the one control
  /// a break has would take that back.
  buttonTap('button_tap'),

  /// §9.2's "unlock", when a milestone award is celebrated.
  ///
  /// §9.2 gives the word no context and there are two candidates. REQ-018's plot
  /// unlock is **not** it: that is a floor derived from a session count
  /// (ADR 0006), nothing on screen announces it, and a sound for something the
  /// user cannot see is a sound they cannot explain. REQ-021's award has a
  /// moment built for it — `MilestoneKeeper` holds the card back until the timer
  /// has come to rest so that it reads as its own event — and that moment has
  /// room in it for a sound.
  unlock('unlock');

  const MicroSound(this.stem);

  /// The file this sound is bundled under, without its extension.
  final String stem;

  /// Where the sound is bundled.
  ///
  /// **AAC, and unlike the end sounds there is nothing to argue about.** These
  /// never reach a notification, so `UNNotificationSound`'s refusal to read
  /// anything but PCM never comes up, and §5.4 asks for AAC. All four together
  /// are a few tens of kilobytes — see `docs/ambience.md` for the budget they
  /// share with the beds.
  String get asset => 'assets/audio/micro/$stem.m4a';
}

/// The app's answer to something the user is looking at: §9.2's four
/// micro-sounds, played.
///
/// **One port with four values rather than four ports.** Four fire-and-forget
/// one-shots at four unrelated call sites would otherwise be four providers and
/// four fakes, and `test/support/app_harness.dart` would grow a parameter per
/// sound. One port takes which sound to play, and one fake records the
/// sequence.
///
/// **There is no switch, and that is a decision rather than an omission.**
/// REQ-037 gives haptics a toggle and REQ-031 gives the end sound a **None**;
/// the PRD says nothing about silencing these, and inventing a fifth control for
/// four sounds nobody has complained about yet would be the settings screen
/// growing a row to describe an implementation. What silences them is the phone:
/// they play on `AudioUse.chimeOnly`, which is `ambient` on iOS — the category
/// the ring switch mutes — and the notification usage on Android, which the
/// ringer mode governs the same way. A phone set to silent stays silent, and
/// that is the property `test/feedback/micro_sounds_test.dart` holds.
///
/// Folding them under `EndSound.none` was the other honest option and was not
/// taken: that value is scoped to what a *completed session* sounds like, on
/// screen and on the notification, and quietly widening it would make the
/// settings row's own label a lie about what it controls.
///
/// **None of the four ever plays with the app behind something else.** They are
/// responses to something on screen, and there is nothing to respond to when
/// nobody is looking. Three of the four get that for free — a tap needs a
/// finger, and the two animation-driven ones need frames — and the fourth,
/// `MicroSound.unlock`, is guarded by `MilestoneKeeper`, whose card can rise on
/// a timer while the app is away.
abstract interface class MicroSounds {
  /// Plays [sound], from the beginning, without waiting for it to finish.
  ///
  /// Returns when the sound has *started*. Every caller is in the middle of
  /// doing something else — landing a seed, opening a sheet, starting a
  /// session — and none of them has any business waiting on a speaker.
  Future<void> play(MicroSound sound);
}
