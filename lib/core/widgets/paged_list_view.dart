import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/paged.dart';
import 'common.dart';
import 'states.dart';

/// An infinite list over a [PagedList]: loads the next page near the end,
/// with pull-to-refresh, empty and error states.
class PagedListView<T> extends StatelessWidget {
  const PagedListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.onRefresh,
    required this.onRetry,
    required this.onLoadMore,
    required this.empty,
    this.header,
  });

  final AsyncValue<PagedList<T>> value;
  final Widget Function(BuildContext, T) itemBuilder;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final Widget empty;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: AsyncValueView(
        value: value,
        onRetry: onRetry,
        data: (list) {
          if (list.items.isEmpty) return ScrollableFill(child: empty);
          final extra = (header == null ? 0 : 1) + 1;
          return NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 400 && list.hasMore && !list.loadingMore && list.moreError == null) {
                onLoadMore();
              }
              return false;
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pagePadding(context),
              itemCount: list.items.length + extra,
              itemBuilder: (context, i) {
                if (header != null) {
                  if (i == 0) return PageBody(maxWidth: 820, child: header!);
                  i -= 1;
                }
                if (i < list.items.length) {
                  return PageBody(maxWidth: 820, child: itemBuilder(context, list.items[i]));
                }
                if (list.moreError != null) {
                  return ErrorView(error: list.moreError!, onRetry: onLoadMore, compact: true);
                }
                if (list.hasMore) return const LoadingView(compact: true);
                return const SizedBox(height: 8);
              },
            ),
          );
        },
      ),
    );
  }
}
