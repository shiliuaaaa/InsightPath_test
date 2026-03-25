import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';
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
  bool _isSuccess = false;

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
      setState(() { _statusMessage = '用户名和密码不能为空'; _isSuccess = false; });
      return;
    }
    setState(() { _isLoading = true; _statusMessage = null; });
    try {
      final result = await _authService.login(username: username, password: password);
      if (!mounted) return;
      if (result) {
        final user = await _authService.getCurrentUser();
        final role = user?['role'] as String? ?? 'STUDENT';
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => role == 'TEACHER' ? const TeacherHomePage() : const StudentHomePage(),
        ));
      } else {
        setState(() { _statusMessage = '登录失败，请检查用户名和密码'; _isSuccess = false; });
      }
    } catch (e) {
      setState(() { _statusMessage = '登录出错：$e'; _isSuccess = false; });
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
          // 顶部装饰背景
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 280,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A4F95), Color(0xFF1E6BB8)],
                ),
              ),
            ),
          ),
          // 装饰圆形
          Positioned(
            top: -60, right: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 40, right: 40,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // 主内容
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  // Logo 区
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.auto_stories_rounded, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 16),
                  const Text('灵犀知径',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 2),
                  ),
                  const SizedBox(height: 6),
                  Text('AI 赋能 · 智慧学习路径导航',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 40),
                  // 登录卡片
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 角色切换
                          Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppTheme.bg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                _roleTab('STUDENT', '学生'),
                                _roleTab('TEACHER', '讲师'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text('欢迎回来',
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                              color: AppTheme.titleColor),
                          ),
                          const SizedBox(height: 4),
                          const Text('请登录您的账号',
                            style: TextStyle(fontSize: 13, color: AppTheme.bodyColor),
                          ),
                          const SizedBox(height: 24),
                          // 用户名
                          TextField(
                            controller: _usernameController,
                            enabled: !_isLoading,
                            decoration: const InputDecoration(
                              hintText: '用户名',
                              prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.primary, size: 20),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // 密码
                          TextField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: !_passwordVisible,
                            decoration: InputDecoration(
                              hintText: '密码',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.primary, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  color: AppTheme.hintColor, size: 20,
                                ),
                                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                              ),
                            ),
                          ),
                          // 状态提示
                          if (_statusMessage != null) ...[  
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: (_isSuccess ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (_isSuccess ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                                    size: 16,
                                    color: _isSuccess ? AppTheme.successColor : AppTheme.errorColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_statusMessage!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: _isSuccess ? AppTheme.successColor : AppTheme.errorColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          // 登录按钮
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading
                                  ? const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('登 录'),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // 注册入口
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('还没有账号？', style: TextStyle(fontSize: 13, color: AppTheme.bodyColor)),
                              TextButton(
                                onPressed: _isLoading ? null : _showRegisterDialog,
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                                child: const Text('立即注册',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                    color: AppTheme.secondary)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // 底部标语
                  Text('专注 · 探索 · 成长',
                    style: TextStyle(fontSize: 12, color: AppTheme.bodyColor.withValues(alpha: 0.6), letterSpacing: 2),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
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
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primary : AppTheme.hintColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showRegisterDialog() {
    final regUsernameCtrl = TextEditingController();
    final regPasswordCtrl = TextEditingController();
    final regConfirmCtrl = TextEditingController();
    final regPhoneCtrl = TextEditingController();
    final regSmsCtrl = TextEditingController();
    String regRole = _userType;
    bool regPwdVisible = false;
    bool regConfirmVisible = false;
    bool sendingCode = false;
    bool registering = false;
    String? dialogMsg;
    bool dialogSuccess = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_add_rounded, color: AppTheme.primary),
                    const SizedBox(width: 10),
                    const Text('创建账号',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.titleColor)),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 20, color: AppTheme.hintColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // 角色
                Container(
                  height: 40,
                  decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      _regRoleTab(setS, regRole, 'STUDENT', '学生', (v) => regRole = v),
                      _regRoleTab(setS, regRole, 'TEACHER', '讲师', (v) => regRole = v),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _dialogField(regUsernameCtrl, '用户名（4-32位字母数字）', Icons.person_outline),
                const SizedBox(height: 12),
                _dialogPwdField(regPasswordCtrl, '密码（至少4位）', regPwdVisible,
                  () => setS(() => regPwdVisible = !regPwdVisible)),
                const SizedBox(height: 12),
                _dialogPwdField(regConfirmCtrl, '确认密码', regConfirmVisible,
                  () => setS(() => regConfirmVisible = !regConfirmVisible)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _dialogField(regPhoneCtrl, '手机号', Icons.phone_outlined, type: TextInputType.phone)),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: sendingCode ? null : () async {
                          final phone = regPhoneCtrl.text.trim();
                          if (phone.isEmpty) { setS(() => dialogMsg = '请先输入手机号'); return; }
                          setS(() { sendingCode = true; dialogMsg = null; });
                          final code = await _authService.sendSmsCode(phone: phone, type: 'REGISTER');
                          setS(() {
                            sendingCode = false;
                            if (code == null) { dialogMsg = '发送失败，请重试'; dialogSuccess = false; }
                            else if (code.isNotEmpty) { dialogMsg = '【演示】验证码：$code'; dialogSuccess = true; }
                            else { dialogMsg = '验证码已发送'; dialogSuccess = true; }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.secondary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        child: sendingCode
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('发送验证码'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _dialogField(regSmsCtrl, '6位验证码', Icons.sms_outlined, type: TextInputType.number),
                if (dialogMsg != null) ...[  
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: (dialogSuccess ? AppTheme.successColor : AppTheme.errorColor).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(dialogMsg!,
                      style: TextStyle(fontSize: 12,
                        color: dialogSuccess ? AppTheme.successColor : AppTheme.errorColor)),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: registering ? null : () async {
                      if (regPasswordCtrl.text != regConfirmCtrl.text) {
                        setS(() { dialogMsg = '两次密码不一致'; dialogSuccess = false; }); return;
                      }
                      if (regSmsCtrl.text.trim().length != 6) {
                        setS(() { dialogMsg = '请输入6位验证码'; dialogSuccess = false; }); return;
                      }
                      setS(() { registering = true; dialogMsg = null; });
                      final ok = await _authService.register(
                        username: regUsernameCtrl.text.trim(),
                        password: regPasswordCtrl.text,
                        phone: regPhoneCtrl.text.trim(),
                        smsCode: regSmsCtrl.text.trim(),
                        role: regRole,
                      );
                      setS(() => registering = false);
                      if (ok) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        setState(() { _statusMessage = '注册成功！请用新账号登录'; _isSuccess = true; });
                      } else {
                        setS(() { dialogMsg = '注册失败，用户名可能已存在或验证码错误'; dialogSuccess = false; });
                      }
                    },
                    child: registering
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('注 册'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _regRoleTab(StateSetter setS, String current, String type, String label, Function(String) onChanged) {
    final selected = current == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setS(() => onChanged(type)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: selected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6)]
                : [],
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primary : AppTheme.hintColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon,
      {TextInputType type = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _dialogPwdField(TextEditingController ctrl, String hint, bool visible, VoidCallback toggle) {
    return TextField(
      controller: ctrl,
      obscureText: !visible,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppTheme.primary),
        suffixIcon: IconButton(
          icon: Icon(visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 18, color: AppTheme.hintColor),
          onPressed: toggle,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
