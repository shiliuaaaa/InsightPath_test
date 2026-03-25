import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/course_service.dart';

class CourseSettingsPage extends StatefulWidget {
  final Course course;

  const CourseSettingsPage({super.key, required this.course});

  @override
  State<CourseSettingsPage> createState() => _CourseSettingsPageState();
}

class _CourseSettingsPageState extends State<CourseSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _coverController;

  late String _status;
  late String _visibility;
  late String _permission;

  bool _isSaving = false;
  String? _errorText;

  final CourseService _courseService = CourseService();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.course.title);
    _descController = TextEditingController(); // 现在还没有 description 字段，先留空
    _coverController = TextEditingController(text: widget.course.coverImage);

    _status = widget.course.status;
    _visibility = widget.course.visibility;
    _permission = widget.course.permission;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _coverController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final ok = await _courseService.updateCourseSettings(
        courseId: widget.course.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        coverImage: _coverController.text.trim(),
        status: _status,
        visibility: _visibility,
        permission: _permission,
      );

      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('课程设置已保存')),
        );
        Navigator.pop(context, true);
      } else {
        setState(() {
          _errorText = '保存失败，请检查网络或权限';
        });
      }
    } catch (e) {
      setState(() {
        _errorText = '保存失败：$e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;

    return Scaffold(
      appBar: AppBar(
        title: Text('课程设置 - ${course.title}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '课程标题'),
                validator: (v) =>
                    v == null || v.isEmpty ? '请输入课程标题' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: '课程简介（暂时本地占位）'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _coverController,
                decoration:
                    const InputDecoration(labelText: '封面图片 URL（可为空）'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: '课程状态'),
                items: const [
                  DropdownMenuItem(
                    value: 'PRE_RELEASE',
                    child: Text('未开课'),
                  ),
                  DropdownMenuItem(
                    value: 'IN_PROGRESS',
                    child: Text('进行中'),
                  ),
                  DropdownMenuItem(
                    value: 'COMPLETED',
                    child: Text('已结课'),
                  ),
                  DropdownMenuItem(
                    value: 'HIDDEN',
                    child: Text('隐藏'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: '可见性'),
                items: const [
                  DropdownMenuItem(
                    value: 'PUBLIC',
                    child: Text('公开'),
                  ),
                  DropdownMenuItem(
                    value: 'RESTRICTED',
                    child: Text('限制'),
                  ),
                  DropdownMenuItem(
                    value: 'PRIVATE',
                    child: Text('私有'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _visibility = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _permission,
                decoration: const InputDecoration(labelText: '加入方式'),
                items: const [
                  DropdownMenuItem(
                    value: 'OPEN',
                    child: Text('直接加入'),
                  ),
                  DropdownMenuItem(
                    value: 'APPLY',
                    child: Text('申请加入'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _permission = v);
                },
              ),
              const SizedBox(height: 24),
              if (_errorText != null)
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
