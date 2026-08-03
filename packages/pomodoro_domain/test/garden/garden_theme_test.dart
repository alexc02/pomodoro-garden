import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('the three themes', () {
    test('are zen, tropical and wildflower', () {
      expect(
        GardenTheme.values,
        [GardenTheme.zen, GardenTheme.tropical, GardenTheme.wildflower],
      );
    });

    test('are every one of them the user\'s, and the default is Zen', () {
      // All free (ADR 0005): the picker offers `values`.
      expect(GardenTheme.fallback, GardenTheme.zen);
    });

    test('every theme says what it is, in words of its own', () {
      for (final theme in GardenTheme.values) {
        expect(theme.label, isNotEmpty, reason: '${theme.name} has no label');
        expect(theme.blurb, isNotEmpty, reason: '${theme.name} has no blurb');
      }

      // The picker shows all three side by side.
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
      // e.g. a row from a newer build with a fourth theme.
      expect(GardenTheme.named('rock_pool'), GardenTheme.fallback);
      expect(GardenTheme.named(''), GardenTheme.fallback);
      expect(GardenTheme.named('Zen Garden'), GardenTheme.fallback);
    });

    test('a theme the user chose survives a round trip through a row', () {
      for (final theme in GardenTheme.values) {
        expect(GardenTheme.named(theme.name), theme);
      }
    });
  });
}
