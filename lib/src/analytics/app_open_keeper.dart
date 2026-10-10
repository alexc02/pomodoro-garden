import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import '../journal/journal_providers.dart';
import 'analytics_providers.dart';

/// Records §7.1's `app_opened`, once per launch.
///
/// **Per launch, not per return to the foreground.** What §7.1 is measuring is
/// retention — how many days between one use and the next — and a user who
/// glances at their phone six times during a session has opened the app once.
/// Coming back from the background is `SessionLifecycle`'s business and it does
/// not go through here.
///
/// **The log is what remembers the last open.** `days_since_last_open` is the
/// gap to the most recent `app_opened` in the log, so nothing had to be added to
/// settings for it and the two facts cannot drift apart. A cleared log — ticket
/// 22's reset — reads as a first open, and that is the honest answer rather than
/// a gap: the log is the only record of when the app was last opened, and a
/// reset takes it. The streak beside it reads as zero for the same reason, from
/// the same reset, which is what makes the pair consistent — this is a device
/// that has been asked to forget the user's garden, and the event says so.
///
/// **It is a keeper**, in the sense the others in `app.dart` are: it puts
/// nothing on screen, it wires one thing to another, and it must live below the
/// two gates, because both halves of what it records are read from the database.
class AppOpenKeeper extends ConsumerStatefulWidget {
  const AppOpenKeeper({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppOpenKeeper> createState() => _AppOpenKeeperState();
}

class _AppOpenKeeperState extends ConsumerState<AppOpenKeeper> {
  @override
  void initState() {
    super.initState();
    // Off the end of this build rather than in it: two queries and a write, none
    // of which the first frame is waiting for.
    unawaited(_recordTheOpen());
  }

  Future<void> _recordTheOpen() async {
    try {
      final log = ref.read(analyticsEventLogProvider);
      final today = ref.read(todayProvider);

      final (lastOpen, activeDays) = await (
        log.lastRecordedAt(AnalyticsEventName.appOpened),
        ref.read(journalRepositoryProvider).daysWithSessions(),
      ).wait;
      if (!mounted) return;

      ref.read(analyticsProvider).record(AppOpened(
            // Calendar days apart rather than hours: "opened yesterday" is a
            // fact about two dates, and a user who opens the app at 23:50 and
            // again at 00:10 has come back the next day rather than a third of
            // an hour later. The same rule the journal counts by — see ADR 0012.
            daysSinceLastOpen: lastOpen == null
                ? null
                : CalendarDay.of(lastOpen.toLocal()).daysUntil(today),
            streakDays:
                Streak.from(activeDays: activeDays, today: today).days,
          ));
    } catch (error, stack) {
      // Reported rather than rethrown, on the same reasoning every other read at
      // launch uses: a log line that could not be worked out is not a reason for
      // an app not to open.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pomodoro_garden',
        context: ErrorDescription('recording that the app was opened'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
