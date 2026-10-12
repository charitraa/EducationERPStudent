import '../../core/utils/json.dart';

/// The login account, from `/auth/me/` and the login response.
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.firstName,
    this.lastName,
    this.phone,
    this.userType,
    this.organizationName,
    this.lastLogin,
  });

  final int id;
  final String email;
  final String fullName;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? userType;

  /// The school or college.
  final String? organizationName;
  final DateTime? lastLogin;

  factory CurrentUser.fromJson(Map<String, dynamic> j) => CurrentUser(
        id: asInt(j['id']) ?? 0,
        email: asString(j['email']) ?? '',
        fullName: asString(j['full_name']) ?? '',
        firstName: asString(j['first_name']),
        lastName: asString(j['last_name']),
        phone: asString(j['phone']),
        userType: asString(j['user_type']),
        organizationName: asString(asMap(j['organization'])['name']),
        lastLogin: asDateTime(j['last_login']),
      );
}
