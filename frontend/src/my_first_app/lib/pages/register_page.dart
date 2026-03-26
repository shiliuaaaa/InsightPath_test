import 'dart:async';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
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

  // mock 模式下后端返回的验证码（显示在界面上方便测试）
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
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    if (!phoneRegex.hasMatch(phone)) {
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
    // mock 模式：显示验证码方便测试
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

  void _goToLogin() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = _role == 'TEACHER';

    return Scaffold(
      appBar: AppBar(title: const Text('注册账号')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  // ── 用户名 ──
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: '用户名'),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '请输入用户名' : null,
                  ),
                  const SizedBox(height: 12),

                  // ── 密码 ──
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: '密码',
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) =>
                        (v == null || v.length < 4) ? '至少 4 位密码' : null,
                  ),
                  const SizedBox(height: 12),

                  // ── 确认密码 ──
                  TextFormField(
                    controller: _confirmController,
                    decoration: InputDecoration(
                      labelText: '确认密码',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm
                              ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    obscureText: _obscureConfirm,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请再次输入密码';
                      if (v != _passwordController.text) return '两次密码不一致';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── 手机号 ──
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: '手机号',
                      hintText: '请输入 11 位手机号',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v == null || v.isEmpty) return '请输入手机号';
                      if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(v)) {
                        return '手机号格式不正确';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),

                  // ── 验证码 + 发送按钮 ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _smsCodeController,
                          decoration: const InputDecoration(
                            labelText: '验证码',
                            hintText: '6 位数字',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return '请输入验证码';
                            if (!RegExp(r'^\d{6}$').hasMatch(v)) {
                              return '验证码必须是 6 位数字';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          width: 110,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_sendingCode || _countdown > 0)
                                ? null
                                : _sendCode,
                            child: _sendingCode
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Text(_countdown > 0
                                    ? '${_countdown}s 后重发'
                                    : '发送验证码'),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // mock 模式下显示验证码提示
                  if (_mockCode != null) ...[  
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        border: Border.all(color: Colors.green.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '演示模式验证码：$_mockCode',
                        style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ── 角色选择 ──
                  const Text(
                    '角色选择',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'TEACHER',
                              label: Text('老师'),
                              icon: Icon(Icons.school),
                            ),
                            ButtonSegment<String>(
                              value: 'STUDENT',
                              label: Text('学生'),
                              icon: Icon(Icons.person),
                            ),
                          ],
                          selected: {_role},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) return;
                            setState(() => _role = selection.first);
                          },
                          showSelectedIcon: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '所属学校：武汉大学（固定，当前项目不区分其他学校）',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),

                  // ── 注册按钮 ──
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _registering ? null : _handleRegister,
                      child: _registering
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('注册'),
                    ),
                  ),
                  TextButton(
                    onPressed: _goToLogin,
                    child: const Text('已有账号？去登录'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isTeacher
                        ? '提示：老师注册后登录将进入教师端首页；学生注册后登录会进入学生端首页。'
                        : '提示：学生账号适合体验选课、加入课程等功能。',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
