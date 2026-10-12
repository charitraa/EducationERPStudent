import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/utils/json.dart';

/// One lesson. From the weekly timetable (`GET /timetable/me/`) or, with
/// [date] set, as it actually happens that day after substitutions, room
/// changes, cancellations and holidays (`GET /timetable/me/?date=`).
class Lesson {
  const Lesson({
    required this.dayOfWeek,
    required this.subjectName,
    this.date,
    this.periodName,
    this.startMinutes,
    this.endMinutes,
    this.teacherName,
    this.roomName,
    this.termName,
    this.isCancelled = false,
    this.closedBy,
    this.note,
    this.isSubstitute = false,
  });

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  final int dayOfWeek;
  final String subjectName;
  final DateTime? date;
  final String? periodName;
  final int? startMinutes;
  final int? endMinutes;
  final String? teacherName;
  final String? roomName;
  final String? termName;
  final bool isCancelled;

  /// The holiday, closure or exam day that suspends the lesson.
  final String? closedBy;
  final String? note;

  /// Taught by someone other than the regular teacher today.
  final bool isSubstitute;

  bool get isOff => isCancelled || closedBy != null;

  factory Lesson.fromJson(Map<String, dynamic> j) {
    final teacher = asInt(j['teacher']);
    final regular = asInt(j['regular_teacher']);
    return Lesson(
      dayOfWeek: asInt(j['day_of_week']) ?? 1,
      subjectName: asString(j['subject_name']) ?? 'Lesson',
      date: asDate(j['date']),
      periodName: asString(j['period_name']),
      startMinutes: asMinutes(j['start_time']),
      endMinutes: asMinutes(j['end_time']),
      teacherName: asString(j['teacher_name']),
      roomName: asString(j['room_name']),
      termName: asString(j['term_name']),
      isCancelled: asBool(j['is_cancelled']),
      closedBy: asString(j['closed_by']),
      note: asString(j['note']),
      isSubstitute: regular != null && teacher != null && regular != teacher,
    );
  }
}

class TimetableRepository {
  TimetableRepository(this._dio);
  final Dio _dio;

  Future<List<Lesson>> week() => _get(const {});

  Future<List<Lesson>> day(DateTime date) => _get({'date': isoDate(date)});

  Future<List<Lesson>> _get(Map<String, String> query) => guard(() async {
        // `as=student` so an account that is also a teacher still gets its class timetable.
        final res = await _dio.get<Map<String, dynamic>>('/timetable/me/', queryParameters: {'as': 'student', ...query});
        final lessons = asMapList(res.data?['lessons']).map(Lesson.fromJson).toList();
        lessons.sort((a, b) {
          final d = a.dayOfWeek.compareTo(b.dayOfWeek);
          return d != 0 ? d : (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0);
        });
        return lessons;
      });
}

final timetableRepositoryProvider = Provider.autoDispose((ref) => TimetableRepository(sessionDio(ref)));

final weekTimetableProvider = FutureProvider.autoDispose<List<Lesson>>((ref) {
  return ref.watch(timetableRepositoryProvider).week();
});

/// Lessons on one calendar day, keyed by the day's date (time ignored).
final dayTimetableProvider = FutureProvider.autoDispose.family<List<Lesson>, DateTime>((ref, date) {
  return ref.watch(timetableRepositoryProvider).day(date);
});

DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
