import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_message.dart';
import '../models/animation_dsl.dart';
import 'auth_service.dart';

class AiService {
  static const String baseUrl = 'http://localhost:8080/api/v1';
  // Python AI 服务地址（动画生成走这里）
  static const String aiBaseUrl = 'http://localhost:5001';

  final AuthService _auth = AuthService();
  final http.Client _client = http.Client();

  /// 发送 AI 聊天消息
  Future<AiMessage?> sendChat({
    required int courseId,
    required String message,
  }) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/courses/$courseId/ai/chat');

      final body = jsonEncode({
        'message': message,
      });

      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (kDebugMode) {
        print('sendChat status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final chatData = data['data'] as Map<String, dynamic>;
        return AiMessage(
          id: (chatData['chat_id'] ?? chatData['chatid']) as int? ?? 0,
          role: 'AI',
          content: chatData['reply'] as String? ?? '',
          createdAt: DateTime.parse(
              (chatData['created_at'] ?? chatData['createdat']) as String? ?? DateTime.now().toIso8601String()),
        );
      } else {
        throw Exception('AI 聊天失败：${resp.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('sendChat error: $e');
      }
      return null;
    }
  }

  /// 获取 AI 聊天历史
  Future<List<AiMessage>> fetchChatHistory({
    required int courseId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/courses/$courseId/ai/history')
          .replace(queryParameters: {
        'page': '$page',
        'page_size': '$pageSize',
      });

      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('fetchChatHistory status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data']['list'] as List<dynamic>)
            .map((e) {
          final item = e as Map<String, dynamic>;
          return AiMessage(
            id: item['id'] as int? ?? 0,
            role: item['sender'] as String? ?? 'USER',
            content: item['content'] as String? ?? '',
            createdAt: DateTime.parse(
                (item['created_at'] ?? item['createdat']) as String? ?? DateTime.now().toIso8601String()),
          );
        })
            .toList();
        return list;
      } else {
        throw Exception('获取聊天历史失败：${resp.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('fetchChatHistory error: $e');
      }
      return [];
    }
  }

  /// 清空 AI 聊天历史
  Future<bool> clearChatHistory(int courseId) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/courses/$courseId/ai/history');

      final resp = await _client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('clearChatHistory status: ${resp.statusCode}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('clearChatHistory error: $e');
      }
      return false;
    }
  }

  /// 调用 AI 服务生成 DSL 动画剧本
  /// [prompt] 用户的自然语言描述，例如 "演示冒泡排序，数组为 [5,3,1,4,2]"
  Future<AnimationScript> generateAnimationScript(String prompt) async {
    final uri = Uri.parse('$aiBaseUrl/api/v1/chat/animation');
    final body = jsonEncode({'prompt': prompt});

    if (kDebugMode) {
      print('generateAnimationScript prompt: $prompt');
    }

    late http.Response resp;
    try {
      resp = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      throw Exception('网络请求失败：$e');
    }

    if (kDebugMode) {
      print('generateAnimationScript status: \${resp.statusCode}');
    }

    if (resp.statusCode != 200) {
      throw Exception('生成失败（${resp.statusCode}）：${resp.body}');
    }

    final responseJson = jsonDecode(resp.body) as Map<String, dynamic>;
    final code = responseJson['code'] as int? ?? 0;
    if (code != 200) {
      throw Exception('服务返回错误：${responseJson['message']}');
    }

    final scriptJson =
        (responseJson['data'] as Map<String, dynamic>)['script'] as Map<String, dynamic>;
    return AnimationScript.fromJson(scriptJson);
  }

  /// 假实现（降级用）
  Future<AiMessage?> sendChatFake({
    required int sectionId,
    required String message,
  }) async {
    await Future.delayed(const Duration(milliseconds: 800));

    final replies = [
      '这是一个很好的问题。根据我对这个主题的理解...',
      '您可以通过以下步骤来解决这个问题...',
      '这涉及到几个重要的概念...',
      '让我为您详细解释一下...',
    ];

    final random = DateTime.now().millisecondsSinceEpoch % replies.length;

    return AiMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'ASSISTANT',
      content: replies[random],
      createdAt: DateTime.now(),
    );
  }
}
