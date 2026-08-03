import '../settings/garden_settings.dart';

/// Short or long break. Same break, different length.
enum BreakKind {
  short,

  /// After [GardenSettings.longBreakAfter] focus sessions.
  long,
}

/// The break on offer: its kind and length. Shared by the screen and the
/// controller so they agree.
final class BreakOffer {
  const BreakOffer({required this.kind, required this.length});

  /// Uses `>=` so a skipped long break is still owed after another session.
  factory BreakOffer.at(int cyclePosition, {required GardenSettings settings}) {
    final kind = cyclePosition >= settings.longBreakAfter
        ? BreakKind.long
        : BreakKind.short;

    return BreakOffer(
      kind: kind,
      length: switch (kind) {
        BreakKind.short => settings.breakLength,
        BreakKind.long => settings.longBreakLength,
      },
    );
  }

  final BreakKind kind;

  final Duration length;

  @override
  bool operator ==(Object other) =>
      other is BreakOffer && other.kind == kind && other.length == length;

  @override
  int get hashCode => Object.hash(kind, length);

  @override
  String toString() => 'BreakOffer(${kind.name}, $length)';
}

/// A rest between focus sessions. Simpler than `FocusSession`: no id, no
/// outcome, never stored (killing the app mid-break just drops it), and it
/// can't be paused. Survives backgrounding because it's anchored like a
/// session.
final class Break {
  const Break({
    required this.startedAt,
    required this.plannedDuration,
    required this.kind,
  });

  /// UTC start. Progress is computed from this and the clock.
  final DateTime startedAt;

  /// Fixed when the break starts.
  final Duration plannedDuration;

  final BreakKind kind;

  DateTime get dueAt => startedAt.add(plannedDuration);

  @override
  String toString() => 'Break(${kind.name}, started $startedAt, '
      'planned $plannedDuration)';
}
