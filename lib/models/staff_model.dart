class Staff {
  String id;
  String name;
  String role;
  String email;
  String phone;
  String avatarUrl;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.phone,
    this.avatarUrl = '',
  });

  factory Staff.fromMap(String id, Map<String, dynamic> data) {
    return Staff(
      id: id,
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      avatarUrl: data['avatarUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'email': email,
      'phone': phone,
      'avatarUrl': avatarUrl,
    };
  }
}
