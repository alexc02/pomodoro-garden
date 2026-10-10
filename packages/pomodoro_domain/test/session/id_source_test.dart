import 'package:pomodoro_domain/pomodoro_domain.dart';
import 'package:test/test.dart';

void main() {
  group('RandomIdSource', () {
    test('produces version 4 UUIDs', () {
      final id = RandomIdSource().newId();

      expect(
        id,
        matches(RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        )),
        reason: 'the version nibble is 4 and the variant nibble is 8-b',
      );
    });

    test('does not repeat itself', () {
      final source = RandomIdSource();
      final ids = {for (var i = 0; i < 5000; i++) source.newId()};

      expect(ids, hasLength(5000));
    });
  });

  group('SequentialIdSource', () {
    test('counts from one', () {
      final source = SequentialIdSource();

      expect([source.newId(), source.newId(), source.newId()], ['1', '2', '3']);
    });
  });
}
