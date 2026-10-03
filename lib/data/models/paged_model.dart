import '../../domain/entities/paged_result.dart';
import 'json_reader.dart';

/// API page envelope: `{items, page, pageSize, total}`.
class PagedModel<T> {
  /// Creates a model.
  const PagedModel({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  /// Parses a page, decoding each item with [itemFromJson].
  factory PagedModel.fromJson(
    Object? raw,
    T Function(Object? item) itemFromJson,
  ) {
    final json = asJson(raw);
    final items = json['items'];
    if (items is! List<Object?>) {
      throw const FormatException('Expected a list at "items"');
    }
    return PagedModel<T>(
      items: items.map(itemFromJson).toList(),
      page: json.integer('page'),
      pageSize: json.integer('pageSize'),
      total: json.integer('total'),
    );
  }

  /// Decoded items.
  final List<T> items;

  /// One-based page number.
  final int page;

  /// Page size.
  final int pageSize;

  /// Total item count.
  final int total;

  /// Converts to a domain page, mapping each item with [convert].
  PagedResult<E> toEntity<E>(E Function(T item) convert) => PagedResult<E>(
    items: items.map(convert).toList(),
    page: page,
    pageSize: pageSize,
    total: total,
  );
}
