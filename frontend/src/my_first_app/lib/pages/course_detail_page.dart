import 'package:flutter/material.dart';
import '../models/course.dart';
import '../services/course_service.dart';
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
  bool _processing = false;
  final _courseService = CourseService();

  @override
  void initState() {
    super.initState();
    _joined = widget.course.isJoined;
    _pending = widget.course.isPendingApproval;
  }

  String _statusText(String status) {
    switch (status) {
      case 'PRE_RELEASE':
        return '未开课';
      case 'IN_PROGRESS':
        return '进行中';
      case 'COMPLETED':
        return '已结课';
      case 'HIDDEN':
        return '已隐藏';
      default:
        return status;
    }
  }

  Future<void> _handleJoinOrApply() async {
    if (_joined || _pending) return;

    setState(() => _processing = true);

    try {
      final status = await _courseService.enrollCourse(
        widget.course.id,
        applyReason: null,
      );

      if (!mounted) return;

      if (status == 'JOINED') {
        setState(() {
          _joined = true;
          widget.course.isJoined = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已成功加入课程')),
        );
      } else if (status == 'PENDING_APPROVAL') {
        setState(() {
          _pending = true;
          widget.course.isPendingApproval = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('申请已提交，请等待教师审核')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('操作失败，请稍后重试')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('出错：$e')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final canJoinDirect = course.permission == 'OPEN';

    // 顶部状态文案
    String topHint;
    Color topColor;
    if (_joined) {
      topHint = '你已加入本课程，可以直接学习';
      topColor = Colors.green;
    } else if (_pending) {
      topHint = '已提交加入申请，待老师审核';
      topColor = Colors.orange;
    } else {
      topHint = canJoinDirect
          ? '本课程可直接加入学习'
          : '本课程需要申请加入，经老师审核后才能学习';
      topColor = canJoinDirect ? Colors.green : Colors.orange;
    }

    // 主按钮
    Widget mainButton;
    if (_joined) {
      mainButton = const Text(
        '已加入课程',
        style: TextStyle(color: Colors.green),
      );
    } else if (_pending) {
      mainButton = const Text(
        '已申请，等待老师审核',
        style: TextStyle(color: Colors.orange),
      );
    } else {
      mainButton = SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _processing ? null : _handleJoinOrApply,
          child: _processing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(canJoinDirect ? '加入课程' : '申请加入'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(course.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  child: Text(course.title.characters.first),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${course.teacherName} · ${_statusText(course.status)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              topHint,
              style: TextStyle(color: topColor),
            ),
            const SizedBox(height: 24),
            mainButton,
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _joined
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CourseInnerPage(course: course),
                          ),
                        );
                      }
                    : null,
                style: _joined
                    ? null
                    : ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.grey.shade600,
                      ),
                child: Text(_joined ? '进入课程' : '加入后才能进入课程'),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '课程简介',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              course.description.isNotEmpty ? course.description : '暂无简介',
            ),
          ],
        ),
      ),
    );
  }
}
