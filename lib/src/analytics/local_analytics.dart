import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

/// [Analytics] over the device's own log, and the only implementation the app
/// ships.
///
/// It is the one place the port's two promises are kept:
///
/// **Recording never blocks the caller.** [record] stamps the event with the
/// clock and hands the write to the event loop. A tap on START is on screen
/// before anything has touched a disk, which is the point: the timer is what the
/// user asked for and the log is what the app happens to keep.
///
/// **Recording never fails a user action.** A write that throws is reported the
/// way every other failed write in this app is — loudly, to
/// [FlutterError.reportError] — and then let go. There is nothing for a call
/// site to do about an analytics event that did not land, and a session that
/// refused to start because its log did would be the tail wagging the dog.
///
/// **And nothing here goes anywhere.** PRD §7.2: no SDK, no network, no account.
/// The whole of the sink is a table in the same SQLite file the sessions are in.
final class LocalAnalytics implements Analytics {
  /// Both collaborators are positional for the reason `SessionMachine`'s are:
  /// the analyzer will not let a named parameter initialise a private field, and
  /// neither of these has any business being public.
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
        library: 'pomodoro_garden',
        context: ErrorDescription('recording $event'),
      ));
    }
  }
}
