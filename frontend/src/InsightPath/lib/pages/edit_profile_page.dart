import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _auth = AuthService();
  final _picker = ImagePicker();
  final _bioController = TextEditingController();
  final _schoolController = TextEditingController();

  String _username = '';
  String? _avatarUrl;
  String? _bgUrl;
  bool _saving = false;

  String? _schoolName;

  File? _avatarFile;
  File? _bgFile;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _schoolController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await _auth.getCurrentUser();
    if (!mounted) return;

    setState(() {
      _username = (user?['nickname'] as String?) ?? (user?['username'] as String?) ?? '用户';
      _avatarUrl = user?['avatar'] as String?;
      _bgUrl = user?['bg_url'] as String?;
      _bioController.text = user?['bio'] as String? ?? '';
      _schoolName = user?['school'] as String?;
      _schoolController.text = _schoolName ?? '';
    });
  }

  Future<void> _pickAvatar() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _pickBg() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;
    setState(() => _bgFile = File(picked.path));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? avatarUrl = _avatarUrl;
      String? bgUrl = _bgUrl;

      if (_avatarFile != null) {
        avatarUrl = await _auth.uploadImageFile(_avatarFile!);
      }
      if (_bgFile != null) {
        bgUrl = await _auth.uploadImageFile(_bgFile!);
      }

      final ok = await _auth.updateUserProfile(
        school: _schoolController.text.trim(),
        avatarUrl: avatarUrl,
        bgUrl: bgUrl,
        bio: _bioController.text.trim(),
      );

      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请稍后重试')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgPreview = _bgFile != null
        ? DecorationImage(image: FileImage(_bgFile!), fit: BoxFit.cover)
        : (_bgUrl != null && _bgUrl!.isNotEmpty
            ? DecorationImage(image: NetworkImage(_bgUrl!), fit: BoxFit.cover)
            : null);

    final avatarImage = _avatarFile != null
        ? FileImage(_avatarFile!) as ImageProvider
        : ((_avatarUrl != null && _avatarUrl!.isNotEmpty) ? NetworkImage(_avatarUrl!) : null);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('编辑资料')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: const Border.fromBorderSide(BorderSide(color: Color(0xFFEEEFF2))),
                image: bgPreview,
              ),
              child: InkWell(
                onTap: _pickBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '点击上传背景图',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Align(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white,
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? Text(
                            _username.isNotEmpty ? _username.characters.first.toUpperCase() : '?',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: InkWell(
                      onTap: _pickAvatar,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            TextField(
              controller: _schoolController,
              maxLength: 64,
              decoration: const InputDecoration(
                labelText: '学校',
                hintText: '请输入你的学校（可留空）',
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _bioController,
              maxLines: 5,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: '个人简介 (bio)',
                hintText: '介绍一下你自己吧…',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('保存修改', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
