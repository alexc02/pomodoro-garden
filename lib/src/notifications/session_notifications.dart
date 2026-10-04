import 'package:pomodoro_domain/pomodoro_domain.dart';

/// The notification for a session or break ending while the app is in the
/// background: when, what it says, and its sound. A plain value so the copy
/// can be tested without a platform.
final class SessionCompletionNotice {
  const SessionCompletionNotice({
    required this.at,
    required this.title,
    required this.body,
    required this.sound,
  });

  /// Keep the tone calm: name the plant, ask for nothing, no exclamation
  /// marks or imperatives.
  factory SessionCompletionNotice.forGrowth(
    PlantGrowth? growing, {
    required DateTime at,
    required EndSound sound,
  }) {
    if (growing == null) {
      // Shouldn't happen, but shouldn't read like a bug either.
      return SessionCompletionNotice(
        at: at,
        title: 'Your session\'s done',
        body: 'Something new is growing in your garden.',
        sound: sound,
      );
    }

    return SessionCompletionNotice(
      at: at,
      title: 'Your ${growing.species.label.toLowerCase()} has bloomed',
      body: 'Your session\'s done. It\'s in your garden whenever you want to '
          'look.',
      sound: sound,
    );
  }

  /// Same tone, no plant (a break grows nothing), and no nagging to get back
  /// to work.
  factory SessionCompletionNotice.forBreak({
    required BreakKind kind,
    required DateTime at,
    required EndSound sound,
  }) {
    return SessionCompletionNotice(
      at: at,
      title: switch (kind) {
        BreakKind.short => 'Your break is over',
        BreakKind.long => 'Your long break is over',
      },
      body: 'Ready for another session when you are.',
      sound: sound,
    );
  }

  /// Absolute instant, scheduled in UTC so timezone changes don't move it.
  final DateTime at;

  final String title;
  final String body;

  /// Read from settings when the app backgrounds, since nothing of ours runs
  /// when it fires. [EndSound.none] still posts the notice, silently.
  final EndSound sound;

  @override
  bool operator ==(Object other) =>
      other is SessionCompletionNotice &&
      other.at == at &&
      other.title == title &&
      other.body == body &&
      other.sound == sound;

  @override
  int get hashCode => Object.hash(at, title, body, sound);

  @override
  String toString() =>
      'SessionCompletionNotice($title, at $at, ${sound.name})';
}

/// Scheduled local notifications. This is the only way a backgrounded session
/// gets announced; nothing runs in the background, so the notice is scheduled
/// as the app leaves the foreground.
///
/// Best-effort; nothing here may throw at a caller.
abstract interface class SessionNotifications {
  /// Safe to call repeatedly; the OS only prompts once.
  Future<bool> requestPermission();

  /// Replaces any previously scheduled completion.
  Future<void> scheduleCompletion(SessionCompletionNotice notice);

  /// Schedules the end of the auto-started break as a second notice (ADR
  /// 0022). Replaces any previous follow-up; leaves the completion alone.
  Future<void> scheduleFollowUp(SessionCompletionNotice notice);

  /// Cancels both notices and also clears delivered ones from the shade,
  /// since they're stale once the user is in the app.
  Future<void> cancelCompletion();
}
