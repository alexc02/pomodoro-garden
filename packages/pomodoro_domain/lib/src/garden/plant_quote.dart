import 'stable_choice.dart';

/// REQ-020's gentle line about growth or patience, and the set they come from.
///
/// Copy rather than logic, and here rather than on a screen for one reason: the
/// line a plant says is decided by the same rule its species was, and that rule
/// lives in this package. A card that picked its own quote would pick a
/// different one every time it opened.
///
/// The lines are the app's own rather than quotations. An attributed quote is a
/// small licensing question and a large tonal one — a plant's card is the user
/// being told something about their own afternoon, not being handed a maxim by
/// somebody famous.
abstract final class PlantQuotes {
  /// Every line a plant can say.
  ///
  /// Added to freely: nothing stores a quote, so a later version with more of
  /// them re-picks for every plant and no user loses anything they were
  /// promised. Removing one, or reordering the list, changes what an existing
  /// plant says — which is a thing to do deliberately, not by accident.
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

  /// The line the plant [seed] identifies says.
  ///
  /// Seeded from the plant rather than rolled for, the same way its species is
  /// — see [stableChoice]. Pass the plant's id: it is the one thing a plant has
  /// that is never null and never changes, where a session id is absent on
  /// ticket 13's milestone plants.
  static String forPlant(String seed) => stableChoice(all, seed);
}
