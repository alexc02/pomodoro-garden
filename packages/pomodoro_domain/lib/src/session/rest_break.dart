import '../settings/garden_settings.dart';

/// Which of the two rests a break is.
///
/// Not two features and not two timers — the same break, run for a different
/// length, at a position in the cycle the user chose with "long break after".
enum BreakKind {
  /// The ordinary rest between one focus session and the next.
  short,

  /// The longer rest the cycle earns, after [GardenSettings.longBreakAfter]
  /// focus sessions.
  long,
}

/// The break a user is being offered: which kind it is, and how long it runs.
///
/// A value rather than two arguments because the two are one decision — how
/// long a break runs is decided *by* which kind it is — and because both the
/// screen offering the break and the controller starting it have to reach the
/// same answer. They reach it by asking here rather than by each restating the
/// rule.
final class BreakOffer {
  const BreakOffer({required this.kind, required this.length});

  /// The break earned at [cyclePosition], under [settings].
  ///
  /// The whole of the long-break rule, in one comparison: a user who has
  /// completed as many focus sessions as their "long break after" says is owed
  /// the long one. Greater-than-or-equal rather than equal, because a user who
  /// skipped the long break they were offered and did another session is still
  /// owed it — the cycle does not quietly forget a break by overshooting it.
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

  /// How long a break started from this offer would run.
  final Duration length;

  /// Offers compare by value: two readings of the same cycle position under the
  /// same settings are the same offer, and nothing showing one should repaint
  /// between them.
  @override
  bool operator ==(Object other) =>
      other is BreakOffer && other.kind == kind && other.length == length;

  @override
  int get hashCode => Object.hash(kind, length);

  @override
  String toString() => 'BreakOffer(${kind.name}, $length)';
}

/// One stretch of rest between focus sessions.
///
/// Deliberately thinner than `FocusSession`, and every difference is a rule
/// from ticket 09:
///
/// **It has no outcome and no id.** A break earns nothing — no plant, no row,
/// nothing counted — so there is nothing to write down about how it went and
/// nothing that would later need to be told apart from another break. A break
/// that was skipped and a break that ran its course leave the same trace, which
/// is none.
///
/// **It is never stored.** It lives in memory on the machine that is running
/// it, so a break cannot survive the app being killed — which is the same thing
/// as saying that the app being killed during a break costs the user nothing.
/// Backgrounding is a different matter, and a break survives it for the same
/// reason a session does: the anchor and the wall clock are all it takes to
/// know where a break is.
///
/// **It cannot be paused.** A rest that has to be held is a rest with something
/// happening in it.
final class Break {
  const Break({
    required this.startedAt,
    required this.plannedDuration,
    required this.kind,
  });

  /// The anchor: the UTC instant the break began. Everything about how far
  /// along a break is comes from here and the clock, exactly as it does for a
  /// session.
  final DateTime startedAt;

  /// How long the break was meant to run, fixed at the instant it started.
  final Duration plannedDuration;

  final BreakKind kind;

  /// The instant this break runs out.
  DateTime get dueAt => startedAt.add(plannedDuration);

  @override
  String toString() => 'Break(${kind.name}, started $startedAt, '
      'planned $plannedDuration)';
}
