import 'package:meta/meta.dart';

@immutable
class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.extension,
    this.tenantName,
    this.role,
  });

  final String id;
  final String name;
  final String email;
  final String? extension;
  final String? tenantName;
  final String? role;

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: '${json['id']}',
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    extension: json['extension'] as String?,
    tenantName: json['tenant_name'] as String?,
    role: json['role'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'extension': extension,
    'tenant_name': tenantName,
    'role': role,
  };
}
