class User {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String pin;
  final String? role;

  User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    required this.pin,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'].toString(),
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      pin: json['pin']?.toString() ?? '',
      role: json['role'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'pin': pin,
      'role': role,
    };
  }
}