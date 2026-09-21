import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import '../journal/journal_providers.dart';
import 'analytics_providers.dart';

/// Records `app_opened` once per launch (not per resume; it's a retention
/// metric).
///
/// `days_since_last_open` comes from the last `app_opened` in the log, so
/// after a data reset it reads as a first open. Must sit below the two gates
/// since it reads the database.
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
            // Calendar days, not hours (23:50 then 00:10 is one day).
            daysSinceLastOpen: lastOpen == null
                ? null
                : CalendarDay.of(lastOpen.toLocal()).daysUntil(today),
            streakDays:
                Streak.from(activeDays: activeDays, today: today).days,
          ));
    } catch (error, stack) {
      // Never block launch over analytics.
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('recording that the app was opened'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
