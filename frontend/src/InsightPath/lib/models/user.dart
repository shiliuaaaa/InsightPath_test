class AppUser {
  final int id;
  final String username;
  final String? nickname;
  final String role;
  final int? schoolId;

  AppUser({
    required this.id,
    required this.username,
    required this.role,
    this.nickname,
    this.schoolId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      nickname: json['nickname'] as String?,
      role: json['role'] as String,
      schoolId: json['schoolid'] as int?,
    );
  }
}

