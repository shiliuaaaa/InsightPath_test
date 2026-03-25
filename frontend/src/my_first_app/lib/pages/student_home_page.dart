import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/course_service.dart';
import '../services/auth_service.dart';
import 'course_detail_page.dart';
import 'login_page.dart';
import '../widgets/profile_header.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  int _currentIndex = 0;
  final _courseService = CourseService();
  final _auth = AuthService();

  bool _isLoading = false;
  String? _errorText;
  List<Course> _courses = [];

  String _username = '';
  String _role = 'STUDENT';
  String _school = '武汉大学';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCourses();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _username = user?['username'] as String? ?? '';
      _role = user?['role'] as String? ?? 'STUDENT';
      _school = user?['school'] as String? ?? '武汉大学';
    });
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final list = await _courseService.fetchCourses(page: 1);
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

  Widget _buildCourseList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      return Center(child: Text(_errorText!));
    }
    if (_courses.isEmpty) {
      return const Center(child: Text('暂无课程'));
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _courses.length,
        itemBuilder: (context, index) {
          final c = _courses[index];
          final statusLabel = c.isJoined
              ? '已加入'
              : (c.isPendingApproval ? '待审批' : '');

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1F77D2)
                    .withOpacity(0.2),
                child: Text(
                  c.title.characters.first,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F77D2),
                  ),
                ),
              ),
              title: Text(
                c.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '讲师：${c.teacherName}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: c.status == 'IN_PROGRESS'
                                ? const Color(0xFF4CAF50)
                                    .withOpacity(0.1)
                                : const Color(0xFFFFC107)
                                    .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.status == 'ONGOING'
                                ? '进行中'
                                : '已结束',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.status == 'ONGOING'
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFFFC107),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (statusLabel.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: c.isJoined
                                  ? const Color(0xFF00BCD4)
                                      .withOpacity(0.1)
                                  : const Color(0xFFF44336)
                                      .withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: c.isJoined
                                    ? const Color(0xFF00BCD4)
                                    : const Color(0xFFF44336),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: c.permission == 'OPEN'
                      ? const Color(0xFF4CAF50).withOpacity(0.1)
                      : const Color(0xFFFFC107).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  c.permission == 'OPEN' ? '可加入' : '需申请',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: c.permission == 'OPEN'
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFFC107),
                  ),
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseDetailPage(course: c),
                  ),
                ).then((_) {
                  setState(() {});
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfile() {
    return ListView(
      children: [
        ProfileHeader(
          username: _username.isEmpty ? '未登录用户' : _username,
          role: _role,
          schoolName: _school,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '账户信息',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF757575),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person,
                          color: Color(0xFF1F77D2)),
                      title: const Text('用户名'),
                      subtitle: Text(
                          _username.isEmpty ? '未设置' : _username),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.school,
                          color: Color(0xFF1F77D2)),
                      title: const Text('学校'),
                      subtitle: Text(_school),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email,
                          color: Color(0xFF1F77D2)),
                      title: const Text('身份'),
                      subtitle: Text(_role == 'TEACHER'
                          ? '讲师'
                          : '学生'),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '设置',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF757575),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading:
                          const Icon(Icons.notifications,
                              color: Color(0xFF1F77D2)),
                      title: const Text('通知设置'),
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock,
                          color: Color(0xFF1F77D2)),
                      title: const Text('隐私设置'),
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () {},
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.help_outline,
                          color: Color(0xFF1F77D2)),
                      title: const Text('关于我们'),
                      trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('退出登录'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildCourseList(),
      _buildProfile(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '学生端',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '退出登录',
            onPressed: _logout,
          ),
        ],
      ),
      body: pages[_currentIndex],
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
