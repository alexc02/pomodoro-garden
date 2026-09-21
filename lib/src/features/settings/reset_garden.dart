import 'package:flutter/material.dart';

abstract final class ResetGardenKeys {
  /// The settings row that opens the first confirmation.
  static const Key control = Key('settings.resetGarden');

  /// Shown instead while a timer is running.
  static const Key heldBack = Key('settings.resetGardenHeldBack');

  /// Snack bar reporting success or failure.
  static const Key outcome = Key('reset.outcome');

  static const Key firstConfirmation = Key('reset.firstConfirmation');
  static const Key secondConfirmation = Key('reset.secondConfirmation');
}

/// Two separate dialogs (not one with a checkbox, which is easy to tap past).
/// True only if both are confirmed; any other way out is false.
Future<bool> confirmGardenReset(BuildContext context) async {
  final decided = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: ResetGardenKeys.firstConfirmation,
      title: const Text('Reset your garden?'),
      content: const Text(
        'Every plant you\'ve grown, and every session and stat behind them, '
        'will be cleared.\n\nYour settings stay: your lengths, your theme and '
        'your sounds.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my garden'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );

  // The screen may be gone after the first await.
  if (decided != true) return false;
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: ResetGardenKeys.secondConfirmation,
      title: const Text('This can\'t be undone'),
      content: const Text(
        'This will clear all plants and stats. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my garden'),
        ),
        // Theme error colour so it holds up in dark mode and high contrast.
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Reset my garden'),
        ),
      ],
    ),
  );

  return confirmed ?? false;
}
