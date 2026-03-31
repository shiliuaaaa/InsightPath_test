import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/course_service.dart';
import '../utils/app_theme.dart';
import '../widgets/profile_header.dart';
import 'course_detail_page.dart';
import 'course_settings_page.dart';
import 'course_students_page.dart';
import 'create_course_page.dart';
import 'global_ai_tutor_page.dart';
import 'login_page.dart';

class TeacherHomePage extends StatefulWidget {
  const TeacherHomePage({super.key});

  @override
  State<TeacherHomePage> createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  final _courseService = CourseService();
  final _auth = AuthService();

  int _currentIndex = 0;
  bool _isLoading = false;
  String? _errorText;
  List<Course> _courses = [];
  String _username = '';
  String _school = '';
  String? _avatarUrl;
  String? _bgUrl;
  String _bio = '';

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
      _username = user?['nickname'] as String? ?? user?['username'] as String? ?? '';
      _school = user?['school'] as String? ?? '';
      _avatarUrl = user?['avatar'] as String?;
      _bgUrl = user?['bg_url'] as String?;
      _bio = user?['bio'] as String? ?? '';
    });
  }

  Future<void> _loadCourses() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final list = await _courseService.fetchMyCourses();
      if (!mounted) return;
      setState(() => _courses = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '加载课程失败：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _goCreate() async {
    final created = await Navigator.push<Course?>(
      context,
      MaterialPageRoute(builder: (_) => const CreateCoursePage()),
    );
    if (created != null && mounted) {
      setState(() => _courses = [created, ..._courses]);
    }
  }

  Future<void> _showCourseActions(Course c, int index) async {
                final action = await showModalBottomSheet<String>(
                  context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusL)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  c.title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.titleColor),
                          ),
                const SizedBox(height: 14),
                _sheetTile(Icons.open_in_new_rounded, '进入课程', AppTheme.primary, 'detail'),
                _sheetTile(Icons.settings_outlined, '课程设置', AppTheme.bodyColor, 'settings'),
                _sheetTile(Icons.group_outlined, '学生管理', AppTheme.bodyColor, 'students'),
              ],
            ),
                      ),
        ),
      ),
                );

    if (!mounted) return;
                if (action == 'detail') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailPage(course: c)));
                } else if (action == 'settings') {
                  final updated = await Navigator.push<dynamic>(
                    context,
        MaterialPageRoute(builder: (_) => CourseSettingsPage(course: c)),
                  );
      if (!mounted) return;
      if (updated == 'deleted') {
        setState(() => _courses.removeAt(index));
      } else if (updated is Course) {
        setState(() => _courses[index] = updated);
                  }
                } else if (action == 'students') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CourseStudentsPage(course: c)));
    }
  }

  Widget _sheetTile(IconData icon, String label, Color color, String value) => ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.hintColor, size: 18),
        onTap: () => Navigator.pop(context, value),
      );

  Widget _buildCoursesTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorText != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.hintColor),
            const SizedBox(height: 12),
            Text(_errorText!, style: const TextStyle(color: AppTheme.bodyColor)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadCourses, child: const Text('重试')),
          ],
                    ),
                  );
                }

    if (_courses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_box_outlined, size: 40, color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            const Text('还没有课程', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.titleColor)),
            const SizedBox(height: 8),
            const Text('点击右下角创建第一门课程', style: TextStyle(color: AppTheme.bodyColor)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCourses,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        itemCount: _courses.length,
        itemBuilder: (_, i) => _TeacherCourseCard(
          course: _courses[i],
          onTap: () => _showCourseActions(_courses[i], i),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        ProfileHeader(
          username: _username.isEmpty ? '讲师' : _username,
          role: 'TEACHER',
          schoolName: _school.trim().isEmpty ? null : _school,
          avatarUrl: _avatarUrl,
          bgUrl: _bgUrl,
          onProfileUpdated: _loadUser,
        ),
        if (_bio.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: const Border.fromBorderSide(BorderSide(color: Color(0xFFEEEFF2))),
              ),
              child: Text(
                _bio,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.bodyColor,
                  height: 1.6,
                ),
        ),
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('账户信息'),
        _infoCard([
          _infoTile(Icons.person_outline_rounded, '用户名', _username.isEmpty ? '未设置' : _username),
          _divider(),
          _infoTile(Icons.school_outlined, '学校', _school.trim().isEmpty ? '未填写' : _school),
          _divider(),
          _infoTile(Icons.badge_outlined, '身份', '讲师'),
        ]),
        const SizedBox(height: 8),
        _sectionTitle('功能'),
        _infoCard([
          _actionTile(Icons.verified_outlined, '教师认证', () {}),
          _divider(),
          _actionTile(Icons.tune_outlined, '教学偏好', () {}),
        ]),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('退出登录'),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.hintColor,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _infoCard(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: const Border.fromBorderSide(BorderSide(color: Color(0xFFEEEFF2))),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          child: Column(children: children),
        ),
      );

  Widget _divider() => const Divider(height: 1, thickness: 1, indent: 56, color: Color(0xFFF4F5F7));

  Widget _infoTile(IconData icon, String label, String value) => ListTile(
        leading: _leadingIcon(icon),
        title: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.bodyColor)),
        trailing: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.titleColor)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) => ListTile(
        leading: _leadingIcon(icon),
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.titleColor)),
        trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.hintColor),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
      );

  Widget _leadingIcon(IconData icon) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 18),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      extendBody: true,
      appBar: (_currentIndex == 1 || _currentIndex == 2)
          ? null
          : AppBar(
              title: Text(
                _currentIndex == 0 ? '我的课程' : '我的',
              ),
        actions: [
          if (_currentIndex == 0)
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadCourses),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), AppTheme.bg],
          ),
        ),
        child: IndexedStack(
          index: _currentIndex,
          children: [
            _buildCoursesTab(),
            GlobalAiTutorPage(username: _username),
            _buildProfileTab(),
          ],
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _goCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建课程', style: TextStyle(fontWeight: FontWeight.w600)),
            )
          : null,
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: '课程',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded),
            label: '小犀AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class _TeacherCourseCard extends StatelessWidget {
  const _TeacherCourseCard({required this.course, required this.onTap});

  final Course course;
  final VoidCallback onTap;

  String _statusLabel(String s) {
    switch (s) {
      case 'IN_PROGRESS':
        return '进行中';
      case 'COMPLETED':
        return '已结课';
      case 'PRE_RELEASE':
        return '未开课';
      case 'HIDDEN':
        return '已隐藏';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'IN_PROGRESS':
        return AppTheme.successColor;
      case 'COMPLETED':
        return AppTheme.hintColor;
      case 'HIDDEN':
        return AppTheme.errorColor;
      default:
        return AppTheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = course.title.isNotEmpty ? course.title[0] : '?';
    final statusColor = _statusColor(course.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: const Border.fromBorderSide(BorderSide(color: Color(0xFFEEEFF2))),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.brandGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusS),
                ),
                child: Center(
                  child: Text(
                    initial,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.titleColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _statusLabel(course.status),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          course.permission == 'OPEN' ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                          size: 13,
                          color: AppTheme.hintColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          course.permission == 'OPEN' ? '直接加入' : '需审批',
                          style: const TextStyle(fontSize: 12, color: AppTheme.hintColor),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.more_vert_rounded, color: AppTheme.hintColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.glassWhite.withValues(alpha: 0.92),
            border: const Border(top: BorderSide(color: Color(0xFFE8EAED), width: 0.6)),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: onTap,
            destinations: destinations,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            height: 56 + bottom,
          ),
        ),
      ),
    );
  }
}
