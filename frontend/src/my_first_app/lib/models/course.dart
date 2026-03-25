class Course {
  final int id;
  final String title;
  final String description;
  final String teacherName;
  final String status;
  final String permission;
  final String visibility;
  final String coverImage;
  bool isJoined;
  bool isPendingApproval;

  Course({
    required this.id,
    required this.title,
    required this.description,
    required this.teacherName,
    required this.status,
    required this.permission,
    this.visibility = 'PUBLIC',
    this.coverImage = '',
    this.isJoined = false,
    this.isPendingApproval = false,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      teacherName: (json['teacher_name'] ?? json['teachername']) as String? ?? '未知讲师',
      status: json['status'] as String? ?? 'IN_PROGRESS',
      permission: json['permission'] as String? ?? 'OPEN',
      visibility: json['visibility'] as String? ?? 'PUBLIC',
      coverImage: (json['cover_image'] ?? json['coverimage']) as String? ?? '',
      isJoined: (json['is_joined'] ?? json['isjoined'] as bool?) ?? false,
      isPendingApproval: false,
    );
  }
}

