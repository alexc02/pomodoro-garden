import 'package:flutter/material.dart';

/// REQ-036's double confirmation: the two questions between a user and an empty
/// garden.
///
/// A file of its own, beside `showThemePicker`, because what
/// is in it is a *flow* rather than a control — the settings screen owns the
/// row and the words under it, and this owns the two things the row has to ask
/// before anything is cleared.
///
/// **Two dialogs and not one with a checkbox in it.** The requirement is a
/// double confirmation, and the reason it is two is that the second one has to
/// be answered on its own: a user who has already tapped past the first is a
/// user who has decided, and the only remaining job is to make the finality
/// unmistakable to somebody who decided too fast. A checkbox is something a
/// finger already on its way to a button skips over.
///
/// **The second one says REQ-036's sentence, in REQ-036's words**, and says it
/// as the whole of the question rather than as a line under a summary. It is
/// the last thing the user reads.

/// What the tests reach for.
abstract final class ResetGardenKeys {
  /// The row in settings that opens the first confirmation.
  static const Key control = Key('settings.resetGarden');

  /// What stands in its place while a timer is in flight.
  static const Key heldBack = Key('settings.resetGardenHeldBack');

  /// The snack bar that says a reset happened, or failed to.
  static const Key outcome = Key('reset.outcome');

  /// The first question, and the second.
  static const Key firstConfirmation = Key('reset.firstConfirmation');
  static const Key secondConfirmation = Key('reset.secondConfirmation');
}

/// Asks both of REQ-036's questions, and answers true only if the user said yes
/// to both.
///
/// False for every other route out — dismissing either dialog, tapping either
/// way back, or the screen going away underneath. A confirmation flow that
/// treated "the sheet closed" as consent would be one bad frame away from
/// clearing somebody's garden.
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

  // Not `if (decided != true) return false` folded into the line below: the
  // second dialog needs a context, and the first `await` is where the screen
  // can have gone away — see the guard.
  if (decided != true) return false;
  if (!context.mounted) return false;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: ResetGardenKeys.secondConfirmation,
      title: const Text('This can\'t be undone'),
      // REQ-036's sentence, as the whole of the second question. Said in the
      // requirement's own words rather than paraphrased, because this is the
      // line the user is being asked to agree to.
      content: const Text(
        'This will clear all plants and stats. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep my garden'),
        ),
        // Coloured as the destruction it is, and second, where a confirming
        // button goes on both platforms. The colour is the theme's error role
        // rather than a red of this file's own, so it stays legible in dark
        // mode and under a high-contrast setting.
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
