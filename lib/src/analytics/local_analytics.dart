import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

/// [Analytics] written to a table in the app's own SQLite file. Nothing leaves
/// the device.
///
/// [record] never blocks and never throws: the write is fire-and-forget, and a
/// failed write is reported via [FlutterError.reportError] and dropped.
final class LocalAnalytics implements Analytics {
  // Positional because named params can't initialise private fields.
  const LocalAnalytics(this._log, this._clock);

  final AnalyticsEventLog _log;
  final Clock _clock;

  @override
  void record(AnalyticsEvent event) => unawaited(_write(event));

  Future<void> _write(AnalyticsEvent event) async {
    try {
      await _log.append(event, at: _clock.now());
    } catch (error, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'pip_garden',
        context: ErrorDescription('recording $event'),
      ));
    }
  }
}
