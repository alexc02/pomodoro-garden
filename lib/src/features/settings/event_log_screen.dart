import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pomodoro_domain/pomodoro_domain.dart';

import '../../analytics/analytics_providers.dart';
import '../../design/garden_colors.dart';
import '../../design/spacing.dart';

/// The handles a test reaches for on this screen.
abstract final class EventLogKeys {
  /// The list itself, so a test can say "the log" rather than "the second
  /// scrollable".
  static const Key log = Key('eventLog.list');

  /// The line saying there is nothing in it.
  static const Key empty = Key('eventLog.empty');
}

/// PRD §7.2's "debug-only viewer": every event the app has recorded, on this
/// device, newest first.
///
/// **The whole of what analytics looks like from outside the code.** There is no
/// dashboard, no console and no account — the events are rows in the same SQLite
/// file the sessions are in, and this is the only screen that reads them. It
/// exists so that "the events are being recorded with the right parameters" is a
/// thing somebody can check by looking rather than by reading `grep` output.
///
/// Reached from the settings screen's **Event log (debug)** section, which is
/// compiled out of release builds by the `kDebugMode` guard at its only call
/// site.
class EventLogScreen extends ConsumerWidget {
  const EventLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(recentEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event log (debug)'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(recentEventsProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Read the log again',
          ),
        ],
      ),
      body: SafeArea(
        child: events.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _Message('The log could not be read: $error'),
          data: (recorded) => recorded.isEmpty
              ? const _Message(
                  key: EventLogKeys.empty,
                  'Nothing recorded yet. Start a session, look at your garden '
                  'or change a setting, and come back.',
                )
              : ListView.separated(
                  key: EventLogKeys.log,
                  padding: Spacing.screenPadding,
                  itemCount: recorded.length + 1,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) => index == recorded.length
                      ? _Footer(shown: recorded.length)
                      : _Event(recorded[index]),
                ),
        ),
      ),
    );
  }
}

/// One event: what it was called, when it happened, and what it carried.
class _Event extends StatelessWidget {
  const _Event(this.event);

  final LoggedEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondary = GardenColors.of(context).textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(event.name, style: theme.textTheme.titleMedium),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                // Local, because the reader is standing in front of the device
                // that wrote it. Seconds included: two events of a session can
                // land in the same minute.
                event.at.toLocal().toString().split('.').first,
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ],
          ),
          if (event.parameters.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            for (final entry in event.parameters.entries)
              Text(
                '${entry.key}: ${entry.value}',
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
          ],
        ],
      ),
    );
  }
}

/// What the log is, said at the bottom of it rather than at the top: the reader
/// came here for the events.
class _Footer extends StatelessWidget {
  const _Footer({required this.shown});

  final int shown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md),
      child: Text(
        '$shown events, of the ${AnalyticsEventLog.maximumEvents} this device '
        'keeps. Older ones are dropped as new ones arrive, and none of this '
        'has ever left the device.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: GardenColors.of(context).textSecondary),
      ),
    );
  }
}

/// A sentence in the middle of an otherwise empty screen.
class _Message extends StatelessWidget {
  const _Message(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Spacing.screenPadding,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
