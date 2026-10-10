import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import '../time/clock_provider.dart';
import 'local_analytics.dart';

/// Where the app says what happened: the one port every call site records
/// through.
///
/// **This is the seam PRD §7.2 promises.** Every §7.1 event in the app is
/// recorded as `ref.read(analyticsProvider).record(SomeEvent(…))`, so the day a
/// real sink is wanted it is this line that changes and no call site — which is
/// the whole reason the events are instrumented now, while the features are
/// being written, rather than in a sweep later.
final analyticsProvider = Provider<Analytics>(
  (ref) => LocalAnalytics(
    ref.watch(analyticsEventLogProvider),
    ref.watch(clockProvider),
  ),
);

/// The most recent events, for the debug screen that shows them.
///
/// Auto-disposed, because it is read by one screen in one build flavour and
/// there is no reason for the app to hold a list of log rows while nobody is
/// looking at it. Read again whenever that screen is opened, which is also how
/// it refreshes.
final recentEventsProvider = FutureProvider.autoDispose<List<LoggedEvent>>(
  (ref) => ref.watch(analyticsEventLogProvider).recent(),
);
