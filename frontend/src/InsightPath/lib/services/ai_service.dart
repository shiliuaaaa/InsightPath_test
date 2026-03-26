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

  /// 启发式助教问答
  Future<String?> askSocraticTutor(String question) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/chat/socratic');
      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'question': question}),
      );

      if (resp.statusCode != 200) {
        throw Exception('请求失败：${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final payload = data['data'];
      if (payload is String) return payload;
      if (payload is Map<String, dynamic>) {
        return payload['reply'] as String? ??
            payload['answer'] as String? ??
            payload['content'] as String? ??
            payload['message'] as String?;
      }
      return data['message'] as String?;
    } catch (e) {
      if (kDebugMode) {
        print('askSocraticTutor error: $e');
      }
      return null;
    }
  }

  /// 创建全局聊天会话
  Future<int?> createGlobalSession({String? title}) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/global-chat/sessions');
      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({if (title != null && title.trim().isNotEmpty) 'title': title.trim()}),
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw Exception('创建会话失败：${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>? ?? {};
      final id = payload['id'] ?? payload['session_id'] ?? payload['sessionId'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('createGlobalSession error: $e');
      }
      return null;
    }
  }

  /// 获取全局聊天会话列表
  Future<List<GlobalChatSession>> getGlobalSessions() async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/global-chat/sessions');
      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode != 200) {
        throw Exception('获取会话失败：${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => GlobalChatSession.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      if (kDebugMode) {
        print('getGlobalSessions error: $e');
      }
      return [];
    }
  }

  /// 获取某个全局会话的消息列表
  Future<List<GlobalChatMessage>> getGlobalMessages(String sessionId) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/global-chat/sessions/$sessionId/messages');
      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (resp.statusCode != 200) {
        throw Exception('获取消息失败：${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => GlobalChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      if (kDebugMode) {
        print('getGlobalMessages error: $e');
      }
      return [];
    }
  }

  /// 发送全局聊天消息，返回 AI 回复
  Future<String?> sendGlobalMessage(
    String sessionId,
    String content, {
    bool enableWebSearch = true,
    String? fileContext,
  }) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/global-chat/message');
      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'session_id': int.tryParse(sessionId) ?? sessionId,
          'content': content,
          'enable_web_search': enableWebSearch,
          if (fileContext != null && fileContext.trim().isNotEmpty) 'file_context': fileContext.trim(),
        }),
      );

      if (resp.statusCode != 200) {
        throw Exception('发送消息失败：${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final payload = data['data'];
      if (payload is Map<String, dynamic>) {
        return payload['reply'] as String? ?? payload['content'] as String?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('sendGlobalMessage error: $e');
      }
      return null;
    }
  }

  /// 保存教师预设知径（绑定到课件页码）
  Future<bool> savePresetConfig(
    String sectionId,
    int pageNumber,
    String prompt,
    String dsl,
  ) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/sections/$sectionId/ai-configs');
      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'page_number': pageNumber,
          'prompt': prompt,
          'generated_dsl': dsl,
        }),
      );

      if (kDebugMode) {
        print('savePresetConfig status: ${resp.statusCode}');
      }
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        print('savePresetConfig error: $e');
      }
      return false;
    }
  }

  /// 获取某课件分区下所有预设知径
  Future<List<SectionAiConfig>> getPresetConfigs(String sectionId) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/sections/$sectionId/ai-configs');
      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('getPresetConfigs status: ${resp.statusCode}');
      }

      if (resp.statusCode != 200) {
        throw Exception('获取预设失败：${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .map((e) => SectionAiConfig.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    } catch (e) {
      if (kDebugMode) {
        print('getPresetConfigs error: $e');
      }
      return [];
    }
  }

  Future<bool> deletePresetConfig(String sectionId, int pageNumber) async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/sections/$sectionId/ai-configs/$pageNumber');
      final resp = await _client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (kDebugMode) {
        print('deletePresetConfig status: ${resp.statusCode}');
      }
      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('deletePresetConfig error: $e');
      }
      return false;
    }
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

class GlobalChatSession {
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  GlobalChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GlobalChatSession.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'] ?? json['session_id'] ?? json['sessionId'] ?? 0;
    return GlobalChatSession(
      id: idValue is int ? idValue : int.tryParse('$idValue') ?? 0,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? (json['title'] as String)
          : '新会话',
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

class GlobalChatMessage {
  final int id;
  final int sessionId;
  final String role;
  final String content;
  final DateTime createdAt;

  GlobalChatMessage({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory GlobalChatMessage.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'] ?? 0;
    final sidValue = json['session_id'] ?? json['sessionId'] ?? 0;
    return GlobalChatMessage(
      id: idValue is int ? idValue : int.tryParse('$idValue') ?? 0,
      sessionId: sidValue is int ? sidValue : int.tryParse('$sidValue') ?? 0,
      role: (json['role'] as String? ?? '').toLowerCase(),
      content: json['content'] as String? ?? '',
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }
}

DateTime _parseDateTime(dynamic raw) {
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw) ?? DateTime.now();
  }
  return DateTime.now();
}

class SectionAiConfig {
  final int id;
  final String sectionId;
  final int pageNumber;
  final String prompt;
  final String generatedDsl;
  final DateTime updatedAt;

  SectionAiConfig({
    required this.id,
    required this.sectionId,
    required this.pageNumber,
    required this.prompt,
    required this.generatedDsl,
    required this.updatedAt,
  });

  factory SectionAiConfig.fromJson(Map<String, dynamic> json) {
    final idRaw = json['id'] ?? 0;
    final sectionIdRaw = json['section_id'] ?? json['sectionId'] ?? '';
    final pageRaw = json['page_number'] ?? json['pageNumber'] ?? 0;
    return SectionAiConfig(
      id: idRaw is int ? idRaw : int.tryParse('$idRaw') ?? 0,
      sectionId: '$sectionIdRaw',
      pageNumber: pageRaw is int ? pageRaw : int.tryParse('$pageRaw') ?? 0,
      prompt: json['prompt'] as String? ?? '',
      generatedDsl: json['generated_dsl'] as String? ?? json['generatedDsl'] as String? ?? '',
      updatedAt: _parseDateTime(json['updated_at'] ?? json['updatedAt']),
    );
  }
}
