/// A decoded JSON object.
typedef Json = Map<String, Object?>;

/// Casts a decoded JSON value to an object, or throws [FormatException].
Json asJson(Object? raw) {
  if (raw is Map<String, Object?>) return raw;
  throw FormatException('Expected a JSON object but got ${raw.runtimeType}');
}

/// Finds the enum value in [values] whose name equals [raw].
T parseEnum<T extends Enum>(List<T> values, String raw) {
  for (final value in values) {
    if (value.name == raw) return value;
  }
  throw FormatException('Unknown ${T.toString()} value "$raw"');
}

/// Typed reads from a JSON object. Wrong or missing values throw a
/// [FormatException], which the networking layer reports as a decoding error.
extension JsonReader on Json {
  /// Reads a required string.
  String string(String key) {
    final value = this[key];
    if (value is String) return value;
    throw FormatException('Expected a string at "$key"');
  }

  /// Reads an optional string.
  String? stringOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Expected a string at "$key"');
  }

  /// Reads a required integer.
  int integer(String key) {
    final value = this[key];
    if (value is int) return value;
    throw FormatException('Expected an integer at "$key"');
  }

  /// Reads a required ISO 8601 timestamp.
  DateTime dateTime(String key) => DateTime.parse(string(key));

  /// Reads an optional ISO 8601 timestamp.
  DateTime? dateTimeOrNull(String key) {
    final value = stringOrNull(key);
    return value == null ? null : DateTime.parse(value);
  }

  /// Reads an optional nested object.
  Json? objectOrNull(String key) {
    final value = this[key];
    return value == null ? null : asJson(value);
  }

  /// Reads a list of objects, treating a missing key as an empty list.
  List<Json> objects(String key) {
    final value = this[key];
    if (value == null) return const <Json>[];
    if (value is! List<Object?>) {
      throw FormatException('Expected a list at "$key"');
    }
    return value.map(asJson).toList();
  }
}
