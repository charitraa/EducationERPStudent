// Contract and access checks against a running Education ERP backend.
// Skipped unless pointed at one with seeded accounts:
//
//   flutter test test/live_api_test.dart \
//     --dart-define=LIVE_API=http://127.0.0.1:8765/api/v1 \
//     --dart-define=LIVE_STUDENT=ram@kmc.test --dart-define=LIVE_TEACHER=hari@kmc.test \
//     --dart-define=LIVE_PASSWORD=...
import 'package:dio/dio.dart';
import 'package:education_erp_student/core/network/api_client.dart';
import 'package:education_erp_student/core/network/api_exception.dart';
import 'package:education_erp_student/features/attendance/attendance_repository.dart';
import 'package:education_erp_student/features/auth/auth_repository.dart';
import 'package:education_erp_student/features/exams/exams_repository.dart';
import 'package:education_erp_student/features/fees/fees_repository.dart';
import 'package:education_erp_student/features/notices/notices_repository.dart';
import 'package:education_erp_student/features/notifications/notifications_repository.dart';
import 'package:education_erp_student/features/results/results_repository.dart';
import 'package:education_erp_student/features/support/support_repository.dart';
import 'package:education_erp_student/features/timetable/timetable_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const _api = String.fromEnvironment('LIVE_API');
const _student = String.fromEnvironment('LIVE_STUDENT');
const _teacher = String.fromEnvironment('LIVE_TEACHER');
const _password = String.fromEnvironment('LIVE_PASSWORD');

void main() {
  final skip = _api.isEmpty ? 'set --dart-define=LIVE_API to run against a backend' : null;

  late MemoryTokenStorage tokens;
  late Dio dio;

  setUp(() async {
    if (skip != null) return;
    tokens = MemoryTokenStorage();
    dio = createApiClient(tokens: tokens, onSessionExpired: () {}, baseUrl: _api);
    final login = await AuthRepository(dio).login(email: _student, password: _password);
    await tokens.save(login.tokens);
  });

  Future<int?> status(String path, {Map<String, dynamic>? query}) async {
    try {
      return (await dio.get<dynamic>(path, queryParameters: query)).statusCode;
    } catch (e) {
      return asApiException(e).status;
    }
  }

  test('every student endpoint parses', () async {
    final student = await AuthRepository(dio).student();
    expect(student.studentNumber, isNotEmpty);
    expect(student.enrollment?.sectionName, isNotNull);

    final day = await TimetableRepository(dio).day(today());
    final week = await TimetableRepository(dio).week();
    expect(week, isNotEmpty);
    expect(day.every((l) => l.startMinutes != null), isTrue);

    final now = today();
    final attendance = await AttendanceRepository(dio).report(now.subtract(const Duration(days: 30)), now);
    expect(attendance.overall.total, greaterThan(0));
    expect(attendance.overall.percentage, isNotNull);

    final exams = await ExamsRepository(dio).mine();
    expect(exams, isNotEmpty);
    final cards = await ResultsRepository(dio).reportCards();
    expect(cards, isNotEmpty);
    expect(cards.first.subjects, isNotEmpty);
    await ResultsRepository(dio).transcript();

    final fees = await FeesRepository(dio).statement();
    expect(fees.invoices, isNotEmpty);

    final notices = await NoticesRepository(dio).page(1);
    expect(notices.items.map((n) => n.title), isNot(contains('Staff meeting')), reason: 'staff-only notice hidden');
    expect(notices.items.map((n) => n.title), isNot(contains('Draft notice')), reason: 'unpublished notice hidden');

    final notifications = NotificationsRepository(dio);
    final first = await notifications.page(1);
    expect(first.items, isNotEmpty);
    await notifications.markRead(first.items.first.id);
    expect(await notifications.unreadCount(), lessThan(first.items.length));

    final support = SupportRepository(dio);
    final ticket = await support.create(subject: 'Live test', description: 'Created by the live API test.');
    await support.addComment(ticket.id, 'A follow-up.');
    expect((await support.comments(ticket.id)).single.body, 'A follow-up.');
  }, skip: skip);

  test('a student cannot reach other records or staff endpoints', () async {
    final me = await AuthRepository(dio).student();
    final other = me.id == 1 ? 2 : 1;
    expect(await status('/students/$other/'), anyOf(403, 404));
    expect(await status('/students/'), 403);
    expect(await status('/results/'), 403);
    expect(await status('/invoices/'), 403);
    expect(await status('/attendance/records/'), 403);
    expect(await status('/payments/'), 403);
    expect(await status('/users/'), 403);
    expect(await status('/transcripts/$other/'), anyOf(403, 404));

    // `student=` only selects a parent's child; for a student it is ignored.
    final mine = (await dio.get<Map<String, dynamic>>('/invoices/me/', queryParameters: {'student': other})).data!;
    expect(mine['student'], me.id);
    final att = (await dio.get<Map<String, dynamic>>('/attendance/records/me/', queryParameters: {'student': other})).data!;
    expect((att['summary'] as Map)['student'], me.id);
  }, skip: skip);

  test('refresh tokens rotate and the old one is refused', () async {
    final old = tokens.refresh!;
    final res = await Dio(BaseOptions(baseUrl: _api)).post<Map<String, dynamic>>('/auth/refresh/', data: {'refresh': old});
    expect(res.data!['refresh'], isNot(old));
    final reuse = await Dio(BaseOptions(baseUrl: _api))
        .post<dynamic>('/auth/refresh/', data: {'refresh': old})
        .then<int?>((r) => r.statusCode, onError: (Object e) => (e as DioException).response?.statusCode);
    expect(reuse, 401);
  }, skip: skip);

  test('a teacher account has no student record', () async {
    final t = MemoryTokenStorage();
    final teacherDio = createApiClient(tokens: t, onSessionExpired: () {}, baseUrl: _api);
    final login = await AuthRepository(teacherDio).login(email: _teacher, password: _password);
    await t.save(login.tokens);
    final error = await AuthRepository(teacherDio).student().then<Object?>((_) => null, onError: (Object e) => e);
    expect((error as ApiException).kind, ApiErrorKind.notFound);
  }, skip: _api.isEmpty || _teacher.isEmpty ? 'needs LIVE_API and LIVE_TEACHER' : null);
}
