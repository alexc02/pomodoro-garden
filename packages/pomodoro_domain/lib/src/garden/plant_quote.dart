import 'stable_choice.dart';

/// Short lines shown on a plant's card. Picked deterministically per plant so
/// the card doesn't change each time it opens.
abstract final class PlantQuotes {
  /// Safe to append. Removing or reordering changes what existing plants say.
  static const List<String> all = [
    'Nothing in a garden hurries, and nothing is late.',
    'This grew because you sat still long enough for it to.',
    'Every green thing here was once a quiet afternoon.',
    'Roots go down before anything goes up.',
    'The work you cannot see is the work that holds.',
    'A garden is patience, kept somewhere you can look at it.',
    'Growth is mostly waiting, done on purpose.',
    'Small things, repeated, become the shape of a place.',
    'You did not make this grow. You made room for it.',
    'What is planted keeps growing after you look away.',
    'Seasons do the slow part; you did the sitting.',
    'Beginnings are seeds. This one was finished.',
    'The soil remembers every hour you gave it.',
    'Nothing here was rushed, and nothing here was wasted.',
  ];

  /// Pass the plant id, not the session id (milestone plants have none).
  static String forPlant(String seed) => stableChoice(all, seed);
}
