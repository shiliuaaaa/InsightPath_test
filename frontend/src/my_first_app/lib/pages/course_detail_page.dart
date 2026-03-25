import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../utils/app_theme.dart';
import 'course_inner_page.dart';

class CourseDetailPage extends StatefulWidget {
  final Course course;
  const CourseDetailPage({super.key, required this.course});

  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  late bool _joined;
  late bool _pending;
  late bool _isOwner;
  bool _processing = false;
  final _courseService = CourseService();

  @override
  void initState() {
    super.initState();
    _joined = widget.course.isJoined;
    _pending = widget.course.isPendingApproval;
    _isOwner = widget.course.isOwner;
  }

  String _statusText(String status) {
    switch (status) {
      case 'PRE_RELEASE': return '未开课';
      case 'IN_PROGRESS': return '进行中';
      case 'COMPLETED': return '已结课';
      case 'HIDDEN': return '已隐藏';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'IN_PROGRESS': return AppTheme.successColor;
      case 'COMPLETED': return AppTheme.hintColor;
      case 'HIDDEN': return AppTheme.errorColor;
      default: return AppTheme.secondary;
    }
  }

  Future<void> _handleJoinOrApply() async {
    if (_joined || _pending || _isOwner) return;
    setState(() => _processing = true);
    try {
      final status = await _courseService.enrollCourse(widget.course.id);
      if (!mounted) return;
      if (status == 'JOINED') {
        setState(() { _joined = true; widget.course.isJoined = true; });
        _showSnack('已成功加入课程', success: true);
      } else if (status == 'PENDING_APPROVAL') {
        setState(() { _pending = true; widget.course.isPendingApproval = true; });
        _showSnack('申请已提交，请等待教师审核');
      } else {
        _showSnack('操作失败，请稍后重试', success: false);
      }
    } catch (e) {
      if (mounted) _showSnack('出错：$e', success: false);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showSnack(String msg, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _enterCourse() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CourseInnerPage(course: widget.course),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final bool canEnter = _isOwner || _joined;
    final bool canJoinDirect = course.permission == 'OPEN';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
              centerTitle: false,
              title: Text(course.title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1A4F95), Color(0xFF3AAFA9)],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            course.title.isNotEmpty ? course.title[0] : '?',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                        child: const Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Text(course.teacherName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.titleColor)),
                      const Spacer(),
                      _statusBadge(course.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildStatusBanner(canJoinDirect),
                  const SizedBox(height: 20),
                  _buildActionButtons(canEnter, canJoinDirect),
                  const SizedBox(height: 28),
                  const Text('课程简介',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.titleColor)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFF0F0F5))),
                    ),
                    child: Text(
                      course.description.isNotEmpty ? course.description : '暂无简介',
                      style: const TextStyle(fontSize: 14, color: AppTheme.bodyColor, height: 1.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(_statusText(status),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool canJoinDirect) {
    String hint;
    Color color;
    IconData icon;

    if (_isOwner) {
      hint = '你是本课程的创建者，可直接管理和进入课程';
      color = AppTheme.primary;
      icon = Icons.admin_panel_settings_outlined;
    } else if (_joined) {
      hint = '你已加入本课程，可以直接进入学习';
      color = AppTheme.successColor;
      icon = Icons.check_circle_outline_rounded;
    } else if (_pending) {
      hint = '已提交加入申请，等待教师审核通过后可进入';
      color = const Color(0xFFF59E0B);
      icon = Icons.hourglass_empty_rounded;
    } else {
      hint = canJoinDirect ? '本课程可直接加入学习' : '本课程需申请加入，经教师审核后才能学习';
      color = canJoinDirect ? AppTheme.successColor : const Color(0xFFF59E0B);
      icon = canJoinDirect ? Icons.lock_open_rounded : Icons.lock_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(hint,
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool canEnter, bool canJoinDirect) {
    if (canEnter) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: _enterCourse,
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: Text(_isOwner ? '管理课程' : '进入课程'),
        ),
      );
    }
    if (_pending) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.borderColor,
            foregroundColor: AppTheme.hintColor,
          ),
          child: const Text('等待审核中...'),
        ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _processing ? null : _handleJoinOrApply,
        style: ElevatedButton.styleFrom(
          backgroundColor: canJoinDirect ? AppTheme.primary : AppTheme.secondary,
        ),
        child: _processing
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(canJoinDirect ? '立即加入' : '申请加入'),
      ),
    );
  }
}
