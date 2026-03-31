import 'package:flutter/material.dart';

import '../pages/edit_profile_page.dart';

class ProfileHeader extends StatelessWidget {
  final String username;
  final String role;
  final String? schoolName;
  final String? avatarUrl;
  final String? bgUrl;
  final VoidCallback? onProfileUpdated;

  const ProfileHeader({
    super.key,
    required this.username,
    required this.role,
    this.schoolName,
    this.avatarUrl,
    this.bgUrl,
    this.onProfileUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final displayRole = role == 'TEACHER' ? '教师' : '学生';
    final avatarImage = (avatarUrl != null && avatarUrl!.isNotEmpty) ? NetworkImage(avatarUrl!) : null;
    final bgImage = (bgUrl != null && bgUrl!.isNotEmpty) ? NetworkImage(bgUrl!) : null;

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: bgImage == null
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                  )
                : null,
            image: bgImage == null ? null : DecorationImage(image: bgImage, fit: BoxFit.cover),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.black.withValues(alpha: bgImage == null ? 0.10 : 0.25),
            ),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      onPressed: () async {
                        final changed = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const EditProfilePage()),
                        );
                        if (changed == true) {
                          onProfileUpdated?.call();
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      tooltip: '编辑资料',
                    ),
                  ],
                ),
        CircleAvatar(
          radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.90),
                  backgroundImage: avatarImage,
                  child: avatarImage == null
                      ? Text(
            username.isNotEmpty ? username.characters.first.toUpperCase() : '?',
            style: const TextStyle(fontSize: 24),
                        )
                      : null,
        ),
        const SizedBox(height: 12),
        Text(
          username,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          displayRole + (schoolName != null ? ' · $schoolName' : ''),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
      ],
    );
  }
}
