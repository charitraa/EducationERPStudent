import '../../core/utils/json.dart';

/// The signed-in student's record, from `GET /students/me/`.
class Student {
  const Student({
    required this.id,
    required this.studentNumber,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    this.middleName,
    this.dateOfBirth,
    this.gender,
    this.email,
    this.phone,
    this.address,
    this.campusName,
    this.status,
    this.admittedOn,
    this.enrollment,
  });

  final int id;
  final String studentNumber;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String fullName;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? email;
  final String? phone;
  final String? address;
  final String? campusName;
  final String? status;
  final DateTime? admittedOn;
  final Enrollment? enrollment;

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return (f + l).toUpperCase();
  }

  factory Student.fromJson(Map<String, dynamic> j) {
    final first = asString(j['first_name']) ?? '';
    final last = asString(j['last_name']) ?? '';
    return Student(
      id: asInt(j['id']) ?? 0,
      studentNumber: asString(j['student_number']) ?? '',
      firstName: first,
      middleName: asString(j['middle_name']),
      lastName: last,
      fullName: asString(j['full_name']) ?? '$first $last'.trim(),
      dateOfBirth: asDate(j['date_of_birth']),
      gender: asString(j['gender']),
      email: asString(j['email']),
      phone: asString(j['phone']),
      address: asString(j['address']),
      campusName: asString(j['campus_name']),
      status: asString(j['status']),
      admittedOn: asDate(j['admitted_on']),
      enrollment: j['current_enrollment'] is Map ? Enrollment.fromJson(asMap(j['current_enrollment'])) : null,
    );
  }
}

/// The student's current class placement.
class Enrollment {
  const Enrollment({this.sectionName, this.programName, this.academicYearName, this.campusName, this.startedOn, this.status});

  /// The class and section as the school writes it, e.g. "Grade 10 - A".
  final String? sectionName;
  final String? programName;
  final String? academicYearName;
  final String? campusName;
  final DateTime? startedOn;
  final String? status;

  factory Enrollment.fromJson(Map<String, dynamic> j) => Enrollment(
        sectionName: asString(j['section_name']),
        programName: asString(j['program_name']),
        academicYearName: asString(j['academic_year_name']),
        campusName: asString(j['campus_name']),
        startedOn: asDate(j['started_on']),
        status: asString(j['status']),
      );
}
