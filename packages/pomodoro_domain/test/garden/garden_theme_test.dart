import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

/// REQ-034's three biomes, and the one rule that is not about colour: which one
/// a stored name that means nothing here reads as.
void main() {
  group('the three themes', () {
    test('are REQ-034 zen, tropical and wildflower', () {
      expect(
        GardenTheme.values,
        [GardenTheme.zen, GardenTheme.tropical, GardenTheme.wildflower],
      );
    });

    test('are every one of them the user\'s, and the default is Zen', () {
      // The app is free and there is nothing to own, so there is no second list
      // of themes anywhere: what the picker offers is `values`. This test is
      // what would fail if a locked one ever came back without the decision
      // being made again — see `docs/adr/0021-…`.
      expect(GardenTheme.fallback, GardenTheme.zen);
    });

    test('every theme says what it is, in words of its own', () {
      for (final theme in GardenTheme.values) {
        expect(theme.label, isNotEmpty, reason: '${theme.name} has no label');
        expect(theme.blurb, isNotEmpty, reason: '${theme.name} has no blurb');
      }

      // Distinct, because the picker shows all three at once and two themes
      // described identically would be a picker that could not be used.
      expect(
        GardenTheme.values.map((theme) => theme.label).toSet(),
        hasLength(GardenTheme.values.length),
      );
      expect(
        GardenTheme.values.map((theme) => theme.blurb).toSet(),
        hasLength(GardenTheme.values.length),
      );
    });
  });

  group('reading a stored name', () {
    test('gives back the theme that wrote it', () {
      for (final theme in GardenTheme.values) {
        expect(GardenTheme.named(theme.name), theme);
      }
    });

    test('falls back to the default for a name this build has never heard '
        'of', () {
      // A row written by a later build that offered a fourth theme. Read as
      // best it can be read rather than thrown over.
      expect(GardenTheme.named('rock_pool'), GardenTheme.fallback);
      expect(GardenTheme.named(''), GardenTheme.fallback);
      expect(GardenTheme.named('Zen Garden'), GardenTheme.fallback);
    });

    test('a theme the user chose survives a round trip through a row', () {
      // What the garden is drawn in is what was stored, with nothing in
      // between deciding they may not have it.
      for (final theme in GardenTheme.values) {
        expect(GardenTheme.named(theme.name), theme);
      }
    });
  });
}
