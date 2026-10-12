import 'package:education_erp_student/core/router/app_router.dart';
import 'package:education_erp_student/features/attendance/attendance_repository.dart';
import 'package:education_erp_student/features/auth/auth_controller.dart';
import 'package:education_erp_student/features/exams/exams_repository.dart';
import 'package:education_erp_student/features/fees/fees_repository.dart';
import 'package:education_erp_student/features/notifications/notifications_repository.dart';
import 'package:education_erp_student/features/profile/student.dart';
import 'package:education_erp_student/features/results/results_repository.dart';
import 'package:education_erp_student/features/shell/app_shell.dart';
import 'package:education_erp_student/features/timetable/lesson_tile.dart';
import 'package:education_erp_student/features/timetable/timetable_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Payloads below mirror what the backend's serializers and selectors emit.
void main() {
  test('Student from /students/me/', () {
    final s = Student.fromJson({
      'id': 7, 'organization': 1, 'student_number': 'S-1001', 'first_name': 'Asha', 'middle_name': '',
      'last_name': 'Rai', 'full_name': 'Asha Rai', 'date_of_birth': '2010-04-02', 'gender': 'female',
      'email': null, 'phone': '', 'address': '', 'campus': 2, 'campus_name': 'Lalitpur', 'status': 'active',
      'admitted_on': '2024-04-15', 'user': 12,
      'current_enrollment': {
        'id': 3, 'campus': 2, 'campus_name': 'Lalitpur', 'section': 9, 'section_name': 'Grade 10 - A',
        'program_name': 'Secondary', 'academic_year_name': '2026/27', 'status': 'active',
        'started_on': '2026-04-14', 'ended_on': null, 'end_reason': '', 'created_at': '2026-04-14T05:00:00Z',
      },
      'created_at': '2024-04-15T05:00:00Z', 'updated_at': '2026-04-14T05:00:00Z',
    });
    expect(s.initials, 'AR');
    expect(s.phone, isNull, reason: 'blank strings read as missing');
    expect(s.enrollment!.sectionName, 'Grade 10 - A');
    expect(s.enrollment!.startedOn, DateTime(2026, 4, 14));
  });

  test('Lesson marks substitutes and closures', () {
    final l = Lesson.fromJson({
      'entry': 1, 'date': '2026-10-12', 'day_of_week': 1, 'period': 2, 'period_name': 'P2',
      'start_time': '10:00:00', 'end_time': '10:45:00', 'section': 9, 'section_name': 'Grade 10 - A',
      'subject': 4, 'subject_name': 'Science', 'teacher': 31, 'teacher_name': 'R. Thapa', 'regular_teacher': 30,
      'room': 5, 'room_name': '101', 'is_cancelled': false, 'closed_by': 'Dashain', 'change': null, 'note': '',
      'combined_group': null,
    });
    expect(l.startMinutes, 600);
    expect(l.isSubstitute, isTrue);
    expect(l.isOff, isTrue);
    expect(l.note, isNull);
  });

  test('currentOrNext picks the running lesson, else the next one', () {
    Lesson at(int start, int end) => Lesson(dayOfWeek: 1, subjectName: 'X', startMinutes: start, endMinutes: end);
    final day = DateTime(2026, 10, 12);
    final lessons = [at(540, 585), at(600, 645), at(660, 705)];
    expect(currentOrNext(lessons, day, now: DateTime(2026, 10, 12, 10, 5)), (1, LessonMoment.now));
    expect(currentOrNext(lessons, day, now: DateTime(2026, 10, 12, 9, 50)), (1, LessonMoment.next));
    expect(currentOrNext(lessons, day, now: DateTime(2026, 10, 12, 12, 0)), isNull);
    expect(currentOrNext(lessons, day, now: DateTime(2026, 10, 13, 10, 5)), isNull, reason: 'other days never highlight');
  });

  test('AttendanceReport: roll call wins, otherwise the worst lesson mark', () {
    final r = AttendanceReport.fromJson({
      'summary': {
        'student': 7, 'student_name': 'Asha Rai', 'from': '2026-10-01', 'to': '2026-10-31',
        'overall': {'total': 5, 'present': 3, 'absent': 1, 'late': 1, 'excused': 0, 'leave': 0, 'medical_leave': 0,
            'on_duty': 0, 'attended': 4, 'percentage': 80.0},
        'daily': {'total': 1, 'present': 1, 'attended': 1, 'percentage': 100.0},
        'subjects': [
          {'subject': 4, 'subject_name': 'Science', 'total': 4, 'present': 2, 'absent': 1, 'late': 1, 'attended': 3, 'percentage': 75.0},
        ],
      },
      'records': [
        {'id': 1, 'date': '2026-10-05', 'subject_name': null, 'status': 'present'},
        {'id': 2, 'date': '2026-10-05', 'subject_name': 'Science', 'status': 'absent'},
        {'id': 3, 'date': '2026-10-06', 'subject_name': 'Science', 'status': 'present'},
        {'id': 4, 'date': '2026-10-06', 'subject_name': 'Maths', 'status': 'late'},
        {'id': 5, 'date': '2026-10-07', 'subject_name': 'Science', 'status': 'medical_leave'},
      ],
    });
    expect(r.overall.percentage, 80.0);
    expect(r.overall.count(AttendanceMark.late), 1);
    expect(r.subjects.single.counts.percentage, 75.0);
    final days = r.dayMarks;
    expect(days[DateTime(2026, 10, 5)], AttendanceMark.present);
    expect(days[DateTime(2026, 10, 6)], AttendanceMark.late);
    expect(days[DateTime(2026, 10, 7)], AttendanceMark.medicalLeave);
  });

  test('ReportCard reads numbers and nullable rank', () {
    final c = ReportCard.fromJson({
      'result_id': 11, 'kind': 'exam', 'title': 'First Terminal', 'exam_type': 'Terminal', 'academic_year': '2026/27',
      'term': null, 'published_at': '2026-08-01T04:00:00Z',
      'student': {'id': 7, 'name': 'Asha Rai'},
      'campus': 'Lalitpur', 'program': 'Secondary', 'level': 10, 'level_label': 'Grade 10', 'section': 'A',
      'subjects': [
        {'subject': 4, 'subject_name': 'Science', 'subject_code': 'SCI', 'credit_hours': 4.0, 'obtained': 72.5,
            'full': 100.0, 'percentage': 72.5, 'letter': 'B+', 'grade_point': 3.2, 'remark': '', 'status': 'pass',
            'absent': false, 'detail': {}},
      ],
      'total_obtained': 72.5, 'total_full': 100.0, 'percentage': 72.5, 'grade_point': 3.2, 'letter': 'B+',
      'division': null, 'result': 'pass', 'rank_in_section': null, 'rank_in_level': null, 'class_size': 32,
      'attendance': {'from': '2026-04-14', 'to': '2026-07-30', 'total': 90, 'attended': 85, 'percentage': 94.4},
      'remark': '', 'grading': [{'from': 90.0, 'letter': 'A+', 'grade_point': 4.0, 'remark': 'Outstanding', 'pass': true}],
    });
    expect(c.passed, isTrue);
    expect(c.rankInSection, isNull);
    expect(c.subjects.single.obtained, 72.5);
    expect(c.attendancePercentage, 94.4);
    expect(c.remark, isNull);
  });

  test('Exam upcoming is judged by its last paper', () {
    final e = Exam.fromJson({
      'id': 3, 'name': 'Second Terminal', 'type': 'Terminal', 'status': 'scheduled',
      'start_date': '2026-10-10', 'end_date': '2026-10-14', 'instructions': '',
      'papers': [
        {'subject_name': 'Maths', 'date': '2026-10-14', 'start_time': '10:00:00', 'end_time': '13:00:00'},
        {'subject_name': 'Science', 'date': '2026-10-10', 'start_time': '10:00:00', 'end_time': '13:00:00'},
      ],
      'seat': {'room': '101', 'seat_number': 'A-12'},
      'admit_card': {'id': 4, 'card_number': 'AC-77', 'status': 'issued', 'withheld_reason': ''},
    });
    expect(e.papers.first.subjectName, 'Science', reason: 'papers sorted by date');
    expect(e.isUpcoming(DateTime(2026, 10, 12)), isTrue);
    expect(e.isUpcoming(DateTime(2026, 10, 15)), isFalse);
    expect(e.remainingPapers(DateTime(2026, 10, 12)).single.subjectName, 'Maths');
    expect(e.admitCard!.isWithheld, isFalse);
  });

  test('FeeStatement from /invoices/me/', () {
    final s = FeeStatement.fromJson({
      'student': 7, 'student_name': 'Asha Rai', 'student_number': 'S-1001',
      'invoices': [
        {'invoice': 1, 'invoice_number': 'INV-1', 'term': 1, 'term_name': 'Term 1', 'issue_date': '2026-04-15',
            'due_date': '2026-05-15', 'total': 12000.0, 'paid': 12000.0, 'balance': 0.0, 'is_paid': true, 'is_overdue': false},
        {'invoice': 2, 'invoice_number': 'INV-2', 'term': 2, 'term_name': 'Term 2', 'issue_date': '2026-09-01',
            'due_date': '2026-09-30', 'total': 12000.0, 'paid': 2000.0, 'balance': 10000.0, 'is_paid': false, 'is_overdue': true},
      ],
      'total_billed': 24000.0, 'total_paid': 14000.0, 'balance': 10000.0,
    });
    expect(s.hasFees, isTrue);
    expect(s.anyOverdue, isTrue);
    expect(s.nextDue, DateTime(2026, 9, 30));
  });

  test('Notifications route to the matching screen', () {
    AppNotification n(String type) => AppNotification(id: 1, eventType: type, title: 't');
    expect(n('examinations.result_published').route, '/results');
    expect(n('attendance.marked_absent').route, '/attendance');
    expect(n('finance.payment_received').route, '/fees');
    expect(n('library.reservation_ready').route, isNull);
  });

  group('router guard', () {
    test('signed-out users only reach the login screens', () {
      expect(authRedirect(AuthStatus.signedOut, '/'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/results/11'), '/login');
      expect(authRedirect(AuthStatus.signedOut, '/forgot-password'), isNull);
    });
    test('signed-in users skip the login screens', () {
      expect(authRedirect(AuthStatus.signedIn, '/login'), '/');
      expect(authRedirect(AuthStatus.signedIn, '/splash'), '/');
      expect(authRedirect(AuthStatus.signedIn, '/fees'), isNull);
    });
    test('an unconfirmed session waits on the splash screen', () {
      expect(authRedirect(AuthStatus.unknown, '/fees'), '/splash');
      expect(authRedirect(AuthStatus.offline, '/'), '/splash');
    });
  });

  test('secondary screens highlight "More" on phones', () {
    expect(navIndexFor(mobileNav, '/'), 0);
    expect(navIndexFor(mobileNav, '/results/12'), 3);
    expect(navIndexFor(mobileNav, '/notices/4'), 4);
    expect(navIndexFor(sideNav, '/support/new'), sideNav.indexWhere((i) => i.path == '/support'));
  });
}
