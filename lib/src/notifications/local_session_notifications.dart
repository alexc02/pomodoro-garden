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

/// The wind chime channel. Keeps the original id so existing users don't lose
/// their per-channel settings on upgrade.
const String windChimeChannelId = 'session_completion';

/// One Android channel per sound, because a channel's sound is fixed once
/// created (and recreating it would wipe the user's channel settings).
String completionChannelId(EndSound sound) => sound == EndSound.windChime
    ? windChimeChannelId
    : '${windChimeChannelId}_${sound.name}';

/// Shown in system notification settings. Each needs a distinct name since a
/// user who tries several sounds ends up with several channels.
String completionChannelName(EndSound sound) =>
    'Finished sessions — ${sound.isSilent ? 'silent' : sound.label}';

String completionChannelDescription(EndSound sound) {
  final plays = sound.isSilent
      ? 'This one makes no sound.'
      : 'This one plays the ${sound.label.toLowerCase()}.';
  return 'Tells you when a focus session has finished and your plant has '
      'grown. $plays';
}

/// Platform details for a notice with [sound]. iOS names a file per
/// notification; Android picks the sound via the channel.
///
/// Top-level so `test/notifications/completion_details_test.dart` can check it
/// without a device.
NotificationDetails completionDetails(EndSound sound) {
  final resource = endSoundAndroidResource(sound);

  return NotificationDetails(
    android: AndroidNotificationDetails(
      completionChannelId(sound),
      completionChannelName(sound),
      channelDescription: completionChannelDescription(sound),
      // High so it shows on the lock screen, but no full-screen intent or
      // lights. Also high for the silent channel.
      importance: Importance.high,
      priority: Priority.high,
      // Our zen rule lets reminders through; without this, quiet mode would
      // block our own completion notice. See `QuietModeRule.kt`.
      category: AndroidNotificationCategory.reminder,
      // Need both: `sound: null` alone means the channel default.
      playSound: resource != null,
      sound: resource == null
          ? null
          : RawResourceAndroidNotificationSound(resource),
      autoCancel: true,
    ),
    iOS: DarwinNotificationDetails(
      sound: endSoundIosSound(sound),
      // A null sound means the system default here too.
      presentSound: !sound.isSilent,
      // Not `timeSensitive`: shouldn't break through the user's Focus.
      interruptionLevel: InterruptionLevel.active,
    ),
  );
}

/// [SessionNotifications] over `flutter_local_notifications`. The OS delivers
/// the notice; nothing here runs when it fires.
///
/// Scheduled against `tz.UTC` (available without loading the tz database), so
/// timezone changes mid-session don't matter.
final class LocalSessionNotifications implements SessionNotifications {
  LocalSessionNotifications({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Fixed ids, so rescheduling replaces and cancel needs no bookkeeping.
  static const int _completionId = 1;

  static const int _followUpId = 2;

  final FlutterLocalNotificationsPlugin _plugin;

  Future<void>? _ready;

  /// Sounds already checked/copied to iOS `Library/Sounds` this run.
  final Set<EndSound> _installedIosSounds = <EndSound>{};

  @override
  Future<bool> requestPermission() =>
      _attempt('requesting notification permission', orElse: false, () async {
        await _initialise();

        if (defaultTargetPlatform == TargetPlatform.iOS) {
          // No badges: nothing to count.
          final granted = await _plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, sound: true);
          return granted ?? false;
        }

        final granted = await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        // Null below Android 13, where no permission is needed.
        return granted ?? true;
      });

  /// Tail of the schedule/cancel queue. See [_inOrder].
  Future<void> _last = Future<void>.value();

  /// Runs [operation] after every earlier schedule or cancel has finished.
  ///
  /// Scheduling awaits more steps than cancelling (sound install, schedule
  /// mode), so without this a cancel issued on a quick return could reach the
  /// OS first and the stale schedule would land after it and fire.
  Future<void> _inOrder(Future<void> Function() operation) {
    final next = _last.then((_) => operation());
    // [_try] never throws, but a broken link must not stall the queue.
    _last = next.catchError((Object _) {});
    return next;
  }

  @override
  Future<void> scheduleCompletion(SessionCompletionNotice notice) => _inOrder(
    () => _schedule(_completionId, notice, 'the completion notification'),
  );

  @override
  Future<void> scheduleFollowUp(SessionCompletionNotice notice) => _inOrder(
    () => _schedule(_followUpId, notice, 'the break-end notification'),
  );

  Future<void> _schedule(int id, SessionCompletionNotice notice, String what) =>
      _try('scheduling $what', () async {
        await _initialise();
        // Separate try: a failed copy means the default sound, not no notice.
        await _try(
          'installing the end sound for iOS',
          () => _installIosSound(notice.sound),
        );

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
  Future<void> cancelCompletion() => _inOrder(
    () => _try('cancelling the completion notification', () async {
      await _initialise();
      // Also removes already-delivered ones from the shade.
      await _plugin.cancel(id: _completionId);
      await _plugin.cancel(id: _followUpId);
    }),
  );

  /// Memoised plugin setup. Cleared on failure so the next call retries.
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
        // No prompt at init; `SessionAnnouncer` asks at the first START.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
  }

  /// Exact if allowed, else inexact (a few minutes late beats nothing).
  /// Android 14 denies `SCHEDULE_EXACT_ALARM` by default, so the manifest
  /// declares `USE_EXACT_ALARM`.
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return AndroidScheduleMode.exactAllowWhileIdle;
    }

    final exact = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.canScheduleExactNotifications();
    return (exact ?? false)
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Copies [sound] to `Library/Sounds`, where `UNNotificationSound` can see
  /// it (Flutter assets live inside `App.framework`). See [endSoundIosSound].
  ///
  /// Only the sound being scheduled, not all of them. Rewritten whenever the
  /// bytes differ, not just when missing, so regenerated placeholder sounds
  /// show up during development. Byte compare because regenerated files keep
  /// the same length.
  Future<void> _installIosSound(EndSound sound) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (_installedIosSounds.contains(sound)) return;

    final endSoundFile = endSoundAsset(sound);
    final endSoundName = endSoundIosSound(sound);
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

  /// False if missing or unreadable; an extra copy is cheap.
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

  /// Reports instead of throwing and returns [orElse].
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

  Future<void> _try(String what, Future<void> Function() action) async {
    try {
      await action();
    } catch (error, stack) {
      _report(what, error, stack);
    }
  }

  void _report(String what, Object error, StackTrace stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription(what),
      ),
    );
  }
}
