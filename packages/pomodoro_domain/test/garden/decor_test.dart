import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

final DateTime _placed = DateTime.utc(2026, 8, 11, 9, 41);

Decor _item(
  DecorKind kind, {
  GardenPlot plot = const GardenPlot(0, 0),
  String id = 'decor-1',
}) =>
    Decor(id: id, kind: kind, plot: plot, placedAt: _placed);

void main() {
  group('the four kinds', () {
    test('are the objects, and no others', () {
      expect(DecorKind.values, [
        DecorKind.lantern,
        DecorKind.bench,
        DecorKind.birdbath,
        DecorKind.pond,
      ]);
    });

    test('each has its own label and blurb', () {
      for (final kind in DecorKind.values) {
        expect(kind.label, isNotEmpty);
        expect(kind.blurb, isNotEmpty);
      }
      expect(
        DecorKind.values.map((kind) => kind.label).toSet(),
        hasLength(DecorKind.values.length),
      );
    });

    test('are read back by name', () {
      expect(DecorKind.named('bench'), DecorKind.bench);
      expect(DecorKind.named('pond'), DecorKind.pond);
    });

    test('a kind this build has never heard of is nothing, not a lantern', () {
      // From a newer build. Null, so we skip it instead of drawing the wrong
      // thing.
      expect(DecorKind.named('gazebo'), isNull);
      expect(DecorKind.named(''), isNull);
    });
  });

  group('an item', () {
    test('moves without becoming a different item', () {
      // Id, kind and placedAt all survive the move.
      final bench = _item(DecorKind.bench, plot: const GardenPlot(1, 0));
      final moved = bench.movedTo(const GardenPlot(-2, 3));

      expect(moved.plot, const GardenPlot(-2, 3));
      expect(moved.id, bench.id);
      expect(moved.kind, DecorKind.bench);
      expect(moved.placedAt, bench.placedAt);
    });

    test('compares by value, so two reads of a row are one item', () {
      expect(_item(DecorKind.pond), _item(DecorKind.pond));
      expect(_item(DecorKind.pond).hashCode, _item(DecorKind.pond).hashCode);
      expect(_item(DecorKind.pond), isNot(_item(DecorKind.lantern)));
      expect(
        _item(DecorKind.pond),
        isNot(_item(DecorKind.pond, plot: const GardenPlot(3, 3))),
      );
    });
  });
}
