class Company {
  final int? id;
  final String name;
  final String address;
  final String mobile;
  final String email;
  final DateTime createdAt;

  Company({
    this.id,
    required this.name,
    required this.address,
    required this.mobile,
    required this.email,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'mobile': mobile,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String,
      mobile: map['mobile'] as String,
      email: map['email'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

