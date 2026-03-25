import 'dart:async';
import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'pages/student_home_page.dart';
import 'pages/teacher_home_page.dart';
import 'services/auth_service.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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

  const MyApp({
    super.key,
    required this.loggedIn,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (!loggedIn) {
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
