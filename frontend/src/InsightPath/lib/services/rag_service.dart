import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/rag_search_response.dart';
import '../services/auth_service.dart'; 
import '../models/course.dart'; 
import '../models/file_item.dart'; 
import '../models/section.dart'; 

class RagService {
  final http.Client _client;
  final AuthService _authService;

  RagService(this._client, this._authService);

  Future<bool> processDocument(int documentId) async {
    final token = await _authService.getToken();
    final response = await _client.post(
      Uri.parse(' ${ApiConfig.baseUrl}/api/v1/rag/documents/ $documentId/process'),
      headers: {
        'Authorization': 'Bearer  $token',
        'Content-Type': 'application/json',
      },
    );
    
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return result['data']['status'] == 'processing';
    } else {
      throw Exception('文档处理启动失败');
    }
  }

  Future<RagSearchResponse> semanticSearch({
    required String query,
    required int documentId,
    int topK = 5,
  }) async {
    final token = await _authService.getToken();
    final response = await _client.post(
      Uri.parse(' ${ApiConfig.baseUrl}/api/v1/rag/search'),
      headers: {
        'Authorization': 'Bearer  $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'query': query,
        'document_id': documentId,
        'top_k': topK,
      }),
    );
    
    if (response.statusCode == 200) {
      final result = jsonDecode(response.body);
      return RagSearchResponse.fromJson(result);
    } else {
      throw Exception('搜索失败:  ${response.reasonPhrase}');
    }
  }
}