import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/course_member.dart';
import '../services/course_service.dart';

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

  // 用于邀请的搜索
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
      final list = await _courseService.fetchCourseStudents(
        widget.course.id,
      );
      setState(() {
        _members = list;
      });
    } catch (e) {
      setState(() {
        _errorText = '加载学生列表失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已通过 ${m.name} 的申请')),
      );
      _loadMembers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('操作失败，请重试')),
      );
    }
  }

  Future<void> _reject(CourseMember m) async {
    final ok = await _courseService.auditApplication(
      courseId: widget.course.id,
      applicationId: m.id,
      action: 'REJECT',
    );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已拒绝 ${m.name} 的申请')),
      );
      _loadMembers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('操作失败，请重试')),
      );
    }
  }

  Future<void> _removeStudent(CourseMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认移除'),
        content: Text('确定要将 ${m.name} 移出课程吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
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
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已移除 ${m.name}')),
      );
      _loadMembers();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('移除失败，请重试')),
      );
    }
  }

  void _showInviteDialog() {
    _inviteController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('邀请学生'),
        content: TextField(
          controller: _inviteController,
          decoration: const InputDecoration(
            labelText: '输入学生用户名',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_search),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
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
      // 调用邀请接口：POST /courses/{id}/students/invite?username=xxx
      final ok = await _courseService.inviteStudent(
        courseId: widget.course.id,
        username: username,
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已成功邀请 $username')),
        );
        _loadMembers();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('邀请失败，用户 $username 可能不存在或已在课程中')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('邀请出错：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorText != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadMembers,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    } else if (_members.isEmpty) {
      body = const Center(child: Text('暂无学生'));
    } else {
      body = RefreshIndicator(
        onRefresh: _loadMembers,
        child: ListView.builder(
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final m = _members[index];
            final isPending = m.status == 'PENDING';

            return ListTile(
              leading: CircleAvatar(
                child: Text(m.name.isNotEmpty ? m.name.characters.first : '?'),
              ),
              title: Text(m.name),
              subtitle: Text('${m.phone} · ${_statusText(m.status)}'),
              trailing: isPending
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _approve(m),
                          child: const Text('通过'),
                        ),
                        TextButton(
                          onPressed: () => _reject(m),
                          child: const Text(
                            '拒绝',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: Colors.red),
                      tooltip: '移除学生',
                      onPressed: () => _removeStudent(m),
                    ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('学生管理 - ${widget.course.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: '邀请学生',
            onPressed: _showInviteDialog,
          ),
        ],
      ),
      body: body,
    );
  }
}
