import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/course.dart';
import 'auth_service.dart';
import '../models/course_member.dart';

class CourseService {
  static const String baseUrl = 'http://localhost:8080/api/v1';

  final http.Client _client = http.Client();
  final _authService = AuthService();

  /// 获取教师自己的课程列表（后端对教师角色自动过滤）
  Future<List<Course>> fetchMyCourses() async {
    return fetchCourses(page: 1);
  }

  /// 获取课程列表
  Future<List<Course>> fetchCourses({
    int page = 1,
    int? schoolId,
    String? keyword,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null) {
        return _getFakeCourses();
      }

      final query = <String, String>{
        'page': '$page',
      };
      if (schoolId != null) query['school_id'] = '$schoolId';
      if (keyword != null && keyword.isNotEmpty) {
        query['keyword'] = keyword;
      }

      final uri =
          Uri.parse('$baseUrl/courses').replace(queryParameters: query);

      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('fetchCourses status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data']['list'] as List<dynamic>)
            .map((c) => Course.fromJson(c as Map<String, dynamic>))
            .toList();
        return list;
      } else if (resp.statusCode == 401) {
        await _authService.logout();
        return _getFakeCourses();
      } else {
        return _getFakeCourses();
      }
    } catch (e) {
      if (kDebugMode) {
        print('fetchCourses error: $e');
      }
      return _getFakeCourses();
    }
  }

  /// 获取课程详情
  Future<Course?> fetchCourseDetail(int courseId) async {
    try {
      final token = (await _authService.getSavedToken())?.trim();
      if (token == null || token.isEmpty) {
        throw Exception('未登录，请先重新登录');
      }

      if (kDebugMode) {
        print('createCourse token exists: ${token.isNotEmpty}, prefix: ${token.substring(0, token.length > 12 ? 12 : token.length)}...');
      }

      final uri = Uri.parse('$baseUrl/courses/$courseId');

      final resp = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('fetchCourseDetail status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return Course.fromJson(data['data'] as Map<String, dynamic>);
      } else if (resp.statusCode == 403 || resp.statusCode == 404) {
        throw Exception('无权访问或课程不存在');
      } else {
        throw Exception('获取课程详情失败：${resp.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('fetchCourseDetail error: $e');
      }
      return null;
    }
  }

  /// 加入课程
  Future<String?> enrollCourse(
    int courseId, {
    String? applyReason,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null || token.isEmpty) {
        throw Exception('未登录，请先重新登录');
      }

      final uri = Uri.parse('$baseUrl/courses/$courseId/enroll');

      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (applyReason != null) 'apply_reason': applyReason,
        }),
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('enrollCourse status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['data']['status'] as String?;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('enrollCourse error: $e');
      }
      return null;
    }
  }

  /// 创建课程（真实后端）
  Future<Course?> createCourse({
    required String title,
    required String description,
    required String coverImage,
    required int schoolId,
    required String status,
    required String visibility,
    required String permission,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null || token.isEmpty) {
        throw Exception('未登录，请先重新登录');
      }

      if (kDebugMode) {
        final prefix = token.substring(0, token.length > 16 ? 16 : token.length);
        print('createCourse token prefix: $prefix...');
      }

      final uri = Uri.parse('$baseUrl/courses');

      final body = jsonEncode({
        'title': title,
        'description': description,
        'cover_image': coverImage,
        'school_id': schoolId,
        'status': status,
        'visibility': visibility,
        'permission': permission,
      });

      final resp = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('createCourse status: ${resp.statusCode}, body: ${resp.body}');
      }

      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final payload = data['data'] as Map<String, dynamic>? ?? {};
        return Course.fromJson(payload);
      } else {
        throw Exception('创建课程失败：${resp.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('createCourse error: $e');
      }
      return null;
    }
  }

  /// 创建课程（假实现）
  Future<Course?> createCourseFake({
    required String title,
    required String description,
    required String coverImage,
    required int schoolId,
    required String status,
    required String visibility,
    required String permission,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return Course(
      id: DateTime.now().millisecondsSinceEpoch,
      title: title,
      description: description,
      teacherName: '讲师',
      status: status,
      permission: permission,
      visibility: visibility,
      coverImage: coverImage,
      isJoined: true,
      isPendingApproval: false,
    );
  }

  /// 上传课程封面（返回可直接保存到 cover_image 的相对 URL）
  Future<String?> uploadCourseCover({
    required File file,
    required String fileName,
    int? courseId,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null || token.isEmpty) {
        throw Exception('未登录，请先重新登录');
      }

      final uri = Uri.parse('$baseUrl/common/upload');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['usage'] = 'COURSE_COVER';

      if (courseId != null) {
        request.fields['id'] = '$courseId';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: fileName,
        ),
      );

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);

      if (kDebugMode) {
        print('uploadCourseCover status: ${resp.statusCode}, body: ${resp.body}');
      }

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        return null;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final payload = data['data'] as Map<String, dynamic>? ?? {};
      final filename = payload['filename'] as String?;
      if (filename == null || filename.isEmpty) {
        return null;
      }
      return '/api/v1/common/static/$filename?usage=COURSE_COVER';
    } catch (e) {
      if (kDebugMode) {
        print('uploadCourseCover error: $e');
      }
      return null;
    }
  }

  /// 删除课程（教师端）
  Future<bool> deleteCourse(int courseId) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null || token.isEmpty) {
        throw Exception('未登录，请先重新登录');
      }

      final uri = Uri.parse('$baseUrl/courses/$courseId');
      final resp = await _client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('deleteCourse status: ${resp.statusCode}, body: ${resp.body}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('deleteCourse error: $e');
      }
      return false;
    }
  }

  /// 更新课程设置（真实后端）
  Future<bool> updateCourseSettings({
    required int courseId,
    required String title,
    required String description,
    required String coverImage,
    required String status,
    required String visibility,
    required String permission,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse('$baseUrl/courses/$courseId/settings');

      final body = jsonEncode({
        'title': title,
        'description': description,
        'cover_image': coverImage,
        'status': status,
        'visibility': visibility,
        'permission': permission,
      });

      final resp = await _client.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('updateCourseSettings status: ${resp.statusCode}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('updateCourseSettings error: $e');
      }
      return false;
    }
  }

  /// 更新课程设置（假实现）
  Future<bool> updateCourseSettingsFake({
    required Course original,
    required String title,
    required String description,
    required String coverImage,
    required String status,
    required String visibility,
    required String permission,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }

  /// 获取课程学生列表
  Future<List<CourseMember>> fetchCourseStudents(
    int courseId, {
    int page = 1,
    String? status,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null) {
        return _getStudentsFake();
      }

      String url = '$baseUrl/courses/$courseId/students?page=$page';
      if (status != null) {
        url += '&status=$status';
      }

      final resp = await _client.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('fetchCourseStudents status: ${resp.statusCode}');
      }

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['data']['list'] as List<dynamic>)
            .map((m) => CourseMember(
                  id: m['id'] as int? ?? 0,
                  name: m['nickname'] as String? ?? '',
                  phone: m['phone'] as String? ?? '',
                  status: m['status'] as String? ?? 'JOINED',
                ))
            .toList();
        return list;
      } else {
        return _getStudentsFake();
      }
    } catch (e) {
      if (kDebugMode) {
        print('fetchCourseStudents error: $e');
      }
      return _getStudentsFake();
    }
  }

  /// 审批学生申请
  Future<bool> auditApplication({
    required int courseId,
    required int applicationId,
    required String action,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse(
        '$baseUrl/courses/$courseId/applications/$applicationId/audit',
      );

      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'action': action,
        }),
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('auditApplication status: ${resp.statusCode}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('auditApplication error: $e');
      }
      return false;
    }
  }

  /// 踢出学生
  Future<bool> removeStudent({
    required int courseId,
    required int studentId,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri =
          Uri.parse('$baseUrl/courses/$courseId/students/$studentId');

      final resp = await _client.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('removeStudent status: ${resp.statusCode}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('removeStudent error: $e');
      }
      return false;
    }
  }

  // ========== 假数据实现 ==========

  List<Course> _getFakeCourses() {
    return [
      Course(
        id: 1,
        title: '数据结构与算法',
        description: '深入理解数据结构和算法设计',
        teacherName: '张教授',
        status: 'INPROGRESS',
        permission: 'OPEN',
        visibility: 'PUBLIC',
        coverImage: '',
        isJoined: false,
        isPendingApproval: false,
      ),
      Course(
        id: 2,
        title: '计算机网络',
        description: '计算机网络基础与应用',
        teacherName: '李教授',
        status: 'PRERELEASE',
        permission: 'APPLY',
        visibility: 'RESTRICTED',
        coverImage: '',
        isJoined: false,
        isPendingApproval: false,
      ),
    ];
  }

  List<CourseMember> _getStudentsFake() {
    return [
      CourseMember(
        id: 1,
        name: '张三',
        phone: '13800000001',
        status: 'JOINED',
      ),
      CourseMember(
        id: 2,
        name: '李四',
        phone: '13800000002',
        status: 'PENDING',
      ),
      CourseMember(
        id: 3,
        name: '王五',
        phone: '13800000003',
        status: 'JOINED',
      ),
    ];
  }
    /// 对外暴露的假数据方法（兼容旧代码）
  Future<List<CourseMember>> fetchStudentsFake(int courseId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _getStudentsFake();
  }

  /// 邀请学生加入课程（教师端）
  Future<bool> inviteStudent({
    required int courseId,
    required String username,
  }) async {
    try {
      final token = await _authService.getSavedToken();
      if (token == null) throw Exception('未登录');

      final uri = Uri.parse(
        '$baseUrl/courses/$courseId/students/invite',
      ).replace(queryParameters: {'username': username});

      final resp = await _client.post(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (kDebugMode) {
        print('inviteStudent status: \${resp.statusCode}');
      }

      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('inviteStudent error: \$e');
      }
      return false;
    }
  }

}
