class User {
  final int? id;
  final String email;
  final String password; // In production, this should be hashed
  final String role; // 'admin' or 'user'
  final String name;
  final String mobileNumber;
  final String? createdBy; // Email of admin who created this user
  final DateTime createdAt;
  final DateTime? lastLoginTime;

  User({
    this.id,
    required this.email,
    required this.password,
    required this.role,
    required this.name,
    required this.mobileNumber,
    this.createdBy,
    required this.createdAt,
    this.lastLoginTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'role': role,
      'name': name,
      'mobileNumber': mobileNumber,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginTime': lastLoginTime?.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      email: map['email'] as String,
      password: map['password'] as String,
      role: map['role'] as String,
      name: map.containsKey('name') && map['name'] != null
          ? (map['name'] as String)
          : '',
      mobileNumber: map.containsKey('mobileNumber') && map['mobileNumber'] != null
          ? (map['mobileNumber'] as String)
          : '',
      createdBy: map.containsKey('createdBy') ? (map['createdBy'] as String?) : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastLoginTime: map.containsKey('lastLoginTime') &&
              map['lastLoginTime'] != null &&
              map['lastLoginTime'] is String
          ? DateTime.parse(map['lastLoginTime'] as String)
          : null,
    );
  }

  bool get isAdmin => role == 'admin';
}

