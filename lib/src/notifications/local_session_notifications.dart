import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:timezone/timezone.dart' as tz;

import '../feedback/end_sound_player.dart';
import 'session_notifications.dart';

/// Android's channel for the wind chime, and the one this app has posted on
/// since ticket 06.
///
/// Kept under its original id on purpose. It is the default sound, so it is the
/// channel almost every user already has — and a channel carries everything
/// they have decided about this app's notifications: its importance, whether it
/// vibrates, whether it may make a sound at all. Minting a new id for the sound
/// they were already on would throw all of that away on upgrade.
const String windChimeChannelId = 'session_completion';

/// The Android channel a notice announcing itself with [sound] is posted on.
///
/// **One channel per sound, and that is the platform's rule rather than a
/// design.** A notification channel's sound cannot be changed once the channel
/// exists, and deleting and recreating one to change it is worse than living
/// with six: it throws away every other decision the user made about that
/// channel, including whether it may make a sound at all, which is theirs and
/// not this app's.
///
/// The wind chime keeps [windChimeChannelId]; every other sound gets an id
/// derived from its own name, so a build that adds a seventh sound cannot
/// collide with a channel a user already has.
String completionChannelId(EndSound sound) => sound == EndSound.windChime
    ? windChimeChannelId
    : '${windChimeChannelId}_${sound.name}';

/// What the user sees this channel called in their system notification
/// settings.
///
/// **Naming these well is part of the work rather than polish.** A channel is
/// created the first time it is posted to, so somebody who tries three sounds
/// ends up with three rows here — and three rows all called "Finished sessions"
/// would be an app that had made their settings screen worse without telling
/// them why.
String completionChannelName(EndSound sound) =>
    'Finished sessions — ${sound.isSilent ? 'silent' : sound.label}';

/// The line under the name, saying what this particular channel is for.
String completionChannelDescription(EndSound sound) {
  final plays = sound.isSilent
      ? 'This one makes no sound.'
      : 'This one plays the ${sound.label.toLowerCase()}.';
  return 'Tells you when a focus session has finished and your plant has '
      'grown. $plays';
}

/// How a notice announcing itself with [sound] is dressed on each platform.
///
/// The same sound on both, so a user with a phone in each pocket hears one app
/// — but arrived at completely differently, and the asymmetry is the platform's
/// rather than this app's. iOS names a file per notification; Android names a
/// channel, and a channel's sound is fixed for its life.
///
/// **Out here rather than on [LocalSessionNotifications], because this is the
/// part of the file with decisions in it and the only part a test on a
/// workstation can reach.** Everything the class does is a call into a plugin
/// that needs a phone; everything decided about *what* to hand that plugin is
/// here, and `test/notifications/completion_details_test.dart` reads it.
NotificationDetails completionDetails(EndSound sound) {
  final resource = endSoundAndroidResource(sound);

  return NotificationDetails(
    android: AndroidNotificationDetails(
      completionChannelId(sound),
      completionChannelName(sound),
      channelDescription: completionChannelDescription(sound),
      // High so the news arrives while the phone is locked, which is the whole
      // point of it — but with no lights, no full-screen intent and nothing
      // that has to be dismissed. It is a piece of news, not an alarm. High for
      // the silent channel too: **None** turns the sound off, not the news.
      importance: Importance.high,
      priority: Priority.high,
      // Ticket 11, and the one line that keeps this app's own news audible
      // through this app's own silence. REQ-014's zen rule silences everything
      // but the categories its policy allows, and reminders is the one this
      // notice honestly belongs to: it is something the user asked to be told
      // at a time they chose. Without it, quiet mode's most obvious failure is
      // that turning it on stops the app announcing the session it silenced the
      // phone for. See `QuietModeRule.kt`, which is the other half of this.
      category: AndroidNotificationCategory.reminder,
      // Both, and not one: `sound: null` on its own means *the channel's
      // default*, which is a sound. Silence has to be asked for.
      playSound: resource != null,
      sound: resource == null
          ? null
          : RawResourceAndroidNotificationSound(resource),
      // Tapping it takes the user to the garden they have just grown something
      // for; leaving the app also gets rid of it.
      autoCancel: true,
    ),
    iOS: DarwinNotificationDetails(
      sound: endSoundIosSound(sound),
      // Null for the chosen sound would mean *the system default* here too, so
      // silence is again the absence of a presented sound. The alert itself is
      // untouched: the notice appears exactly as it would with a sound on it.
      presentSound: !sound.isSilent,
      // `timeSensitive` would let this through a Focus mode the user is
      // running, and the user running a Focus mode is exactly who this app is
      // for. Left at the default: a session that finishes while they are
      // deliberately unavailable can wait for them.
      interruptionLevel: InterruptionLevel.active,
    ),
  );
}

/// [SessionNotifications] over `flutter_local_notifications`.
///
/// The one thing worth reading twice: **this class does not run when the
/// notification fires.** It hands the operating system a message and an instant
/// and gets out of the way, which is why a session survives the app being
/// suspended, swapped out or killed while it waits. REQ-005 rules out anything
/// that would need the app to be alive at the end of a session.
///
/// Timezones never enter into it. A session's end is an absolute instant, so it
/// is scheduled against `tz.UTC` — which the `timezone` package supplies
/// without loading its database — and a phone that changes zone mid-session
/// still gets its chime at the right moment.
final class LocalSessionNotifications implements SessionNotifications {
  LocalSessionNotifications({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// The id of the one notification this app posts. Fixed rather than minted,
  /// because there is one session and so at most one notice: scheduling twice
  /// replaces rather than accumulates, and cancelling needs nothing remembered.
  static const int _completionId = 1;

  /// The break's end that follows a completion, when one is scheduled.
  static const int _followUpId = 2;

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void>? _ready;

  /// Which sounds have been copied into iOS's `Library/Sounds` this run.
  ///
  /// A memo over a filesystem check rather than a substitute for one — see
  /// [_installIosSound], which still compares what is there against the asset.
  final Set<EndSound> _installedIosSounds = <EndSound>{};

  @override
  Future<bool> requestPermission() =>
      _attempt('requesting notification permission', orElse: false, () async {
        await _initialise();

        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // Badges are not asked for: nothing in this app counts, and a red dot
          // on the icon is the kind of pressure PRD §2 is written against.
          final granted = await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true);
          return granted ?? false;
        }

        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
        // Null where there is nothing to grant: below Android 13 notifications
        // are permitted on install, and answering false there would report a
        // refusal nobody made.
        return granted ?? true;
      });

  @override
  Future<void> scheduleCompletion(SessionCompletionNotice notice) =>
      _schedule(_completionId, notice, 'the completion notification');

  @override
  Future<void> scheduleFollowUp(SessionCompletionNotice notice) =>
      _schedule(_followUpId, notice, 'the break-end notification');

  Future<void> _schedule(
    int id,
    SessionCompletionNotice notice,
    String what,
  ) =>
      _try('scheduling $what', () async {
        await _initialise();
        // Best-effort, and separately so: a sound that could not be copied out
        // of the bundle leaves iOS playing its own default, which is a notice
        // with the wrong sound on it. Letting that failure escape would make it
        // a session with no notice at all, and the notice is the news.
        await _try('installing the end sound for iOS',
            () => _installIosSound(notice.sound));

        await _plugin.zonedSchedule(
          id: id,
          title: notice.title,
          body: notice.body,
          scheduledDate: tz.TZDateTime.from(notice.at.toUtc(), tz.UTC),
          notificationDetails: completionDetails(notice.sound),
          androidScheduleMode: await _scheduleMode(),
        );
      });

  @override
  Future<void> cancelCompletion() =>
      _try('cancelling the completion notification', () async {
        await _initialise();
        // Withdraws the pending alarm *and* removes an already-delivered
        // notification from the shade, which is what makes opening the app
        // clear the news it has just made stale.
        await _plugin.cancel(id: _completionId);
        await _plugin.cancel(id: _followUpId);
      });

  /// The plugin's one-time setup, plus the iOS sound install.
  ///
  /// Memoised, because every method here begins with it — but only while it
  /// succeeds. A failed setup is forgotten rather than remembered, so a session
  /// that could not be announced because the plugin was not ready does not
  /// condemn every session after it to the same silence.
  Future<void> _initialise() async {
    final ready = _ready ??= _startUp();
    try {
      await ready;
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }

  Future<void> _startUp() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Every `request…Permission` is false on purpose: initialising must not
        // put a permission dialog in front of someone who has just opened the
        // app for the first time. The app asks at the first START instead —
        // see `SessionAnnouncer`.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  /// Exact if the platform allows it, and near enough if it does not.
  ///
  /// From Android 14, `SCHEDULE_EXACT_ALARM` is denied by default, and the app
  /// declares `USE_EXACT_ALARM` instead — see the manifest. If a device or a
  /// policy refuses anyway, an inexact alarm is still delivered, a few minutes
  /// late; a late chime is a worse experience than a punctual one and a far
  /// better one than none.
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    final exact = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.canScheduleExactNotifications();
    return (exact ?? false)
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Puts [sound] where iOS can find it.
  ///
  /// `UNNotificationSound` reads from the main bundle or from the app
  /// container's `Library/Sounds`, and a Flutter asset is in neither — it is
  /// inside `App.framework`. Copying it out keeps the sound a Flutter asset,
  /// which is what lets `scripts/make_synth_end_sounds.py` own both copies
  /// and what keeps it out of an Xcode project file that a later
  /// `flutter create --platforms` would rewrite.
  ///
  /// **One sound rather than all five, and at schedule time rather than at
  /// setup.** Most users never change the setting, and installing the four they
  /// will never hear would be three quarters of a megabyte of copying on every
  /// first launch. What is copied is what is about to be needed.
  ///
  /// **Copied when its contents differ rather than when it is missing.** The
  /// old check was "is there a file there", which is right for a released app —
  /// a rebuilt app gets a fresh container — and wrong here: re-running the
  /// placeholder script during development leaves a stale copy shadowing the
  /// new one, and a sound that will not change until the app is reinstalled is
  /// a confusing thing to debug.
  ///
  /// Compared byte for byte rather than by length, which is the cheaper check
  /// and the useless one: every placeholder has a fixed duration, so retuning a
  /// waveform produces a file of exactly the same size. Length would say
  /// "unchanged" about the one edit this check exists to notice. The cost is
  /// reading a few hundred kilobytes at most five times in the life of a run —
  /// once per sound the user actually schedules with.
  Future<void> _installIosSound(EndSound sound) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (_installedIosSounds.contains(sound)) return;

    final endSoundFile = endSoundAsset(sound);
    final endSoundName = endSoundIosSound(sound);
    // Nothing to install for the choice that is not a file.
    if (endSoundFile == null || endSoundName == null) return;

    final bytes = await rootBundle.load(endSoundFile);
    final sized = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );

    final library = await getLibraryDirectory();
    final installed = File(p.join(library.path, 'Sounds', endSoundName));
    if (!await _holds(installed, sized)) {
      await installed.parent.create(recursive: true);
      await installed.writeAsBytes(sized);
    }

    _installedIosSounds.add(sound);
  }

  /// Whether [file] already holds exactly [wanted].
  ///
  /// False for a file that is not there, and false for one that cannot be read:
  /// a copy that goes ahead when it did not need to costs a few hundred
  /// kilobytes of writing, where a copy skipped on a bad reading costs the user
  /// the wrong sound until they reinstall.
  Future<bool> _holds(File file, Uint8List wanted) async {
    if (!file.existsSync()) return false;
    if (file.lengthSync() != wanted.length) return false;

    try {
      final there = await file.readAsBytes();
      for (var index = 0; index < wanted.length; index++) {
        if (there[index] != wanted[index]) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs [action], and reports rather than throws if the platform will not.
  ///
  /// Every method on [SessionNotifications] promises this. A notification is
  /// the app's second guarantee, not its first: the session is anchored to the
  /// wall clock and is recorded correctly whether or not any of this works, so
  /// a plugin that is missing, a permission that was refused or an alarm the
  /// system will not take must not surface as an error to a user who is trying
  /// to focus.
  Future<T> _attempt<T>(
    String what,
    Future<T> Function() action, {
    required T orElse,
  }) async {
    try {
      return await action();
    } catch (error, stack) {
      _report(what, error, stack);
      return orElse;
    }
  }

  /// [_attempt] for the two methods with nothing to hand back.
  Future<void> _try(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      _report(what, error, stack);
    }
  }

  void _report(String what, Object error, StackTrace stack) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'pip_garden',
      context: ErrorDescription(what),
    ));
  }
}
