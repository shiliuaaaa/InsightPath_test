class Section {
  final int id;
  final int courseId;
  final String title;
  final String type;
  final int orderIndex;

  Section({
    required this.id,
    required this.courseId,
    required this.title,
    required this.type,
    required this.orderIndex,
  });

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      id: json['id'] as int? ?? 0,
      courseId: (json['course_id'] ?? json['courseid'] ?? json['courseId'] ?? 0) as int,
      title: (json['title'] ?? '') as String,
      type: (json['type'] ?? 'DISPLAY') as String,
      orderIndex: (json['order'] ?? json['orderindex'] ?? json['orderIndex'] ?? 0) as int,
    );
  }
}

