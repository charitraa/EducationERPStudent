import 'package:dio/dio.dart';
import 'package:education_erp_student/app.dart';
import 'package:education_erp_student/core/network/api_client.dart';
import 'package:education_erp_student/core/providers.dart';
import 'package:education_erp_student/features/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Development fixtures for widget tests only — never shipped in the app.
const _user = {
  'id': 12, 'email': 'asha@example.edu', 'phone': '', 'first_name': 'Asha', 'middle_name': '', 'last_name': 'Rai',
  'full_name': 'Asha Rai', 'user_type': 'student', 'is_active': true, 'is_superuser': false,
  'organization': {'id': 1, 'name': 'Sunrise Academy', 'code': 'SUN'}, 'roles': [], 'permissions': [],
  'last_login': null, 'date_joined': '2024-04-15T05:00:00Z',
};

const _student = {
  'id': 7, 'student_number': 'S-1001', 'first_name': 'Asha', 'middle_name': '', 'last_name': 'Rai',
  'full_name': 'Asha Rai', 'campus_name': 'Lalitpur', 'status': 'active', 'admitted_on': '2024-04-15',
  'current_enrollment': {'section_name': 'Grade 10 - A', 'program_name': 'Secondary', 'academic_year_name': '2026/27',
      'started_on': '2026-04-14'},
};

Map<String, dynamic> _page(List<Object> items) =>
    {'count': items.length, 'total_pages': 1, 'page': 1, 'page_size': 25, 'next': null, 'previous': null, 'results': items};

/// Answers every endpoint the student app calls.
Future<(int, Object?)> _backend(RequestOptions o, {bool isStudent = true, bool otp = false}) async {
  final p = o.path;
  if (p.endsWith('/auth/login/')) {
    final data = o.data as Map;
    if (data['password'] != 'right') return (400, errorBody('invalid_credentials', 'Invalid credentials or inactive account.'));
    if (otp && data['otp'] == null) return (400, errorBody('otp_required', 'Enter the code from your authenticator app.'));
    return (200, {'access': 'A', 'refresh': 'R', 'user': _user});
  }
  if (p.endsWith('/auth/logout/')) return (204, null);
  if (p.endsWith('/auth/me/')) return (200, _user);
  if (p.endsWith('/students/me/')) {
    return isStudent ? (200, _student) : (404, errorBody('not_found', 'No student record is linked to your account.'));
  }
  if (p.endsWith('/timetable/me/')) return (200, {'as': 'student', 'date': null, 'student': 7, 'lessons': []});
  if (p.endsWith('/attendance/records/me/')) {
    return (200, {
      'summary': {'overall': {'total': 0}, 'daily': {'total': 0}, 'subjects': []},
      'records': [],
    });
  }
  if (p.endsWith('/exams/me/')) return (200, []);
  if (p.endsWith('/results/me/')) return (200, []);
  if (p.endsWith('/transcripts/me/')) return (200, {'records': [], 'cumulative': {'gpa': null}});
  if (p.endsWith('/invoices/me/')) return (200, {'invoices': [], 'total_billed': 0, 'total_paid': 0, 'balance': 0});
  if (p.endsWith('/notices/')) {
    return (200, _page([
      {'id': 1, 'title': 'Sports week', 'body': 'Sports week starts Monday.', 'audience': 'all', 'campus_name': null,
          'published_at': '2026-10-01T04:00:00Z'},
    ]));
  }
  if (p.endsWith('/notifications/unread-count/')) return (200, {'unread': 2});
  return (404, errorBody('not_found', 'Not found.'));
}

Future<MemoryTokenStorage> _pumpApp(WidgetTester tester, {String? refresh, bool isStudent = true, bool otp = false}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final tokens = MemoryTokenStorage(access: refresh == null ? null : 'A', refresh: refresh);
  await tester.pumpWidget(ProviderScope(
    retry: (_, _) => null,
    overrides: [
      tokenStorageProvider.overrideWithValue(tokens),
      apiClientProvider.overrideWith((ref) => createApiClient(
            tokens: tokens,
            onSessionExpired: () => ref.read(authControllerProvider.notifier).onSessionExpired(),
            baseUrl: 'http://api',
            adapter: () => FakeAdapter((o) => _backend(o, isStudent: isStudent, otp: otp)),
          )),
    ],
    child: const StudentApp(),
  ));
  await tester.pumpAndSettle();
  return tokens;
}

void main() {
  testWidgets('no saved session shows the login screen', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Student Portal'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('login validates input before calling the server', (tester) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('wrong password shows the server message', (tester) async {
    await _pumpApp(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asha@example.edu');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrong');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Invalid credentials or inactive account.'), findsOneWidget);
  });

  testWidgets('two-factor accounts are asked for a code', (tester) async {
    await _pumpApp(tester, otp: true);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'asha@example.edu');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'right');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Verification code'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Verification code'), '123456');
    await tester.tap(find.text('Verify and sign in'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Asha'), findsWidgets);
  });

  testWidgets('accounts without a student record are turned away', (tester) async {
    final tokens = await _pumpApp(tester, isStudent: false);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'teacher@example.edu');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'right');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text(notStudentMessage), findsOneWidget);
    expect(tokens.refresh, isNull, reason: 'the server session is discarded too');
  });

  testWidgets('a saved session opens the dashboard with live data', (tester) async {
    await _pumpApp(tester, refresh: 'R');
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('ID S-1001'), findsOneWidget);
    expect(find.text('Secondary · Grade 10 - A'), findsOneWidget);
    expect(find.text('Sports week'), findsOneWidget);
    expect(find.text('No upcoming exams.'), findsOneWidget);
    expect(find.text('2'), findsWidgets, reason: 'unread badge');
    // No invoices: the fee card stays hidden.
    expect(find.text('Outstanding'), findsNothing);
  });

  testWidgets('sign out returns to login and clears tokens', (tester) async {
    final tokens = await _pumpApp(tester, refresh: 'R');
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(tokens.refresh, isNull);
  });
}
