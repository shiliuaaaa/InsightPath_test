import 'dart:async';
import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/student_home_page.dart';
import 'pages/teacher_home_page.dart';
import 'pages/animation_player_page.dart';
import 'services/auth_service.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 开发模式：通过 --dart-define=ANIMATION_DEV=true 直接进入动画播放器测试
  const bool devMode = bool.fromEnvironment('ANIMATION_DEV', defaultValue: false);
  
  if (devMode) {
    runApp(const MyApp(
      loggedIn: true,
      role: 'TEACHER',
      devMode: true,
    ));
    return;
  }
  
  final auth = AuthService();
  final loggedIn = await auth.isLoggedIn();
  final user = loggedIn ? await auth.getCurrentUser() : null;
  final role = user?['role'] as String?;

  runApp(MyApp(
    loggedIn: loggedIn,
    role: role,
  ));
}

class MyApp extends StatelessWidget {
  final bool loggedIn;
  final String? role;
  final bool devMode;

  const MyApp({
    super.key,
    required this.loggedIn,
    required this.role,
    this.devMode = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget home;
    
    if (devMode) {
      // 开发模式：直接显示动画播放器
      home = const AnimationPlayerPage();
    } else if (!loggedIn) {
      home = const LoginPage();
    } else if (role == 'TEACHER') {
      home = const TeacherHomePage();
    } else {
      home = const StudentHomePage();
    }

    return MaterialApp(
      title: '灵犀知径',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: home,
    );
  }
}
