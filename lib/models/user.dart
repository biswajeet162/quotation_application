class User {
  final int? id;
  final String email;
  final String password; // In production, this should be hashed
  final String role; // 'admin' or 'user'
  final DateTime createdAt;

  User({
    this.id,
    required this.email,
    required this.password,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      email: map['email'] as String,
      password: map['password'] as String,
      role: map['role'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  bool get isAdmin => role == 'admin';
}

