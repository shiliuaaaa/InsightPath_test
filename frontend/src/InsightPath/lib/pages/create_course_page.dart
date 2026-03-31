import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
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

  File? _coverFile;

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
      String coverImage = _coverController.text.trim();
      if (_coverFile != null) {
        final uploaded = await _courseService.uploadCourseCover(
          file: _coverFile!,
          fileName: _coverFile!.path.split('/').last,
        );
        if (uploaded == null) {
          throw Exception('课程封面上传失败');
        }
        coverImage = uploaded;
      }

      final Course? created = await _courseService.createCourse(
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        coverImage: coverImage,
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

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) {
      return;
    }
    setState(() {
      _coverFile = File(result.files.first.path!);
      _coverController.text = _coverFile!.path.split('/').last;
    });
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
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: '课程封面（本地上传）',
                            hintText: '请选择图片文件',
                            suffixIcon: IconButton(
                              onPressed: _pickCoverImage,
                              icon: const Icon(Icons.upload_file_rounded),
                              tooltip: '选择封面图片',
                            ),
                          ),
              ),
              if (_coverFile != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '已选择：${_coverFile!.path.split('/').last}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.bodyColor),
                  ),
                ),
              ],
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
