import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'register_page.dart';
import 'student_home_page.dart';
import 'teacher_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  String _userType = 'STUDENT';
  bool _isLoading = false;
  bool _passwordVisible = false;
  String? _statusMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _statusMessage = '用户名和密码不能为空');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    try {
      final ok = await _authService.login(username: username, password: password);
      if (!mounted) return;

      if (!ok) {
        setState(() => _statusMessage = '登录失败，请检查用户名和密码');
        return;
      }

        final user = await _authService.getCurrentUser();
        final role = user?['role'] as String? ?? 'STUDENT';
      if (!mounted) return;

        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
          builder: (_) => role == 'TEACHER'
                    ? const TeacherHomePage()
                    : const StudentHomePage(),
          ),
        );
    } catch (e) {
      setState(() => _statusMessage = '登录出错：$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
              children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
            ),
          ),
          Positioned(
            top: -50,
            right: -40,
            child: _bubble(220, 0.07),
          ),
          Positioned(
            top: 40,
            right: 36,
            child: _bubble(90, 0.10),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _brandHeader(),
                  const SizedBox(height: 30),
                  _glassCard(),
                  const SizedBox(height: 20),
                  Text(
                    '专注 · 探索 · 成长',
                        style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.8,
                      color: AppTheme.bodyColor.withValues(alpha: 0.65),
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

  Widget _brandHeader() {
    return Column(
                      children: [
        Container(
          width: 76,
          height: 76,
                              decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                                ),
          child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 14),
        const Text(
          '灵犀知径',
                                style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'AI 赋能 · 智慧学习路径导航',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: .5,
            color: Colors.white.withValues(alpha: 0.86),
                                ),
                              ),
      ],
    );
  }

  Widget _glassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                            child: Container(
          width: double.infinity,
                              decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(AppTheme.radiusXL),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 26,
                offset: const Offset(0, 10),
                        ),
                      ],
                    ),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.bg,
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: Row(
                    children: [
                      _roleTab('STUDENT', '学生'),
                      _roleTab('TEACHER', '讲师'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  '欢迎回来',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.titleColor),
                ),
                const SizedBox(height: 4),
                const Text('请登录您的账号', style: TextStyle(fontSize: 13, color: AppTheme.bodyColor)),
                const SizedBox(height: 20),
                TextField(
                  controller: _usernameController,
                  enabled: !_isLoading,
                  decoration: const InputDecoration(
                    hintText: '用户名',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                      ),
                    ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    hintText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 20,
                        color: AppTheme.hintColor,
                      ),
                      onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                    ),
                  ),
                ),
                if (_statusMessage != null) ...[
                const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                    child: Text(
                            _statusMessage!,
                            style: const TextStyle(fontSize: 13, color: AppTheme.errorColor),
                      ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('登 录'),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                    const Text('还没有账号？', style: TextStyle(fontSize: 13, color: AppTheme.bodyColor)),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const RegisterPage()),
                              ),
                        child: const Text(
                          '立即注册',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary),
                        ),
                      ),
                    ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleTab(String type, String label) {
    final selected = _userType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _userType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
                              ),
          child: Center(
                            child: Text(
              label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primary : AppTheme.hintColor,
                              ),
                            ),
                          ),
                        ),
                      ),
    );
  }

  Widget _bubble(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}
