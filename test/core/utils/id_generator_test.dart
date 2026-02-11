import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/core/utils/id_generator.dart';

void main() {
  group('IdGenerator', () {
    test('generate creates unique IDs', () {
      final id1 = IdGenerator.generate();
      final id2 = IdGenerator.generate();

      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(equals(id2)));
    });

    test('generate creates valid UUID format', () {
      final id = IdGenerator.generate();

      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      expect(id.length, equals(36));
      expect(id.contains('-'), isTrue);
    });

    test('generateShort creates shorter IDs', () {
      final shortId = IdGenerator.generateShort();

      expect(shortId, isNotEmpty);
      expect(shortId.length, lessThan(36));
    });
  });
}
