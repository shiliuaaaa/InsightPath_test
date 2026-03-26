import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _smsCodeController = TextEditingController();
  final _auth = AuthService();

  bool _registering = false;
  bool _sendingCode = false;
  int _countdown = 0;
  Timer? _timer;
  String _role = 'TEACHER';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _mockCode;

  @override
  void dispose() {
    _timer?.cancel();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    _smsCodeController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _countdown = 0);
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _sendCode() async {
    final phone = _phoneController.text.trim();
    if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先输入正确的手机号')),
      );
      return;
    }

    setState(() {
      _sendingCode = true;
      _mockCode = null;
    });

    final code = await _auth.sendSmsCode(phone: phone, type: 'REGISTER');

    if (!mounted) return;
    setState(() => _sendingCode = false);

    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('验证码发送失败，请稍后重试')),
      );
      return;
    }

    _startCountdown();
    if (code.isNotEmpty) {
      setState(() => _mockCode = code);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('验证码已发送（演示模式：见提示）')),
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _registering = true);

    final ok = await _auth.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
      smsCode: _smsCodeController.text.trim(),
      role: _role,
    );

    if (!mounted) return;
    setState(() => _registering = false);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('注册失败，用户名/手机号已存在或验证码错误')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('注册成功，请登录')),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('注册账号')),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.93),
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                          const Text(
                            '创建新账号',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.titleColor),
                          ),
                          const SizedBox(height: 6),
                          const Text('填写信息，快速开始你的灵犀知径之旅', style: TextStyle(fontSize: 13, color: AppTheme.bodyColor)),
                          const SizedBox(height: 20),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: '用户名'),
                            validator: (v) => (v == null || v.isEmpty) ? '请输入用户名' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                            obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: '密码',
                      suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                            validator: (v) => (v == null || v.length < 4) ? '至少 4 位密码' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController,
                            obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: '确认密码',
                      suffixIcon: IconButton(
                                icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请再次输入密码';
                      if (v != _passwordController.text) return '两次密码不一致';
                      return null;
                    },
                  ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _phoneController,
                            decoration: const InputDecoration(labelText: '手机号', hintText: '请输入 11 位手机号'),
                            keyboardType: TextInputType.phone,
                            validator: (v) {
                              if (v == null || v.isEmpty) return '请输入手机号';
                              if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v)) return '手机号格式不正确';
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                  Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                                child: TextFormField(
                                  controller: _smsCodeController,
                                  decoration: const InputDecoration(labelText: '验证码', hintText: '6 位数字'),
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return '请输入验证码';
                                    if (!RegExp(r'^\d{6}$').hasMatch(v)) return '验证码必须是 6 位数字';
                                    return null;
                          },
                        ),
                      ),
                              const SizedBox(width: 8),
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 122,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: (_sendingCode || _countdown > 0) ? null : _sendCode,
                                    child: _sendingCode
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : Text(_countdown > 0 ? '${_countdown}s 后重发' : '发送验证码'),
                                  ),
                        ),
                      ),
                    ],
                  ),
                          if (_mockCode != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withValues(alpha: 0.08),
                                border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '演示模式验证码：$_mockCode',
                                style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Text('角色选择', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment<String>(value: 'TEACHER', label: Text('老师'), icon: Icon(Icons.school_rounded)),
                              ButtonSegment<String>(value: 'STUDENT', label: Text('学生'), icon: Icon(Icons.person_rounded)),
                            ],
                            selected: {_role},
                            onSelectionChanged: (selection) {
                              if (selection.isNotEmpty) {
                                setState(() => _role = selection.first);
                              }
                            },
                            showSelectedIcon: false,
                  ),
                          const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                            height: 52,
                    child: ElevatedButton(
                      onPressed: _registering ? null : _handleRegister,
                      child: _registering
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('注 册'),
                    ),
                  ),
                  TextButton(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const LoginPage()),
                            ),
                    child: const Text('已有账号？去登录'),
                  ),
                        ],
                      ),
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
