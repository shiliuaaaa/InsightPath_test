class SyllabusNode {
  final int id;
  final int? parentId;
  final String type;
  final String title;

  final int? resourceFileId;
  final String? resourceName;
  final String? resourceUrl;
  final String? resourcePdfUrl;
  final String? resourceExtension;

  final String? question;
  final List<QuizOption> options;
  final String? answer;

  final List<SyllabusNode> children;

  SyllabusNode({
    required this.id,
    required this.parentId,
    required this.type,
    required this.title,
    required this.resourceFileId,
    required this.resourceName,
    required this.resourceUrl,
    required this.resourcePdfUrl,
    required this.resourceExtension,
    required this.question,
    required this.options,
    required this.answer,
    required this.children,
  });

  bool get isChapter => type == 'CHAPTER';
  bool get isKnowledge => type == 'KNOWLEDGE';
  bool get isQuizChoice => type == 'QUIZ_CHOICE';
  bool get isQuizEssay => type == 'QUIZ_ESSAY';

  factory SyllabusNode.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? 0;
    final parentRaw = json['parent_id'];
    final resourceFileIdRaw = json['resource_file_id'];

    final childList = (json['children'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(SyllabusNode.fromJson)
        .toList();

    final options = (json['options'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(QuizOption.fromJson)
        .toList();

    return SyllabusNode(
      id: idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0,
      parentId: parentRaw == null
          ? null
          : (parentRaw is int ? parentRaw : int.tryParse('$parentRaw')),
      type: json['type'] as String? ?? 'CHAPTER',
      title: json['title'] as String? ?? '',
      resourceFileId: resourceFileIdRaw == null
          ? null
          : (resourceFileIdRaw is int
              ? resourceFileIdRaw
              : int.tryParse('$resourceFileIdRaw')),
      resourceName: json['resource_name'] as String?,
      resourceUrl: json['resource_url'] as String?,
      resourcePdfUrl: json['resource_pdf_url'] as String?,
      resourceExtension: json['resource_extension'] as String?,
      question: json['question'] as String?,
      options: options,
      answer: json['answer'] as String?,
      children: childList,
    );
  }
}

class QuizOption {
  final String key;
  final String content;

  QuizOption({required this.key, required this.content});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      key: json['key'] as String? ?? '',
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'content': content,
      };
}

