import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'course_detail_page.dart';
import 'login_page.dart';

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
  String _school = '武汉大学';
  final _searchController = TextEditingController();
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadCourses();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getCurrentUser();
    if (!mounted) return;
    setState(() {
      _username = user?['nickname'] as String? ?? user?['username'] as String? ?? '';
      _school = user?['school'] as String? ?? '示例大学';
    });
  }

  Future<void> _loadCourses() async {
    setState(() { _isLoading = true; _errorText = null; });
    try {
      final list = await _courseService.fetchCourses(page: 1, keyword: _keyword.isEmpty ? null : _keyword);
      setState(() => _courses = list);
    } catch (e) {
      setState(() => _errorText = '加载课程失败：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  // ── 课程列表 Tab ──
  Widget _buildCourseTab() {
    return CustomScrollView(
      slivers: [
        // 搜索栏
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索课程...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hintColor, size: 20),
                suffixIcon: _keyword.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppTheme.hintColor),
                        onPressed: () { _searchController.clear(); setState(() => _keyword = ''); _loadCourses(); },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() => _keyword = v),
              onSubmitted: (_) => _loadCourses(),
                            ),
                          ),
                        ),
        // 课程内容
        if (_isLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_errorText != null)
          SliverFillRemaining(
            child: Center(
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
            ),
          )
        else if (_courses.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.school_outlined, size: 56, color: AppTheme.hintColor),
                  SizedBox(height: 12),
                  Text('暂无课程', style: TextStyle(color: AppTheme.bodyColor, fontSize: 15)),
                  ],
                ),
              ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _CourseCard(course: _courses[i]),
                childCount: _courses.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── 我的 Tab ──
  Widget _buildProfileTab() {
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : '?';
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // 头部卡片
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A4F95), Color(0xFF1E6BB8)],
                ),
              ),
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(initial, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_username.isEmpty ? '未登录' : _username,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('学生', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle('账户信息'),
        _infoCard([
          _infoTile(Icons.person_outline_rounded, '用户名', _username.isEmpty ? '未设置' : _username),
          _infoTile(Icons.school_outlined, '学校', _school),
          _infoTile(Icons.badge_outlined, '身份', '学生'),
        ]),
        const SizedBox(height: 8),
        _sectionTitle('更多'),
        _infoCard([
          _actionTile(Icons.notifications_outlined, '通知设置', () {}),
          _actionTile(Icons.lock_outline_rounded, '隐私设置', () {}),
          _actionTile(Icons.info_outline_rounded, '关于我们', () {}),
        ]),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('退出登录'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.5)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
    child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: AppTheme.hintColor, letterSpacing: 0.5)),
  );

  Widget _infoCard(List<Widget> children) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFF0F0F5))),
    ),
    child: Column(children: children),
  );

  Widget _infoTile(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, color: AppTheme.primary, size: 20),
    title: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.bodyColor)),
    trailing: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.titleColor)),
    dense: true,
  );

  Widget _actionTile(IconData icon, String label, VoidCallback onTap) => ListTile(
    leading: Icon(icon, color: AppTheme.primary, size: 20),
    title: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.titleColor)),
    trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.hintColor),
    dense: true,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text(_currentIndex == 0 ? '发现课程' : '我的'),
        actions: [
          if (_currentIndex == 0)
          IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadCourses,
              tooltip: '刷新',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildCourseTab(), _buildProfileTab()],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFF0F0F5))),
        ),
        child: BottomNavigationBar(
        currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
        items: const [
            BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore_rounded), label: '发现'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: '我的'),
        ],
        ),
      ),
    );
  }
}

// ── 课程卡片组件 ──
class _CourseCard extends StatelessWidget {
  final Course course;
  const _CourseCard({required this.course});

  String _statusLabel(String s) {
    switch (s) {
      case 'IN_PROGRESS': return '进行中';
      case 'COMPLETED': return '已结课';
      case 'PRE_RELEASE': return '即将开课';
      default: return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'IN_PROGRESS': return AppTheme.successColor;
      case 'COMPLETED': return AppTheme.hintColor;
      default: return AppTheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = course.title.isNotEmpty ? course.title[0] : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(BorderSide(color: Color(0xFFF0F0F5))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CourseDetailPage(course: course))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A4F95), Color(0xFF3AAFA9)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Center(child: Text(initial,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.titleColor),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('讲师：${course.teacherName}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.bodyColor)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _tag(_statusLabel(course.status), _statusColor(course.status)),
                        const SizedBox(width: 6),
                        if (course.isJoined) _tag('已加入', AppTheme.secondary)
                        else if (course.isPendingApproval) _tag('待审批', const Color(0xFFF59E0B))
                        else _tag(course.permission == 'OPEN' ? '可加入' : '需申请',
                            course.permission == 'OPEN' ? AppTheme.successColor : const Color(0xFFF59E0B)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.hintColor, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );
}
