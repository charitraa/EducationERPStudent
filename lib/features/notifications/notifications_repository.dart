import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/paged.dart';
import '../../core/providers.dart';
import '../../core/utils/json.dart';

/// An in-app notification. `GET /notifications/` only ever returns the
/// signed-in user's own.
class AppNotification {
  const AppNotification({required this.id, required this.eventType, required this.title, this.body, this.isRead = false, this.createdAt});

  final int id;

  /// e.g. `examinations.result_published`, `attendance.marked_absent`.
  final String eventType;
  final String title;
  final String? body;
  final bool isRead;
  final DateTime? createdAt;

  AppNotification read() =>
      AppNotification(id: id, eventType: eventType, title: title, body: body, isRead: true, createdAt: createdAt);

  /// The screen that shows what this notification is about, if any.
  String? get route {
    final area = eventType.split('.').first;
    return switch (area) {
      'examinations' => '/results',
      'attendance' => '/attendance',
      'finance' => '/fees',
      'notices' => '/notices',
      'timetable' => '/timetable',
      _ => null,
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: asInt(j['id']) ?? 0,
        eventType: asString(j['event_type']) ?? '',
        title: asString(j['title']) ?? 'Notification',
        body: asString(j['body']),
        isRead: asBool(j['is_read']),
        createdAt: asDateTime(j['created_at']),
      );
}

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<PageResult<AppNotification>> page(int page) => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/notifications/', queryParameters: {'page': page, 'page_size': 25});
        return PageResult.fromJson(res.data!, AppNotification.fromJson);
      });

  Future<int> unreadCount() => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/notifications/unread-count/');
        return asInt(res.data?['unread']) ?? 0;
      });

  Future<void> markRead(int id) => guard(() => _dio.post<void>('/notifications/$id/mark-read/'));

  Future<void> markAllRead() => guard(() => _dio.post<void>('/notifications/mark-all-read/'));
}

final notificationsRepositoryProvider = Provider.autoDispose((ref) => NotificationsRepository(sessionDio(ref)));

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) => ref.watch(notificationsRepositoryProvider).unreadCount());

final notificationsProvider =
    AsyncNotifierProvider.autoDispose<NotificationsController, PagedList<AppNotification>>(NotificationsController.new);

class NotificationsController extends AsyncNotifier<PagedList<AppNotification>> {
  NotificationsRepository get _repo => ref.read(notificationsRepositoryProvider);

  @override
  Future<PagedList<AppNotification>> build() async {
    final first = await ref.watch(notificationsRepositoryProvider).page(1);
    return PagedList(items: first.items, page: 1, hasMore: first.hasNext);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _repo.page(current.page + 1);
      state = AsyncData(PagedList(items: [...current.items, ...next.items], page: current.page + 1, hasMore: next.hasNext));
    } catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false, moreError: e));
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    await _repo.markRead(n.id);
    _update((items) => [for (final i in items) i.id == n.id ? i.read() : i]);
    ref.invalidate(unreadCountProvider);
  }

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    _update((items) => [for (final i in items) i.read()]);
    ref.invalidate(unreadCountProvider);
  }

  void _update(List<AppNotification> Function(List<AppNotification>) change) {
    final current = state.value;
    if (current != null) state = AsyncData(current.copyWith(items: change(current.items)));
  }
}
