import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/json.dart';
import '../auth/auth_controller.dart';

/// The backend's attendance statuses (`AttendanceStatus`).
enum AttendanceMark {
  present('present', 'Present', AppColors.success, Icons.check_circle_outline),
  late('late', 'Late', AppColors.warning, Icons.schedule),
  absent('absent', 'Absent', AppColors.danger, Icons.cancel_outlined),
  leave('leave', 'On leave', AppColors.info, Icons.beach_access_outlined),
  medicalLeave('medical_leave', 'Medical leave', AppColors.info, Icons.medical_services_outlined),
  excused('excused', 'Excused', AppColors.neutral, Icons.remove_circle_outline),
  onDuty('on_duty', 'On duty', AppColors.success, Icons.work_outline);

  const AttendanceMark(this.code, this.label, this.color, this.icon);
  final String code;
  final String label;
  final Color color;
  final IconData icon;

  static AttendanceMark? fromCode(String? code) {
    for (final m in values) {
      if (m.code == code) return m;
    }
    return null;
  }

  /// Higher wins when several lessons on one day disagree.
  int get severity => switch (this) {
        absent => 4,
        late => 3,
        leave || medicalLeave || excused => 2,
        present || onDuty => 1,
      };
}

/// Counts per status over a span, as the server's `summarize()` returns them.
class AttendanceCounts {
  const AttendanceCounts({required this.total, required this.byStatus, required this.attended, this.percentage});

  final int total;
  final Map<AttendanceMark, int> byStatus;
  final int attended;

  /// Attended ÷ (total − excused), or null when nothing counted yet.
  final double? percentage;

  int count(AttendanceMark m) => byStatus[m] ?? 0;
  int get leaveCount => count(AttendanceMark.leave) + count(AttendanceMark.medicalLeave) + count(AttendanceMark.excused);

  factory AttendanceCounts.fromJson(Map<String, dynamic> j) => AttendanceCounts(
        total: asInt(j['total']) ?? 0,
        attended: asInt(j['attended']) ?? 0,
        percentage: asDouble(j['percentage']),
        byStatus: {for (final m in AttendanceMark.values) m: asInt(j[m.code]) ?? 0},
      );

  static const empty = AttendanceCounts(total: 0, byStatus: {}, attended: 0);
}

class SubjectAttendance {
  const SubjectAttendance(this.subjectName, this.counts);
  final String subjectName;
  final AttendanceCounts counts;
}

class AttendanceRecord {
  const AttendanceRecord({required this.id, required this.date, required this.mark, this.subjectName, this.note});

  final int id;
  final DateTime date;
  final AttendanceMark? mark;

  /// The lesson's subject; null for the daily roll call.
  final String? subjectName;
  final String? note;

  bool get isDaily => subjectName == null;

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: asInt(j['id']) ?? 0,
        date: asDate(j['date']) ?? DateTime(1970),
        mark: AttendanceMark.fromCode(asString(j['status'])),
        subjectName: asString(j['subject_name']),
        note: asString(j['note']),
      );
}

class AttendanceReport {
  const AttendanceReport({
    required this.from,
    required this.to,
    required this.overall,
    required this.daily,
    required this.subjects,
    required this.records,
  });

  final DateTime from;
  final DateTime to;
  final AttendanceCounts overall;
  final AttendanceCounts daily;
  final List<SubjectAttendance> subjects;
  final List<AttendanceRecord> records;

  /// One status per day: the roll call if taken, otherwise the most serious
  /// lesson mark (any absence shows the day as absent).
  Map<DateTime, AttendanceMark> get dayMarks {
    final out = <DateTime, AttendanceMark>{};
    final daily = <DateTime>{};
    for (final r in records) {
      final m = r.mark;
      if (m == null) continue;
      if (r.isDaily) {
        out[r.date] = m;
        daily.add(r.date);
      } else if (!daily.contains(r.date)) {
        final current = out[r.date];
        if (current == null || m.severity > current.severity) out[r.date] = m;
      }
    }
    return out;
  }

  factory AttendanceReport.fromJson(Map<String, dynamic> j) {
    final summary = asMap(j['summary']);
    return AttendanceReport(
      from: asDate(summary['from']) ?? DateTime.now(),
      to: asDate(summary['to']) ?? DateTime.now(),
      overall: AttendanceCounts.fromJson(asMap(summary['overall'])),
      daily: AttendanceCounts.fromJson(asMap(summary['daily'])),
      subjects: asMapList(summary['subjects'])
          .map((s) => SubjectAttendance(asString(s['subject_name']) ?? 'Subject', AttendanceCounts.fromJson(s)))
          .toList(),
      records: asMapList(j['records']).map(AttendanceRecord.fromJson).toList(),
    );
  }
}

class AttendanceRepository {
  AttendanceRepository(this._dio);
  final Dio _dio;

  /// The server allows at most this many days per request.
  static const maxSpanDays = 400;

  /// `GET /attendance/records/me/?from=&to=`: read-only, and always the
  /// signed-in student's own records.
  Future<AttendanceReport> report(DateTime from, DateTime to) => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/attendance/records/me/',
            queryParameters: {'from': isoDate(from), 'to': isoDate(to)});
        return AttendanceReport.fromJson(res.data!);
      });
}

final attendanceRepositoryProvider = Provider.autoDispose((ref) => AttendanceRepository(sessionDio(ref)));

typedef DateSpan = ({DateTime from, DateTime to});

final attendanceProvider = FutureProvider.autoDispose.family<AttendanceReport, DateSpan>((ref, span) {
  return ref.watch(attendanceRepositoryProvider).report(span.from, span.to);
});

DateSpan monthSpan(DateTime month) {
  final from = DateTime(month.year, month.month, 1);
  final to = DateTime(month.year, month.month + 1, 0);
  return (from: from, to: to);
}

/// From the start of the current enrollment (this academic year's class) to
/// today, capped at the server's maximum span.
final enrollmentSpanProvider = Provider.autoDispose<DateSpan>((ref) {
  final student = ref.watch(authControllerProvider.select((s) => s.student));
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final earliest = today.subtract(const Duration(days: AttendanceRepository.maxSpanDays));
  var from = student?.enrollment?.startedOn ?? today.subtract(const Duration(days: 365));
  if (from.isBefore(earliest)) from = earliest;
  if (from.isAfter(today)) from = today;
  return (from: from, to: today);
});
