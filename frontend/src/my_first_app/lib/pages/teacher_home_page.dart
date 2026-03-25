import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/course_service.dart';
import '../services/auth_service.dart';
import 'course_detail_page.dart';
import 'create_course_page.dart';
import 'course_students_page.dart';
import 'course_settings_page.dart';
import 'login_page.dart';
import '../widgets/profile_header.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final CourseService _courseService = CourseService();
  final AuthService _auth = AuthService();

  int _currentIndex = 0;

  bool _isLoading = false;
  String? _errorText;
  List<Course> _courses = [];

  String _username = '';
  String _role = 'TEACHER';
  String _school = '武汉大学';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadTeacherCourses();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _username = user?['username'] as String? ?? '';
      _role = user?['role'] as String? ?? 'TEACHER';
      _school = user?['school'] as String? ?? '武汉大学';
    });
  }

  Future<void> _loadTeacherCourses() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final list = await _courseService.fetchMyCourses();
      setState(() {
        _courses = list;
      });
    } catch (e) {
      setState(() {
        _errorText = '加载课程失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _goToCreateCourse() async {
    final created = await Navigator.push<Course?>(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateCoursePage(),
      ),
    );

    if (created != null) {
      setState(() {
        _courses = [created, ..._courses];
      });
    }
  }

  Widget _buildCourseManage() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_errorText != null) {
      return Center(child: Text(_errorText!));
    } else if (_courses.isEmpty) {
      return const Center(child: Text('你还没有创建任何课程'));
    } else {
      return RefreshIndicator(
        onRefresh: _loadTeacherCourses,
        child: ListView.builder(
          itemCount: _courses.length,
          itemBuilder: (context, index) {
            final c = _courses[index];
            return ListTile(
              leading: const Icon(Icons.menu_book),
              title: Text(c.title),
              subtitle: Text('${c.teacherName} · ${c.status}'),
              onTap: () async {
                final action = await showModalBottomSheet<String>(
                  context: context,
                  builder: (context) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.info),
                            title: const Text('课程详情'),
                            onTap: () => Navigator.pop(context, 'detail'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.settings),
                            title: const Text('课程设置'),
                            onTap: () => Navigator.pop(context, 'settings'),
                          ),
                          ListTile(
                            leading: const Icon(Icons.group),
                            title: const Text('学生管理'),
                            onTap: () => Navigator.pop(context, 'students'),
                          ),
                        ],
                      ),
                    );
                  },
                );

                if (action == 'detail') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailPage(course: c),
                    ),
                  );
                } else if (action == 'settings') {
                  final updated = await Navigator.push<Course?>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseSettingsPage(course: c),
                    ),
                  );
                  if (updated != null) {
                    setState(() {
                      _courses[index] = updated;
                    });
                  }
                } else if (action == 'students') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseStudentsPage(course: c),
                    ),
                  );
                }
              },
            );
          },
        ),
      );
    }
  }

  Widget _buildProfile() {
    return ListView(
      children: [
        ProfileHeader(
          username: _username.isEmpty ? '未登录用户' : _username,
          role: _role,
          schoolName: _school,
        ),
        ListTile(
          leading: const Icon(Icons.badge),
          title: const Text('教师认证'),
          subtitle: const Text('以后可接入教师认证状态'),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.school),
          title: const Text('所属学校'),
          subtitle: Text(_school),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('教学偏好设置'),
          subtitle: const Text('如作业形式、评分方式等（预留）'),
          onTap: () {},
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text(
            '退出登录',
            style: TextStyle(color: Colors.red),
          ),
          onTap: _logout,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildCourseManage(),
      _buildProfile(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '教师端首页' : '我的'),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              onPressed: _loadTeacherCourses,
              icon: const Icon(Icons.refresh),
              tooltip: '刷新课程',
            ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
          ),
        ],
      ),
      body: pages[_currentIndex],
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _goToCreateCourse,
              icon: const Icon(Icons.add),
              label: const Text('新建课程'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book),
            label: '课程',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}
