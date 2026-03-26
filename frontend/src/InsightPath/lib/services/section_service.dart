import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/section.dart';
import '../models/file_item.dart';
import '../models/syllabus_node.dart';
import 'auth_service.dart';
import '../models/file_list_response.dart';

class SectionService {
  static const String baseUrl = 'http://localhost:8080/api/v1';

  final AuthService _auth = AuthService();
  final http.Client _client = http.Client();

  /// 获取课程分区列表（讲义/资料/AI）
  Future<List<Section>> fetchSections(int courseId) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) {
        return _getFakeSections();
      }

      final uri = Uri.parse('$baseUrl/courses/$courseId/sections');

      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('fetchSections status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data'] as List<dynamic>)
            .map((e) => Section.fromJson(e as Map<String, dynamic>))
            .toList();
        return list;
      } else {
        return _getFakeSections();
      }
    } catch (e) {
      if (kDebugMode) {
        print('fetchSections error: $e');
      }
      return _getFakeSections();
    }
  }

  /// 获取讲义内容（DISPLAY 类型）
  Future<String?> fetchDisplayContent(int courseId, int sectionId) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) return null;

      final uri = Uri.parse(
          '$baseUrl/courses/$courseId/sections/$sectionId/content');

      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('fetchDisplayContent status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['data']['content'] as String?;
      } else if (resp.statusCode == 404) {
        return null;
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('fetchDisplayContent error: $e');
      }
      return null;
    }
  }

  /// 更新讲义内容（老师端）
  Future<bool> updateDisplayContent(
      int courseId, int sectionId, String content) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse(
          '$baseUrl/courses/$courseId/sections/$sectionId/content');

      final body = jsonEncode({
        'content': content,
      });

      final resp = await _client.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('updateDisplayContent status: ${resp.statusCode}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('updateDisplayContent error: $e');
      }
      return false;
    }
  }

  /// 获取资料列表（STORAGE 类型）
  Future<FileListResponse?> fetchFiles({
    required int courseId,
    required int sectionId,
    required int parentId,
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) return null;

      final uri = Uri.parse(
          '$baseUrl/courses/$courseId/sections/$sectionId/files')
          .replace(queryParameters: {'parent_id': '$parentId'});

      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('fetchFiles status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final responseData = data['data'] as Map<String, dynamic>;

        final fileList = (responseData['list'] as List<dynamic>?)
            ?.map((e) => FileItem.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];

        final pathList = (responseData['path'] as List<dynamic>?)
            ?.map((p) => PathItem(
              id: p['id'] as int? ?? 0,
              name: p['name'] as String? ?? '',
            ))
            .toList() ?? [];

        return FileListResponse(
          currentFolderId: (responseData['current_folder_id'] ?? responseData['currentfolderid']) as int? ?? parentId,
          path: pathList,
          files: fileList,
        );
      } else {
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print('fetchFiles error: $e');
      }
      return null;
    }
  }

  /// 删除文件/文件夹
  Future<bool> deleteFile({
    required int courseId,
    required int sectionId,
    required String itemId,
    required String type,
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse(
              '$baseUrl/courses/$courseId/sections/$sectionId/items/$itemId')
          .replace(queryParameters: {'type': type});

      final resp = await _client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('deleteFile status: ${resp.statusCode}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('deleteFile error: $e');
      }
      return false;
    }
  }

  /// 重命名文件/文件夹
  Future<bool> renameFile({
    required int courseId,
    required int sectionId,
    required String itemId,
    required String newName,
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse(
          '$baseUrl/courses/$courseId/sections/$sectionId/items/$itemId/rename');

      final body = jsonEncode({
        'name': newName,
      });

      final resp = await _client.put(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('renameFile status: ${resp.statusCode}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('renameFile error: $e');
      }
      return false;
    }
  }

  /// 新建文件夹
  Future<bool> createFolder({
    required int courseId,
    required int sectionId,
    required String name,
    int? parentId,
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) throw Exception('未登录');

      final queryParams = <String, String>{'name': name};
      if (parentId != null && parentId != 0) {
        queryParams['parent_id'] = '$parentId';
      }

      final uri = Uri.parse(
              '$baseUrl/courses/$courseId/sections/$sectionId/folders')
          .replace(queryParameters: queryParams);

      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) print('createFolder status: ${resp.statusCode}');
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      if (kDebugMode) print('createFolder error: $e');
      return false;
    }
  }

  /// 上传文件到课程资料区
  Future<bool> uploadFile({
    required int courseId,
    required int sectionId,
    required File file,
    required String fileName,
    int? parentId,
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/common/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['usage'] = 'COURSE_MATERIAL'
        ..fields['id'] = '$courseId'
        ..fields['section_id'] = '$sectionId';

      if (parentId != null && parentId != 0) {
        request.fields['parent_id'] = '$parentId';
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName,
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);

      if (kDebugMode) print('uploadFile status: ${resp.statusCode}, body: ${resp.body}');
      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (e) {
      if (kDebugMode) print('uploadFile error: $e');
      return false;
    }
  }

  /// 获取文件下载/访问 URL
  String getFileAccessUrl(String storedName) {
    return '$baseUrl/common/static/$storedName?usage=COURSE_MATERIAL';
  }

  /// 获取课程大纲树
  Future<List<SyllabusNode>> fetchSyllabus(int courseId) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) return [];

      final uri = Uri.parse('$baseUrl/courses/$courseId/syllabus');
      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['data'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SyllabusNode.fromJson)
          .toList();
      return list;
    } catch (e) {
      if (kDebugMode) print('fetchSyllabus error: $e');
      return [];
    }
  }

  Future<SyllabusNode?> createSyllabusChapter({
    required int courseId,
    required String title,
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/courses/$courseId/syllabus/chapters');
      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'title': title}),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200 && resp.statusCode != 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return SyllabusNode.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) print('createSyllabusChapter error: $e');
      return null;
    }
  }

  Future<SyllabusNode?> createSyllabusKnowledge({
    required int courseId,
    required int chapterId,
    required String title,
    required int resourceFileId,
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/courses/$courseId/syllabus/chapters/$chapterId/knowledge');
      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'resource_file_id': resourceFileId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200 && resp.statusCode != 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return SyllabusNode.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) print('createSyllabusKnowledge error: $e');
      return null;
    }
  }

  Future<SyllabusNode?> createSyllabusQuiz({
    required int courseId,
    required int chapterId,
    required String quizType,
    required String question,
    required String answer,
    List<QuizOption> options = const [],
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) return null;

      final uri = Uri.parse('$baseUrl/courses/$courseId/syllabus/chapters/$chapterId/quiz');
      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'quiz_type': quizType,
          'question': question,
          'answer': answer,
          'options': options.map((e) => e.toJson()).toList(),
        }),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200 && resp.statusCode != 201) return null;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return SyllabusNode.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) print('createSyllabusQuiz error: $e');
      return null;
    }
  }

  /// 上传文件到课程资料区（返回新建 fileId，便于直接关联知识点）
  Future<int?> uploadFileForSyllabus({
    required int courseId,
    required int sectionId,
    required File file,
    required String fileName,
    int? parentId,
  }) async {
    try {
      final token = await _auth.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/common/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['usage'] = 'COURSE_MATERIAL'
        ..fields['id'] = '$courseId'
        ..fields['section_id'] = '$sectionId';

      if (parentId != null && parentId != 0) {
        request.fields['parent_id'] = '$parentId';
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        filename: fileName,
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200 && resp.statusCode != 201) return null;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final idRaw = (data['data'] as Map<String, dynamic>)['courseFileId'];
      if (idRaw is int) return idRaw;
      if (idRaw is String) return int.tryParse(idRaw);
      return null;
    } catch (e) {
      if (kDebugMode) print('uploadFileForSyllabus error: $e');
      return null;
    }
  }

  // ========== 假数据 ==========

  List<Section> _getFakeSections() {
    return [
      Section(
        id: 101,
        courseId: 1,
        title: '讲义',
        type: 'DISPLAY',
        orderIndex: 0,
      ),
      Section(
        id: 102,
        courseId: 1,
        title: '资料',
        type: 'STORAGE',
        orderIndex: 1,
      ),
      Section(
        id: 103,
        courseId: 1,
        title: '课程 AI',
        type: 'AI',
        orderIndex: 2,
      ),
    ];
  }
}
