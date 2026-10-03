/// Removes secrets and personal data from anything the app logs.
///
/// Applied by every logger sink, so tokens, passwords, authorization headers
/// and personal details never reach the console or a crash reporter.
class LogRedactor {
  /// Creates a redactor.
  const LogRedactor();

  /// Replacement shown instead of a sensitive value.
  static const String mask = '***';

  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'passwd',
    'authorization',
    'proxyauthorization',
    'cookie',
    'setcookie',
    'secret',
    'apikey',
    'email',
    'phone',
  };

  static const List<String> _sensitiveSuffixes = <String>[
    'token',
    'password',
    'secret',
  ];

  static final RegExp _bearer = RegExp(
    r'bearer\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );

  static final RegExp _keyValue = RegExp(
    r'''(["']?(?:password|passwd|authorization|secret|api[_-]?key|email|phone|[A-Za-z_]*token)["']?\s*[:=]\s*)("[^"]*"|'[^']*'|[^\s,&}]+)''',
    caseSensitive: false,
  );

  /// Whether a map key names a sensitive value.
  bool isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp('[_-]'), '');
    if (_sensitiveKeys.contains(normalized)) return true;
    return _sensitiveSuffixes.any(normalized.endsWith);
  }

  /// Returns [value] with sensitive entries masked, recursing into maps and
  /// lists. Other values are returned unchanged.
  Object? redactValue(Object? value) {
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          '${entry.key}': isSensitiveKey('${entry.key}')
              ? mask
              : redactValue(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(redactValue).toList();
    }
    if (value is String) return redactText(value);
    return value;
  }

  /// Masks bearer tokens and `key: value` pairs for sensitive keys inside
  /// free-form [text].
  String redactText(String text) {
    final withoutBearer = text.replaceAll(_bearer, 'Bearer $mask');
    return withoutBearer.replaceAllMapped(
      _keyValue,
      (match) => '${match.group(1)}$mask',
    );
  }
}
