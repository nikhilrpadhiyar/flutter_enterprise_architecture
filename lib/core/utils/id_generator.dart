import 'dart:math';

/// Produces unique identifiers for idempotency keys and local records.
abstract interface class IdGenerator {
  /// Returns a new identifier.
  String next();
}

/// Generates random 128-bit identifiers rendered as hexadecimal.
class RandomIdGenerator implements IdGenerator {
  /// Creates a generator. Pass a seeded [random] in tests.
  RandomIdGenerator({Random? random}) : _random = random ?? Random.secure();

  static const int _byteCount = 16;
  static const int _byteRange = 256;
  static const int _hexRadix = 16;

  final Random _random;

  @override
  String next() {
    final buffer = StringBuffer();
    for (var i = 0; i < _byteCount; i++) {
      buffer.write(
        _random.nextInt(_byteRange).toRadixString(_hexRadix).padLeft(2, '0'),
      );
    }
    return buffer.toString();
  }
}
