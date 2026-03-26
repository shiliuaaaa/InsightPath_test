import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/ai_service.dart';
import 'animation_player_page.dart';

class GlobalAiTutorPage extends StatefulWidget {
  const GlobalAiTutorPage({super.key, required this.username});

  final String username;

  @override
  State<GlobalAiTutorPage> createState() => _GlobalAiTutorPageState();
}

class _GlobalAiTutorPageState extends State<GlobalAiTutorPage> {
  final AiService _aiService = AiService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<_UiMessage> _messages = [];
  List<GlobalChatSession> _sessions = [];

  int? _sessionId;
  bool _isBooting = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _refreshSessions();
    if (_sessions.isNotEmpty) {
      await _switchSession(_sessions.first.id);
    } else {
      await _createNewSession();
    }
    if (mounted) {
      setState(() => _isBooting = false);
    }
  }

  Future<void> _refreshSessions() async {
    final sessions = await _aiService.getGlobalSessions();
    if (!mounted) return;
    setState(() => _sessions = sessions);
  }

  Future<void> _createNewSession() async {
    final sessionId = await _aiService.createGlobalSession();
    if (sessionId == null) {
      if (!mounted) return;
      _showSnack('创建会话失败，请稍后重试');
      return;
    }

    _sessionId = sessionId;
    _messages.clear();
    await _refreshSessions();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _switchSession(int sessionId) async {
    final list = await _aiService.getGlobalMessages('$sessionId');
    if (!mounted) return;

    setState(() {
      _sessionId = sessionId;
      _messages
        ..clear()
        ..addAll(
          list.map(
            (e) => _UiMessage(
              role: e.role == 'assistant' ? 'assistant' : 'user',
              content: e.content,
            ),
          ),
        );
    });
    _jumpToBottom();
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSending) return;

    if (_sessionId == null) {
      final created = await _aiService.createGlobalSession();
      if (created == null) {
        _showSnack('会话初始化失败');
        return;
      }
      _sessionId = created;
      await _refreshSessions();
    }

    setState(() {
      _messages.add(_UiMessage(role: 'user', content: text));
      _isSending = true;
      _inputController.clear();
    });
    _jumpToBottom();

    final reply = await _aiService.sendGlobalMessage('${_sessionId!}', text);

    if (!mounted) return;
    setState(() {
      _isSending = false;
      _messages.add(
        _UiMessage(
          role: 'assistant',
          content: (reply == null || reply.trim().isEmpty) ? '小犀暂时没想好答案，请稍后再试。' : reply,
        ),
      );
    });

    await _refreshSessions();
    _jumpToBottom();
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _inputController.text.trim().isNotEmpty && !_isSending;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF8F9FA),
      endDrawer: _buildHistoryDrawer(),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AppBar(
              toolbarHeight: 64,
              title: const Text('小犀'),
              backgroundColor: Colors.white.withValues(alpha: 0.58),
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              elevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.history_rounded),
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _WelcomeBanner(
            username: widget.username.trim().isEmpty ? '同学' : widget.username.trim(),
            onOpenAnimation: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnimationPlayerPage()),
              );
            },
          ),
          Expanded(
            child: _isBooting
                ? const Center(child: CupertinoActivityIndicator(radius: 12))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                    itemCount: _messages.length + (_isSending ? 1 : 0),
                    itemBuilder: (_, index) {
                      if (_isSending && index == _messages.length) {
                        return const _ThinkingBubble();
                      }
                      final item = _messages[index];
                      return _MessageBubble(message: item);
                    },
                  ),
          ),
          _InputBar(
            controller: _inputController,
            canSend: canSend,
            onChanged: (_) => setState(() {}),
            onSend: _send,
            onAttach: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryDrawer() {
    return Drawer(
      width: 300,
      backgroundColor: const Color(0xFFF8F9FA),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '历史会话',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      Navigator.of(context).maybePop();
                      await _createNewSession();
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _sessions.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无历史会话',
                        style: TextStyle(color: Color(0xFF9AA0A6)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _sessions.length,
                      itemBuilder: (_, index) {
                        final session = _sessions[index];
                        final selected = session.id == _sessionId;
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: Icon(
                            selected ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                            color: selected ? const Color(0xFF1A73E8) : const Color(0xFF8A9097),
                            size: 18,
                          ),
                          title: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected ? const Color(0xFF1A73E8) : const Color(0xFF1F2937),
                            ),
                          ),
                          subtitle: Text(
                            _formatTime(session.updatedAt),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9AA0A6)),
                          ),
                          onTap: () async {
                            Navigator.of(context).maybePop();
                            await _switchSession(session.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final h = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$m-$d $h:$min';
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.username,
    required this.onOpenAnimation,
  });

  final String username;
  final VoidCallback onOpenAnimation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9EDF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$username，你好！',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '需要我为你做些什么？',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onOpenAnimation,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('动画讲解'),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _UiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1A73E8) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                boxShadow: isUser
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: isUser
                  ? Text(
                      message.content,
                      style: const TextStyle(color: Colors.white, height: 1.45, fontSize: 14),
                    )
                  : MarkdownBody(
                      data: message.content,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          color: Color(0xFF212529),
                          height: 1.55,
                          fontSize: 14,
                        ),
                        code: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF0B3A7D),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFFF2F5FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        strong: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(color: Color(0x15000000), blurRadius: 4, offset: Offset(0, 1)),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(radius: 9),
                  SizedBox(width: 8),
                  Text(
                    '小犀正在思考...',
                    style: TextStyle(color: Color(0xFF5F6368), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onSend,
    required this.onChanged,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool canSend;
  final Future<void> Function() onSend;
  final ValueChanged<String> onChanged;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x10FFFFFF), Color(0xE6FFFFFF)],
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onAttach,
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF8A9097)),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: TextField(
                        controller: controller,
                        onChanged: onChanged,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (canSend) onSend();
                        },
                        maxLines: 4,
                        minLines: 1,
                        decoration: const InputDecoration(
                          hintText: '向小犀提问...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: canSend ? onSend : null,
                    icon: Icon(
                      Icons.send_rounded,
                      color: canSend ? const Color(0xFF1A73E8) : const Color(0xFFB0B6BD),
                    ),
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

class _UiMessage {
  const _UiMessage({required this.role, required this.content});

  final String role;
  final String content;
}

