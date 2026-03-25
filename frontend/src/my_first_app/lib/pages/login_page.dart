import 'package:flutter/material.dart';

import '../services/auth_service.dart';
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
  String? _errorMessage;

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
      setState(() {
        _errorMessage = '用户名和密码不能为空';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _authService.login(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (result) {
        final user = await _authService.getCurrentUser();
        final role = user?['role'] as String? ?? 'STUDENT';
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                role == 'TEACHER'
                    ? const TeacherHomePage()
                    : const StudentHomePage(),
          ),
        );
      } else {
        setState(() {
          _errorMessage = '登录失败，请检查用户名和密码';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '登录出错：$e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo 和标题
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1F77D2),
                              Color(0xFF165BAD),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: Colors.white,
                          size: 60,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '灵犀知径',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F77D2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '智能辅导，知识相伴',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF757575),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // 用户类型选择按钮
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 2,
                      ),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _userType = 'STUDENT');
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  bottomLeft: Radius.circular(8),
                                ),
                                color: _userType == 'STUDENT'
                                    ? const Color(0xFF1F77D2)
                                    : Colors.white,
                              ),
                              child: Text(
                                '学生',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _userType == 'STUDENT'
                                      ? Colors.white
                                      : const Color(0xFF757575),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _userType = 'TEACHER');
                            },
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                color: _userType == 'TEACHER'
                                    ? const Color(0xFF1F77D2)
                                    : Colors.white,
                              ),
                              child: Text(
                                '讲师',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _userType == 'TEACHER'
                                      ? Colors.white
                                      : const Color(0xFF757575),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // 用户名输入框
                TextField(
                  controller: _usernameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    hintText: '用户名',
                    prefixIcon: const Icon(Icons.person_outline,
                        color: Color(0xFF1F77D2)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF1F77D2),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),

                const SizedBox(height: 16),

                // 密码输入框
                TextField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: !_passwordVisible,
                  decoration: InputDecoration(
                    hintText: '密码',
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: Color(0xFF1F77D2)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: const Color(0xFF1F77D2),
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF1F77D2),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),

                const SizedBox(height: 12),

                // 错误/成功提示
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_errorMessage?.contains('成功') ?? false)
                          ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                          : const Color(0xFFF44336).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (_errorMessage?.contains('成功') ?? false)
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _errorMessage ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: (_errorMessage?.contains('成功') ?? false)
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // 登录按钮
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F77D2),
                      disabledBackgroundColor:
                          const Color(0xFF1F77D2).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            '登录',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                // 注册链接
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '没有账号？',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF757575),
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () {
                                _showRegisterDialog();
                              },
                        child: const Text(
                          '立即注册',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1F77D2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRegisterDialog() {
    final regUsernameController = TextEditingController();
    final regPasswordController = TextEditingController();
    final regConfirmPasswordController = TextEditingController();
    final regPhoneController = TextEditingController();
    final regSmsController = TextEditingController();
    String regUserType = _userType;
    bool regPasswordVisible = false;
    bool regConfirmPasswordVisible = false;
    bool sendingCode = false;
    bool registering = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('创建账号'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 角色选择
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E0E0), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => regUserType = 'STUDENT'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(7),
                                bottomLeft: Radius.circular(7),
                              ),
                              color: regUserType == 'STUDENT'
                                  ? const Color(0xFF1F77D2)
                                  : Colors.transparent,
                            ),
                            child: Text('学生',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: regUserType == 'STUDENT' ? Colors.white : const Color(0xFF757575),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => regUserType = 'TEACHER'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(7),
                                bottomRight: Radius.circular(7),
                              ),
                              color: regUserType == 'TEACHER'
                                  ? const Color(0xFF1F77D2)
                                  : Colors.transparent,
                            ),
                            child: Text('讲师',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: regUserType == 'TEACHER' ? Colors.white : const Color(0xFF757575),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // 用户名
                TextField(
                  controller: regUsernameController,
                  decoration: InputDecoration(
                    labelText: '用户名（4-32位字母数字）',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                // 密码
                TextField(
                  controller: regPasswordController,
                  obscureText: !regPasswordVisible,
                  decoration: InputDecoration(
                    labelText: '密码（至少4位）',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(regPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => regPasswordVisible = !regPasswordVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 确认密码
                TextField(
                  controller: regConfirmPasswordController,
                  obscureText: !regConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: '确认密码',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(regConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => regConfirmPasswordVisible = !regConfirmPasswordVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 手机号 + 发送验证码
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: regPhoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: '手机号',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          prefixIcon: const Icon(Icons.phone_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: sendingCode
                            ? null
                            : () async {
                                final phone = regPhoneController.text.trim();
                                if (phone.isEmpty) {
                                  setDialogState(() => dialogError = '请先输入手机号');
                                  return;
                                }
                                setDialogState(() {
                                  sendingCode = true;
                                  dialogError = null;
                                });
                                final mockCode = await _authService.sendSmsCode(
                                  phone: phone,
                                  type: 'REGISTER',
                                );
                                setDialogState(() {
                                  sendingCode = false;
                                  if (mockCode == null) {
                                    dialogError = '发送失败，请重试';
                                  } else if (mockCode.isNotEmpty) {
                                    dialogError = '【演示模式】验证码：$mockCode';
                                  } else {
                                    dialogError = '验证码已发送';
                                  }
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1F77D2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: sendingCode
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('发送验证码', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 验证码输入
                TextField(
                  controller: regSmsController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '6位验证码',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    prefixIcon: const Icon(Icons.sms_outlined),
                  ),
                ),
                if (dialogError != null) ...[  
                  const SizedBox(height: 8),
                  Text(
                    dialogError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: (dialogError!.contains('演示模式') || dialogError!.contains('已发送'))
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF44336),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: registering
                  ? null
                  : () async {
                      if (regPasswordController.text != regConfirmPasswordController.text) {
                        setDialogState(() => dialogError = '两次密码不一致');
                        return;
                      }
                      if (regSmsController.text.trim().length != 6) {
                        setDialogState(() => dialogError = '请输入6位验证码');
                        return;
                      }
                      setDialogState(() {
                        registering = true;
                        dialogError = null;
                      });
                      final ok = await _authService.register(
                        username: regUsernameController.text.trim(),
                        password: regPasswordController.text,
                        phone: regPhoneController.text.trim(),
                        smsCode: regSmsController.text.trim(),
                        role: regUserType,
                      );
                      setDialogState(() => registering = false);
                      if (ok) {
                        if (context.mounted) Navigator.pop(context);
                        setState(() => _errorMessage = '注册成功！请用新账号登录');
                      } else {
                        setDialogState(() => dialogError = '注册失败，用户名可能已存在或验证码错误');
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F77D2)),
              child: registering
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('注册'),
            ),
          ],
        ),
      ),
    );
  }
}
