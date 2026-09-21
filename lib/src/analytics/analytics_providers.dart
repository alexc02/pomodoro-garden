import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../data/database_providers.dart';
import '../time/clock_provider.dart';
import 'local_analytics.dart';

/// Every analytics event goes through here. Swapping in a real sink means
/// changing this provider, not the call sites.
final analyticsProvider = Provider<Analytics>(
  (ref) => LocalAnalytics(
    ref.watch(analyticsEventLogProvider),
    ref.watch(clockProvider),
  ),
);

/// Recent events for the debug screen. Auto-disposed, so it re-reads each
/// time the screen opens.
final recentEventsProvider = FutureProvider.autoDispose<List<LoggedEvent>>(
  (ref) => ref.watch(analyticsEventLogProvider).recent(),
);
