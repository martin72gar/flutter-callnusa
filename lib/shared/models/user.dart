import 'package:meta/meta.dart';

/// Shape of `GET /api/v1/me`. [id] is the public UUID, never the integer key.
@immutable
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.role,
    this.status,
  });

  final String id;
  final String name;
  final String email;
  final String? role; // agent | tenant_admin | platform_admin
  final String? status;

  bool get isAdmin => role == 'tenant_admin' || role == 'platform_admin';

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: (json['public_id'] ?? json['id']).toString(),
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    role: json['role'] as String?,
    status: json['status'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'public_id': id,
    'name': name,
    'email': email,
    'role': role,
    'status': status,
  };
}
