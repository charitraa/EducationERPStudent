import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../../core/utils/json.dart';

class SubjectLine {
  const SubjectLine({
    required this.subjectName,
    this.subjectCode,
    this.creditHours,
    this.obtained,
    this.full,
    this.percentage,
    this.letter,
    this.gradePoint,
    this.remark,
    this.status,
    this.absent = false,
  });

  final String subjectName;
  final String? subjectCode;
  final double? creditHours;
  final double? obtained;
  final double? full;
  final double? percentage;
  final String? letter;
  final double? gradePoint;
  final String? remark;

  /// `pass`, `fail`, `absent`, `withheld`… as the ERP computed it.
  final String? status;
  final bool absent;

  factory SubjectLine.fromJson(Map<String, dynamic> j) => SubjectLine(
        subjectName: asString(j['subject_name']) ?? 'Subject',
        subjectCode: asString(j['subject_code']),
        creditHours: asDouble(j['credit_hours']),
        obtained: asDouble(j['obtained']),
        full: asDouble(j['full']),
        percentage: asDouble(j['percentage']),
        letter: asString(j['letter']),
        gradePoint: asDouble(j['grade_point']),
        remark: asString(j['remark']),
        status: asString(j['status']),
        absent: asBool(j['absent']),
      );
}

class GradeBand {
  const GradeBand({required this.from, required this.letter, this.gradePoint, this.remark, this.pass = true});
  final double from;
  final String letter;
  final double? gradePoint;
  final String? remark;
  final bool pass;

  factory GradeBand.fromJson(Map<String, dynamic> j) => GradeBand(
        from: asDouble(j['from']) ?? 0,
        letter: asString(j['letter']) ?? '',
        gradePoint: asDouble(j['grade_point']),
        remark: asString(j['remark']),
        pass: j['pass'] != false,
      );
}

/// A published report card, from `GET /results/me/?include_card=true`.
/// The server never returns unpublished results here.
class ReportCard {
  const ReportCard({
    required this.resultId,
    required this.title,
    required this.subjects,
    required this.grading,
    this.kind,
    this.examType,
    this.academicYear,
    this.term,
    this.publishedAt,
    this.program,
    this.levelLabel,
    this.section,
    this.campus,
    this.totalObtained,
    this.totalFull,
    this.percentage,
    this.gradePoint,
    this.letter,
    this.division,
    this.result,
    this.rankInSection,
    this.rankInLevel,
    this.classSize,
    this.attendancePercentage,
    this.attendanceAttended,
    this.attendanceTotal,
    this.remark,
  });

  final int resultId;

  /// `exam` or `term`.
  final String? kind;
  final String title;
  final String? examType;
  final String? academicYear;
  final String? term;
  final DateTime? publishedAt;
  final String? program;
  final String? levelLabel;
  final String? section;
  final String? campus;
  final List<SubjectLine> subjects;
  final double? totalObtained;
  final double? totalFull;
  final double? percentage;
  final double? gradePoint;
  final String? letter;
  final String? division;

  /// Overall `pass` / `fail` etc.
  final String? result;
  final int? rankInSection;
  final int? rankInLevel;
  final int? classSize;
  final double? attendancePercentage;
  final int? attendanceAttended;
  final int? attendanceTotal;
  final String? remark;
  final List<GradeBand> grading;

  bool get passed => result == 'pass';

  factory ReportCard.fromJson(Map<String, dynamic> j) {
    final attendance = j['attendance'] is Map ? asMap(j['attendance']) : null;
    return ReportCard(
      resultId: asInt(j['result_id']) ?? 0,
      kind: asString(j['kind']),
      title: asString(j['title']) ?? 'Result',
      examType: asString(j['exam_type']),
      academicYear: asString(j['academic_year']),
      term: asString(j['term']),
      publishedAt: asDateTime(j['published_at']),
      program: asString(j['program']),
      levelLabel: asString(j['level_label']),
      section: asString(j['section']),
      campus: asString(j['campus']),
      subjects: asMapList(j['subjects']).map(SubjectLine.fromJson).toList(),
      totalObtained: asDouble(j['total_obtained']),
      totalFull: asDouble(j['total_full']),
      percentage: asDouble(j['percentage']),
      gradePoint: asDouble(j['grade_point']),
      letter: asString(j['letter']),
      division: asString(j['division']),
      result: asString(j['result']),
      rankInSection: asInt(j['rank_in_section']),
      rankInLevel: asInt(j['rank_in_level']),
      classSize: asInt(j['class_size']),
      attendancePercentage: attendance == null ? null : asDouble(attendance['percentage']),
      attendanceAttended: attendance == null ? null : asInt(attendance['attended']),
      attendanceTotal: attendance == null ? null : asInt(attendance['total']),
      remark: asString(j['remark']),
      grading: asMapList(j['grading']).map(GradeBand.fromJson).toList(),
    );
  }
}

/// Cumulative figures from `GET /transcripts/me/`.
class TranscriptSummary {
  const TranscriptSummary({this.gpa, this.credits, this.creditsPassed, this.records = 0});
  final double? gpa;
  final double? credits;
  final double? creditsPassed;
  final int records;

  factory TranscriptSummary.fromJson(Map<String, dynamic> j) {
    final c = asMap(j['cumulative']);
    return TranscriptSummary(
      gpa: asDouble(c['gpa']),
      credits: asDouble(c['credits']),
      creditsPassed: asDouble(c['credits_passed']),
      records: (j['records'] as List?)?.length ?? 0,
    );
  }
}

class ResultsRepository {
  ResultsRepository(this._dio);
  final Dio _dio;

  Future<List<ReportCard>> reportCards() => guard(() async {
        final res = await _dio.get<List<dynamic>>('/results/me/', queryParameters: {'include_card': 'true'});
        return asMapList(res.data).map(ReportCard.fromJson).toList();
      });

  Future<TranscriptSummary> transcript() => guard(() async {
        final res = await _dio.get<Map<String, dynamic>>('/transcripts/me/');
        return TranscriptSummary.fromJson(res.data!);
      });
}

final resultsRepositoryProvider = Provider.autoDispose((ref) => ResultsRepository(sessionDio(ref)));

final reportCardsProvider =
    FutureProvider.autoDispose<List<ReportCard>>((ref) => ref.watch(resultsRepositoryProvider).reportCards());

final transcriptProvider =
    FutureProvider.autoDispose<TranscriptSummary>((ref) => ref.watch(resultsRepositoryProvider).transcript());
