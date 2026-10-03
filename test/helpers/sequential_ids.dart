import 'package:flutter_enterprise_architecture/core/utils/id_generator.dart';

/// Deterministic identifiers: `id-1`, `id-2`, ...
class SequentialIds implements IdGenerator {
  int _count = 0;

  @override
  String next() => 'id-${++_count}';
}
