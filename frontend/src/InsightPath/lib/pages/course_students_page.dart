import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/course_member.dart';
import '../services/course_service.dart';
import '../utils/app_theme.dart';

class CourseStudentsPage extends StatefulWidget {
  final Course course;

  const CourseStudentsPage({super.key, required this.course});

  @override
  State<CourseStudentsPage> createState() => _CourseStudentsPageState();
}

class _CourseStudentsPageState extends State<CourseStudentsPage> {
  final CourseService _courseService = CourseService();

  bool _loading = false;
  String? _errorText;
  List<CourseMember> _members = [];
  final TextEditingController _inviteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final list = await _courseService.fetchCourseStudents(widget.course.id);
      if (!mounted) return;
      setState(() => _members = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = '加载学生列表失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'JOINED':
        return '已加入';
      case 'PENDING':
        return '待审批';
      default:
        return status;
    }
  }

  Future<void> _approve(CourseMember m) async {
    final ok = await _courseService.auditApplication(
      courseId: widget.course.id,
      applicationId: m.id,
      action: 'APPROVE',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已通过 ${m.name} 的申请' : '操作失败，请重试')),
    );
    if (ok) _loadMembers();
  }

  Future<void> _reject(CourseMember m) async {
    final ok = await _courseService.auditApplication(
      courseId: widget.course.id,
      applicationId: m.id,
      action: 'REJECT',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已拒绝 ${m.name} 的申请' : '操作失败，请重试')),
    );
    if (ok) _loadMembers();
  }

  Future<void> _removeStudent(CourseMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认移除'),
        content: Text('确定要将 ${m.name} 移出课程吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('移除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _courseService.removeStudent(
      courseId: widget.course.id,
      studentId: m.id,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '已移除 ${m.name}' : '移除失败，请重试')),
    );
    if (ok) _loadMembers();
  }

  void _showInviteDialog() {
    _inviteController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusM)),
        title: const Text('邀请学生'),
        content: TextField(
          controller: _inviteController,
          decoration: const InputDecoration(
            labelText: '输入学生用户名',
            prefixIcon: Icon(Icons.person_search_rounded),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final username = _inviteController.text.trim();
              if (username.isEmpty) return;
              Navigator.pop(ctx);
              await _inviteStudent(username);
            },
            child: const Text('邀请'),
          ),
        ],
      ),
    );
  }

  Future<void> _inviteStudent(String username) async {
    try {
      final ok = await _courseService.inviteStudent(
        courseId: widget.course.id,
        username: username,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? '已成功邀请 $username' : '邀请失败，用户可能不存在或已在课程中')),
      );
      if (ok) _loadMembers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('邀请出错：$e')));
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorText != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorText!, style: const TextStyle(color: AppTheme.errorColor)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _loadMembers, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_members.isEmpty) {
      return const Center(child: Text('暂无学生', style: TextStyle(color: AppTheme.bodyColor)));
    }

    return RefreshIndicator(
        onRefresh: _loadMembers,
        child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final m = _members[index];
            final isPending = m.status == 'PENDING';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: const Color(0xFFEFF2F6)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  m.name.isNotEmpty ? m.name.characters.first : '?',
                  style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${m.phone} · ${_statusText(m.status)}'),
              trailing: isPending
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: () => _approve(m), child: const Text('通过')),
                        TextButton(
                          onPressed: () => _reject(m),
                          child: const Text('拒绝', style: TextStyle(color: AppTheme.errorColor)),
                        ),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: AppTheme.errorColor),
                      tooltip: '移除学生',
                      onPressed: () => _removeStudent(m),
                    ),
            ),
            );
          },
        ),
      );
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text('学生管理 · ${widget.course.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: '邀请学生',
            onPressed: _showInviteDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
                  ),
                  child: _buildBody(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
