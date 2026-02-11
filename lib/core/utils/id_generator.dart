import 'package:uuid/uuid.dart';

class IdGenerator {
  IdGenerator._();

  static const Uuid _uuid = Uuid();

  static String generate() => _uuid.v4();

  static String generateShort() => _uuid.v4().substring(0, 8);

  static String generateTimeBased() => _uuid.v1();

  static bool isValid(String id) {
    return Uuid.isValidUUID(fromString: id);
  }
}
