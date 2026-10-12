import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/paged.dart';
import '../../core/providers.dart';
import '../../core/utils/json.dart';

/// A published notice. For a student, `GET /notices/` returns only notices
/// that are published, unexpired, addressed to students or everyone, and
/// for the whole organization or the student's own campus.
class Notice {
  const Notice({required this.id, required this.title, required this.body, this.audience, this.campusName, this.publishedAt, this.expiresAt});

  final int id;
  final String title;
  final String body;

  /// `all`, `students`, …
  final String? audience;

  /// Null for organization-wide notices.
  final String? campusName;
  final DateTime? publishedAt;
  final DateTime? expiresAt;

  factory Notice.fromJson(Map<String, dynamic> j) => Notice(
        id: asInt(j['id']) ?? 0,
        title: asString(j['title']) ?? 'Notice',
        body: asString(j['body']) ?? '',
        audience: asString(j['audience']),
        campusName: asString(j['campus_name']),
        publishedAt: asDateTime(j['published_at']),
        expiresAt: asDateTime(j['expires_at']),
      );
}

class NoticesRepository {
  NoticesRepository(this._dio);
  final Dio _dio;

  Future<PageResult<Notice>> page(int page, {int pageSize = 20}) => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/notices/', queryParameters: {'page': page, 'page_size': pageSize});
        return PageResult.fromJson(res.data!, Notice.fromJson);
      });

  Future<Notice> get(int id) => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/notices/$id/');
        return Notice.fromJson(res.data!);
      });
}

final noticesRepositoryProvider = Provider.autoDispose((ref) => NoticesRepository(sessionDio(ref)));

final noticesProvider = AsyncNotifierProvider.autoDispose<NoticesController, PagedList<Notice>>(NoticesController.new);

class NoticesController extends AsyncNotifier<PagedList<Notice>> {
  @override
  Future<PagedList<Notice>> build() async {
    final first = await ref.watch(noticesRepositoryProvider).page(1);
    return PagedList(items: first.items, page: 1, hasMore: first.hasNext);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(noticesRepositoryProvider).page(current.page + 1);
      state = AsyncData(PagedList(items: [...current.items, ...next.items], page: current.page + 1, hasMore: next.hasNext));
    } catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false, moreError: e));
    }
  }
}

/// The newest few notices, for the dashboard.
final recentNoticesProvider = FutureProvider.autoDispose<List<Notice>>((ref) async {
  final page = await ref.watch(noticesRepositoryProvider).page(1, pageSize: 3);
  return page.items;
});

final noticeProvider = FutureProvider.autoDispose.family<Notice, int>((ref, id) => ref.watch(noticesRepositoryProvider).get(id));
