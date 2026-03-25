import 'package:shared_preferences/shared_preferences.dart';

class NoteService {
  static const _keyPrefix = 'course_note_';

  String _keyForCourse(int courseId) => '$_keyPrefix$courseId';

  /// 读取某课程的讲义 Markdown 内容
  Future<String?> getNote(int courseId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyForCourse(courseId));
  }

  /// 保存某课程的讲义 Markdown 内容
  Future<void> saveNote(int courseId, String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyForCourse(courseId), text);
  }
}
