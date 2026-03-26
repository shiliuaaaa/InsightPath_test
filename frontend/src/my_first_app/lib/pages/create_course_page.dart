import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/course_service.dart';
import '../utils/app_theme.dart';

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _coverController = TextEditingController();
  final _schoolIdController = TextEditingController(text: '1');

  String _status = 'PRERELEASE';
  String _visibility = 'PUBLIC';
  String _permission = 'OPEN';

  bool _isSubmitting = false;
  String? _errorText;

  final CourseService _courseService = CourseService();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _coverController.dispose();
    _schoolIdController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final schoolId = int.tryParse(_schoolIdController.text) ?? 0;
      final Course? created = await _courseService.createCourse(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        coverImage: _coverController.text.trim(),
        schoolId: schoolId,
        status: _status,
        visibility: _visibility,
        permission: _permission,
      );

      if (!mounted) return;
      if (created == null) {
        setState(() => _errorText = '创建失败，请检查网络或权限');
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('课程创建成功')),
      );
      Navigator.pop(context, created);
    } catch (e) {
      setState(() => _errorText = '创建失败：$e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('新建课程')),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 200,
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(AppTheme.radiusL),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
                  ),
                  padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '课程标题'),
                          validator: (v) => v == null || v.isEmpty ? '请输入课程标题' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: '课程简介'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _coverController,
                          decoration: const InputDecoration(labelText: '封面图片 URL（可先留空）'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                          initialValue: _status,
                decoration: const InputDecoration(labelText: '课程状态'),
                items: const [
                            DropdownMenuItem(value: 'PRERELEASE', child: Text('未开课')),
                            DropdownMenuItem(value: 'INPROGRESS', child: Text('进行中')),
                            DropdownMenuItem(value: 'COMPLETED', child: Text('已结课')),
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
                            DropdownMenuItem(value: 'PUBLIC', child: Text('公开')),
                            DropdownMenuItem(value: 'RESTRICTED', child: Text('限制')),
                            DropdownMenuItem(value: 'PRIVATE', child: Text('私有')),
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
                            DropdownMenuItem(value: 'OPEN', child: Text('直接加入')),
                            DropdownMenuItem(value: 'APPLY', child: Text('申请加入')),
                ],
                onChanged: (v) {
                            if (v != null) setState(() => _permission = v);
                },
              ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 14),
                          Text(_errorText!, style: const TextStyle(color: AppTheme.errorColor)),
                        ],
                        const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                          height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                                : const Text('创建课程'),
                ),
              ),
            ],
          ),
        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
