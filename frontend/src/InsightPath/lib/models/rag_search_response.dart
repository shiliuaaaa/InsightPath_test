import 'search_reference.dart';

class RagSearchResponse {
  final String answer;
  final List<SearchReference> references;
  final bool success;
  final String message;

  RagSearchResponse({
    required this.answer,
    required this.references,
    required this.success,
    required this.message,
  });

  factory RagSearchResponse.fromJson(Map<String, dynamic> json) {
    return RagSearchResponse(
      answer: json['answer'] as String,
      references: (json['references'] as List)
          .map((e) => SearchReference.fromJson(e))
          .toList(),
      success: json['success'] as bool,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'references': references.map((e) => e.toJson()).toList(),
      'success': success,
      'message': message,
    };
  }
}