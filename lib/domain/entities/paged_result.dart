import 'package:equatable/equatable.dart';

/// One page of a larger, server-side collection.
final class PagedResult<T> extends Equatable {
  /// Creates a page.
  const PagedResult({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  /// An empty first page.
  const PagedResult.empty()
    : items = const [],
      page = 1,
      pageSize = 0,
      total = 0;

  /// Items on this page.
  final List<T> items;

  /// One-based page number.
  final int page;

  /// Requested page size.
  final int pageSize;

  /// Total number of items across all pages.
  final int total;

  /// Whether more pages exist after this one.
  bool get hasMore => page * pageSize < total;

  @override
  List<Object?> get props => <Object?>[items, page, pageSize, total];
}
