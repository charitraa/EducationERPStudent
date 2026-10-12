import '../utils/json.dart';

/// One page of the backend's `DefaultPagination` envelope:
/// `{count, total_pages, page, page_size, next, previous, results}`.
class PageResult<T> {
  const PageResult({required this.items, required this.count, required this.hasNext});
  final List<T> items;
  final int count;
  final bool hasNext;

  factory PageResult.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) parse) => PageResult(
        items: asMapList(j['results']).map(parse).toList(),
        count: asInt(j['count']) ?? 0,
        hasNext: j['next'] != null,
      );
}

/// Accumulated pages for an infinite list.
class PagedList<T> {
  const PagedList({required this.items, required this.page, required this.hasMore, this.loadingMore = false, this.moreError});

  final List<T> items;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final Object? moreError;

  PagedList<T> copyWith({List<T>? items, int? page, bool? hasMore, bool? loadingMore, Object? moreError}) => PagedList(
        items: items ?? this.items,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        moreError: moreError,
      );
}
