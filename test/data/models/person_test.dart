import 'package:flutter_test/flutter_test.dart';
import 'package:spendsheet/data/models/person.dart';

void main() {
  group('Person', () {
    final now = DateTime.now();

    test('creates person correctly', () {
      final person = Person(
        id: 'p-1',
        name: 'Alice',
        phone: '555-1234',
        note: 'College friend',
        createdAt: now,
        updatedAt: now,
      );

      expect(person.id, equals('p-1'));
      expect(person.name, equals('Alice'));
      expect(person.phone, equals('555-1234'));
      expect(person.note, equals('College friend'));
      expect(person.netBalance, equals(0));
      expect(person.isDeleted, isFalse);
    });

    test('creates person with optional fields null', () {
      final person = Person(
        id: 'p-2',
        name: 'Bob',
        createdAt: now,
        updatedAt: now,
      );

      expect(person.phone, isNull);
      expect(person.note, isNull);
      expect(person.deletedAt, isNull);
    });

    test('isDeleted returns true when deletedAt is set', () {
      final person = Person(
        id: 'p-1',
        name: 'Alice',
        createdAt: now,
        updatedAt: now,
        deletedAt: now,
      );

      expect(person.isDeleted, isTrue);
    });

    test('copyWithDelete sets deletedAt', () {
      final person = Person(
        id: 'p-1',
        name: 'Alice',
        createdAt: now,
        updatedAt: now,
      );

      final deleted = person.copyWithDelete();

      expect(deleted.isDeleted, isTrue);
      expect(deleted.deletedAt, isNotNull);
      expect(person.isDeleted, isFalse);
    });

    test('toJson and fromJson roundtrip', () {
      final person = Person(
        id: 'p-1',
        name: 'Alice',
        phone: '555-1234',
        note: 'Test note',
        createdAt: now,
        updatedAt: now,
      );

      final json = person.toJson();
      final restored = Person.fromJson(json);

      expect(restored.id, equals(person.id));
      expect(restored.name, equals(person.name));
      expect(restored.phone, equals(person.phone));
      expect(restored.note, equals(person.note));
    });

    test('copyWith creates new instance', () {
      final original = Person(
        id: 'p-1',
        name: 'Alice',
        createdAt: now,
        updatedAt: now,
      );

      final updated = original.copyWith(name: 'Alice Smith', netBalance: 100);

      expect(updated.name, equals('Alice Smith'));
      expect(updated.netBalance, equals(100));
      expect(original.name, equals('Alice'));
      expect(original.netBalance, equals(0));
    });
  });
}
