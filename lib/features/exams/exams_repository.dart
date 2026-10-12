import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/utils/json.dart';

class ExamPaper {
  const ExamPaper({required this.subjectName, this.date, this.startMinutes, this.endMinutes});
  final String subjectName;
  final DateTime? date;
  final int? startMinutes;
  final int? endMinutes;

  factory ExamPaper.fromJson(Map<String, dynamic> j) => ExamPaper(
        subjectName: asString(j['subject_name']) ?? 'Subject',
        date: asDate(j['date']),
        startMinutes: asMinutes(j['start_time']),
        endMinutes: asMinutes(j['end_time']),
      );
}

class AdmitCardInfo {
  const AdmitCardInfo({required this.cardNumber, required this.status, this.withheldReason});
  final String cardNumber;
  final String status;
  final String? withheldReason;

  bool get isWithheld => status == 'withheld';

  factory AdmitCardInfo.fromJson(Map<String, dynamic> j) => AdmitCardInfo(
        cardNumber: asString(j['card_number']) ?? '',
        status: asString(j['status']) ?? '',
        withheldReason: asString(j['withheld_reason']),
      );
}

/// A scheduled or published exam for the student's class, from `GET /exams/me/`.
class Exam {
  const Exam({
    required this.id,
    required this.name,
    required this.papers,
    this.type,
    this.status,
    this.startDate,
    this.endDate,
    this.instructions,
    this.seatRoom,
    this.seatNumber,
    this.admitCard,
  });

  final int id;
  final String name;
  final String? type;

  /// `scheduled` or `published` (results out).
  final String? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? instructions;
  final List<ExamPaper> papers;
  final String? seatRoom;
  final String? seatNumber;
  final AdmitCardInfo? admitCard;

  /// Not finished yet, judged by the last paper (or the exam's end date).
  bool isUpcoming(DateTime today) {
    final last = papers.map((p) => p.date).whereType<DateTime>().fold<DateTime?>(
        endDate, (a, b) => a == null || b.isAfter(a) ? b : a);
    return last == null || !last.isBefore(today);
  }

  /// Papers still to sit, in order.
  List<ExamPaper> remainingPapers(DateTime today) =>
      papers.where((p) => p.date == null || !p.date!.isBefore(today)).toList();

  factory Exam.fromJson(Map<String, dynamic> j) {
    final seat = j['seat'] is Map ? asMap(j['seat']) : null;
    final papers = asMapList(j['papers']).map(ExamPaper.fromJson).toList()
      ..sort((a, b) {
        final d = (a.date ?? DateTime(9999)).compareTo(b.date ?? DateTime(9999));
        return d != 0 ? d : (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0);
      });
    return Exam(
      id: asInt(j['id']) ?? 0,
      name: asString(j['name']) ?? 'Exam',
      type: asString(j['type']),
      status: asString(j['status']),
      startDate: asDate(j['start_date']),
      endDate: asDate(j['end_date']),
      instructions: asString(j['instructions']),
      papers: papers,
      seatRoom: seat == null ? null : asString(seat['room']),
      seatNumber: seat == null ? null : asString(seat['seat_number']),
      admitCard: j['admit_card'] is Map ? AdmitCardInfo.fromJson(asMap(j['admit_card'])) : null,
    );
  }
}

class ExamsRepository {
  ExamsRepository(this._dio);
  final Dio _dio;

  Future<List<Exam>> mine() => guard(() async {
        final res = await _dio.get<List<dynamic>>('/exams/me/');
        return asMapList(res.data).map(Exam.fromJson).toList();
      });
}

final examsRepositoryProvider = Provider.autoDispose((ref) => ExamsRepository(sessionDio(ref)));

final examsProvider = FutureProvider.autoDispose<List<Exam>>((ref) => ref.watch(examsRepositoryProvider).mine());
