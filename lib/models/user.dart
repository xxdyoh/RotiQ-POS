import 'cabang_model.dart';

class User {
  final String id;
  final String kduser;
  final String nmuser;
  final String? email;
  final String? phone;
  final String pin;
  final String? role;
  final Cabang? cabang;
  final bool isPusat;

  User({
    required this.id,
    required this.kduser,
    required this.nmuser,
    this.email,
    this.phone,
    required this.pin,
    this.role,
    this.cabang,
    this.isPusat = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      kduser: json['kduser'] ?? json['name'] ?? '',
      nmuser: json['nmuser'] ?? json['name'] ?? '',
      email: json['email'],
      phone: json['phone'],
      pin: json['pin']?.toString() ?? '',
      role: json['role'],
      cabang: json['cabang'] != null ? Cabang.fromJson(json['cabang']) : null,
      isPusat: json['isPusat'] ?? json['cabang']?['isPusat'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kduser': kduser,
      'nmuser': nmuser,
      'email': email,
      'phone': phone,
      'pin': pin,
      'role': role,
      'cabang': cabang?.toJson(),
    };
  }
}