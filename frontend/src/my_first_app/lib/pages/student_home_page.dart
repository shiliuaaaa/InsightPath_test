import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/auth_service.dart';
import '../services/course_service.dart';
import '../utils/app_theme.dart';
import 'course_detail_page.dart';
import 'global_ai_tutor_page.dart';
import 'login_page.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final _courseService = CourseService();
  final _auth = AuthService();
  final _searchController = TextEditingController();

  int _currentIndex = 0;
  bool _isLoading = false;
  String? _errorText;
  List<Course> _courses = [];
  String _username = '';
  String _school = '示例大学';
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
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final list = await _courseService.fetchCourses(
        page: 1,
        keyword: _keyword.isEmpty ? null : _keyword,
      );
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

  Widget _buildCourseTab() {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeroCard()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: _GlassSearchBar(
              controller: _searchController,
              keyword: _keyword,
              onChanged: (v) => setState(() => _keyword = v),
              onSubmitted: _loadCourses,
              onClear: () {
                _searchController.clear();
                setState(() => _keyword = '');
                _loadCourses();
              },
                  ),
                ),
              ),
        if (_isLoading)
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
        else if (_errorText != null)
          SliverFillRemaining(
            child: _EmptyBlock(
              icon: Icons.wifi_off_rounded,
              message: _errorText!,
              action: ElevatedButton(onPressed: _loadCourses, child: const Text('重试')),
            ),
          )
        else if (_courses.isEmpty)
          const SliverFillRemaining(
            child: _EmptyBlock(
              icon: Icons.school_outlined,
              message: '暂无课程，等待讲师开课',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
            sliver: SliverList.builder(
              itemCount: _courses.length,
              itemBuilder: (_, i) => _StudentCourseCard(course: _courses[i]),
                ),
              ),
      ],
    );
  }

  Widget _buildHeroCard() {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '早上好' : (hour < 18 ? '下午好' : '晚上好');
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : 'S';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting 👋',
                  style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 6),
                Text(
                  _username.isEmpty ? '同学' : _username,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(_school, style: const TextStyle(fontSize: 13, color: Colors.white60)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_courses.length} 门课程',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.24),
            child: Text(
              initial,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    final initial = _username.isNotEmpty ? _username[0].toUpperCase() : 'S';

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 34),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white.withValues(alpha: 0.22),
                child: Text(initial, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_username.isEmpty ? '同学' : _username, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(_school, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionTitle('账户信息'),
        _infoCard([
          _infoTile(Icons.person_outline_rounded, '用户名', _username.isEmpty ? '未设置' : _username),
          _divider(),
          _infoTile(Icons.school_outlined, '学校', _school),
          _divider(),
          _infoTile(Icons.badge_outlined, '身份', '学生'),
        ]),
        const SizedBox(height: 8),
        _sectionTitle('功能'),
        _infoCard([
          _actionTile(Icons.notifications_outlined, '通知设置', () {}),
          _divider(),
          _actionTile(Icons.info_outline_rounded, '关于我们', () {}),
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

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
        child: Text(
          title,
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
      appBar: _currentIndex == 1
          ? null
          : AppBar(
              title: Text(
                _currentIndex == 0 ? '学习' : '我的',
              ),
              actions: [
                if (_currentIndex == 0)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: _loadCourses,
                  ),
              ],
            ),
      body: _currentIndex == 1
          ? IndexedStack(
              index: _currentIndex,
              children: [
                _buildCourseTab(),
                GlobalAiTutorPage(username: _username),
                _buildProfileTab(),
              ],
            )
          : Container(
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
                  _buildCourseTab(),
                  GlobalAiTutorPage(username: _username),
                  _buildProfileTab(),
                ],
              ),
            ),
      bottomNavigationBar: _GlassNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: '学习',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded),
            label: '小犀AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }
}

class _StudentCourseCard extends StatelessWidget {
  const _StudentCourseCard({required this.course});

  final Course course;

  static const List<List<Color>> _coverGradients = [
    [Color(0xFF1A73E8), Color(0xFF0D47A1)],
    [Color(0xFF34A853), Color(0xFF1B7E3B)],
    [Color(0xFFFA7B17), Color(0xFFE65100)],
    [Color(0xFF9C27B0), Color(0xFF6A1B9A)],
    [Color(0xFF00BCD4), Color(0xFF006064)],
  ];

  String _statusLabel(String s) {
    switch (s) {
      case 'IN_PROGRESS':
        return '进行中';
      case 'COMPLETED':
        return '已结课';
      case 'PRE_RELEASE':
        return '即将开课';
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
      default:
        return AppTheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _coverGradients[course.title.hashCode.abs() % _coverGradients.length];
    final initial = course.title.isNotEmpty ? course.title[0] : '?';

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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CourseDetailPage(course: course)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                    const SizedBox(height: 4),
                    Text('讲师：${course.teacherName}', style: const TextStyle(fontSize: 12, color: AppTheme.bodyColor)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _tag(_statusLabel(course.status), _statusColor(course.status)),
                        const SizedBox(width: 6),
                        if (course.isJoined)
                          _tag('已加入', AppTheme.secondary)
                        else if (course.isPendingApproval)
                          _tag('待审批', const Color(0xFFF59E0B))
                        else
                          _tag(
                            course.permission == 'OPEN' ? '可加入' : '需申请',
                            course.permission == 'OPEN' ? AppTheme.successColor : const Color(0xFFF59E0B),
                          ),
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
        child: Text(
          label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        ),
      );
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

class _GlassSearchBar extends StatelessWidget {
  const _GlassSearchBar({
    required this.controller,
    required this.keyword,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String keyword;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusM),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppTheme.radiusM),
            border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE8EAED))),
          ),
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '搜索课程...',
              prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.hintColor, size: 20),
              suffixIcon: keyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppTheme.hintColor),
                      onPressed: onClear,
                    )
                  : null,
              border: InputBorder.none,
              filled: false,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
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
            child: Icon(icon, size: 40, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          Text(message, style: const TextStyle(fontSize: 14, color: AppTheme.bodyColor), textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}
