class AppUser {
  final String id;
  final String email;
  final String name;
  final String photoUrl;
  final String role; // 'owner', 'admin', 'employee'

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.photoUrl,
    required this.role,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      role: map['role'] ?? 'employee',
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'name': name, 'photoUrl': photoUrl, 'role': role};
  }

  AppUser copyWith({String? name, String? photoUrl, String? role}) {
    return AppUser(
      id: id,
      email: email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
    );
  }
}
