import 'package:flutter/material.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String role;
  final String? schoolName;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.role,
    this.schoolName,
  });

  @override
  Widget build(BuildContext context) {
    final displayRole = role == 'TEACHER' ? '教师' : '学生';

    return Column(
      children: [
        const SizedBox(height: 16),
        CircleAvatar(
          radius: 32,
          child: Text(
            username.isNotEmpty ? username.characters.first.toUpperCase() : '?',
            style: const TextStyle(fontSize: 24),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          username,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          displayRole + (schoolName != null ? ' · $schoolName' : ''),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    );
  }
}
