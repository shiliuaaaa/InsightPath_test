import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/course_service.dart';
import '../utils/app_theme.dart';

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

  File? _coverFile;

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
    _descController = TextEditingController();
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
      String coverImage = _coverController.text.trim();
      if (_coverFile != null) {
        final uploaded = await _courseService.uploadCourseCover(
          file: _coverFile!,
          fileName: _coverFile!.path.split('/').last,
          courseId: widget.course.id,
        );
        if (uploaded == null) {
          throw Exception('课程封面上传失败');
        }
        coverImage = uploaded;
      }

      final ok = await _courseService.updateCourseSettings(
        courseId: widget.course.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        coverImage: coverImage,
        status: _status,
        visibility: _visibility,
        permission: _permission,
      );

      if (!mounted) return;
      if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('课程设置已保存')),
      );
        Navigator.pop(context, widget.course);
      } else {
        setState(() => _errorText = '保存失败，请检查网络或权限');
      }
    } catch (e) {
      setState(() => _errorText = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _handleDeleteCourse() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除课程'),
        content: const Text('删除后课程、栏目、课件与成员记录将被清理，且无法恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('确认删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    final ok = await _courseService.deleteCourse(widget.course.id);
    if (!mounted) return;

    setState(() => _isSaving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('课程已删除')),
      );
      Navigator.pop(context, 'deleted');
      return;
    }

    setState(() => _errorText = '删除失败，请稍后重试');
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
    final course = widget.course;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: Text('课程设置 · ${course.title}')),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 190,
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
                decoration: const InputDecoration(labelText: '课程简介（暂时本地占位）'),
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
                            DropdownMenuItem(value: 'PRE_RELEASE', child: Text('未开课')),
                            DropdownMenuItem(value: 'IN_PROGRESS', child: Text('进行中')),
                            DropdownMenuItem(value: 'COMPLETED', child: Text('已结课')),
                            DropdownMenuItem(value: 'HIDDEN', child: Text('隐藏')),
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
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                                : const Text('保存设置'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _handleDeleteCourse,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    side: const BorderSide(color: AppTheme.errorColor),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('删除课程'),
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
