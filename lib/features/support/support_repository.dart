import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/paged.dart';
import '../../core/providers.dart';
import '../../core/utils/json.dart';

/// A support request. Students see only tickets they raised.
class Ticket {
  const Ticket({required this.id, required this.subject, required this.description, required this.status, this.assignedToName, this.createdAt, this.resolvedAt});

  final int id;
  final String subject;
  final String description;

  /// `open`, `in_progress`, `resolved`, `closed`.
  final String status;
  final String? assignedToName;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  bool get isClosed => status == 'resolved' || status == 'closed';

  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        id: asInt(j['id']) ?? 0,
        subject: asString(j['subject']) ?? '',
        description: asString(j['description']) ?? '',
        status: asString(j['status']) ?? 'open',
        assignedToName: asString(j['assigned_to_name']),
        createdAt: asDateTime(j['created_at']),
        resolvedAt: asDateTime(j['resolved_at']),
      );
}

class TicketComment {
  const TicketComment({required this.id, required this.body, this.authorName, this.authorId, this.createdAt});
  final int id;
  final String body;
  final String? authorName;
  final int? authorId;
  final DateTime? createdAt;

  factory TicketComment.fromJson(Map<String, dynamic> j) => TicketComment(
        id: asInt(j['id']) ?? 0,
        body: asString(j['body']) ?? '',
        authorName: asString(j['author_name']),
        authorId: asInt(j['author']),
        createdAt: asDateTime(j['created_at']),
      );
}

class SupportRepository {
  SupportRepository(this._dio);
  final Dio _dio;

  Future<PageResult<Ticket>> page(int page) => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/support/tickets/', queryParameters: {'page': page});
        return PageResult.fromJson(res.data!, Ticket.fromJson);
      });

  Future<Ticket> get(int id) => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/support/tickets/$id/');
        return Ticket.fromJson(res.data!);
      });

  Future<Ticket> create({required String subject, required String description}) => guard(() async {
        final res = await _dio.post<Map<String, dynamic>>('/support/tickets/',
            data: {'subject': subject.trim(), 'description': description.trim()});
        return Ticket.fromJson(res.data!);
      });

  Future<List<TicketComment>> comments(int id) => guard(() async {
        final res = await _dio.get<List<dynamic>>('/support/tickets/$id/comments/');
        return asMapList(res.data).map(TicketComment.fromJson).toList();
      });

  Future<TicketComment> addComment(int id, String body) => guard(() async {
        final res = await _dio.post<Map<String, dynamic>>('/support/tickets/$id/comments/', data: {'body': body.trim()});
        return TicketComment.fromJson(res.data!);
      });
}

final supportRepositoryProvider = Provider.autoDispose((ref) => SupportRepository(sessionDio(ref)));

final ticketsProvider = AsyncNotifierProvider.autoDispose<TicketsController, PagedList<Ticket>>(TicketsController.new);

class TicketsController extends AsyncNotifier<PagedList<Ticket>> {
  @override
  Future<PagedList<Ticket>> build() async {
    final first = await ref.watch(supportRepositoryProvider).page(1);
    return PagedList(items: first.items, page: 1, hasMore: first.hasNext);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await ref.read(supportRepositoryProvider).page(current.page + 1);
      state = AsyncData(PagedList(items: [...current.items, ...next.items], page: current.page + 1, hasMore: next.hasNext));
    } catch (e) {
      state = AsyncData(current.copyWith(loadingMore: false, moreError: e));
    }
  }
}

final ticketProvider = FutureProvider.autoDispose.family<Ticket, int>((ref, id) => ref.watch(supportRepositoryProvider).get(id));

final ticketCommentsProvider =
    FutureProvider.autoDispose.family<List<TicketComment>, int>((ref, id) => ref.watch(supportRepositoryProvider).comments(id));
