import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../utils/app_theme.dart';
import 'animation_player_page.dart';
import 'global_ai_tutor_page.dart';

class LessonQuizPage extends StatefulWidget {
  final String lessonTitle;
  final String quizId;

  const LessonQuizPage({
    super.key,
    required this.lessonTitle,
    required this.quizId,
  });

  @override
  State<LessonQuizPage> createState() => _LessonQuizPageState();
}

class _LessonQuizPageState extends State<LessonQuizPage> {
  String? _selectedOption;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('课后练习', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AnimationPlayerPage(
                    sourceTitle: widget.lessonTitle,
                    sourceContent: '题目：在最坏情况下，冒泡排序的时间复杂度是多少？\n选项：A.O(n) B.O(n log n) C.O(n^2) D.O(1)',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            label: const Text(
              '动画讲解',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: '小犀',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GlobalAiTutorPage(username: '同学'),
                ),
              );
            },
            icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
        ],
      ),      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), AppTheme.bg],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 620),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusL),
                border: Border.all(color: const Color(0xFFEFF2F6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.lessonTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.hintColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '在最坏情况下，冒泡排序的时间复杂度是多少？',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _optionTile('A. O(n)'),
                  _optionTile('B. O(n log n)'),
                  _optionTile('C. O(n^2)'),
                  _optionTile('D. O(1)'),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTutorPanel,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('向 AI 助教求助'),
      ),
    );
  }

  Widget _optionTile(String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _selectedOption == value
            ? AppTheme.primary.withValues(alpha: 0.08)
            : AppTheme.bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(
          color: _selectedOption == value
              ? AppTheme.primary.withValues(alpha: 0.4)
              : const Color(0xFFE8EAED),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        onTap: () => setState(() => _selectedOption = value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                _selectedOption == value
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: _selectedOption == value ? AppTheme.primary : AppTheme.hintColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 14, color: AppTheme.titleColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTutorPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SocraticTutorSheet(
        title: widget.lessonTitle,
      ),
    );
  }
}

class _SocraticTutorSheet extends StatefulWidget {
  final String title;

  const _SocraticTutorSheet({required this.title});

  @override
  State<_SocraticTutorSheet> createState() => _SocraticTutorSheetState();
}

class _SocraticTutorSheetState extends State<_SocraticTutorSheet> {
  final AiService _aiService = AiService();
  final TextEditingController _inputController = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'AI',
      'content': '我是你的启发式助教。别急着看答案，先说说你对这道题的第一直觉。',
    }
  ];
  bool _sending = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.45,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.school_rounded, color: AppTheme.primary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'AI 助教（启发式）',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(widget.title, style: const TextStyle(fontSize: 12, color: AppTheme.hintColor)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final m = _messages[index];
                        final isUser = m['role'] == 'USER';
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? AppTheme.primary.withValues(alpha: 0.14)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE8EAED)),
                            ),
                            child: Text(
                              m['content'] ?? '',
                              style: const TextStyle(fontSize: 13, color: AppTheme.titleColor, height: 1.5),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.hintColor),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            maxLines: 3,
                            minLines: 1,
                            decoration: const InputDecoration(
                              hintText: '比如：我总是分不清最好和最坏复杂度…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _sending ? null : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add({'role': 'USER', 'content': text});
      _sending = true;
      _inputController.clear();
    });

    final reply = await _aiService.askSocraticTutor(text);
    if (!mounted) return;

    setState(() {
      _messages.add({
        'role': 'AI',
        'content': reply ?? '我暂时没能连上服务。你可以先回忆：冒泡排序最坏时是否会比较很多轮？',
      });
      _sending = false;
    });
  }
}
