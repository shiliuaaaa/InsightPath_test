import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ai_message.dart';
import '../../utils/app_theme.dart';

class StudentStepGuideDemo extends StatefulWidget {
  const StudentStepGuideDemo({super.key});

  @override
  State<StudentStepGuideDemo> createState() => _StudentStepGuideDemoState();
}

class _StudentStepGuideDemoState extends State<StudentStepGuideDemo> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<AiMessage> _messages = [];

  int _phase = 0;
  int _nextId = 1;
  bool _thinking = false;

  String get _currentQuestion {
    if (_phase == 0) return '第一步：为了给索引 2 腾出位置，循环变量 j 的初始值应该是多少？';
    if (_phase == 1) return '第二步：循环条件应该是 j > i 还是 j >= i？';
    return '第三步：移动完成后，新元素 99 应该写入哪个索引？';
  }

  @override
  void initState() {
    super.initState();
    _messages.add(_ai('我们来一步一步完成顺序表 insert(2, 99)。先不要急着写完整代码，只判断移动策略。'));
    _messages.add(_ai(_currentQuestion));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _thinking) return;

    _controller.clear();
    setState(() {
      _messages.add(_user(text));
      _thinking = true;
    });
    _jumpBottom();

    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) return;

    final normalized = text.toLowerCase().replaceAll(' ', '');
    setState(() {
      if (_phase == 0) {
        if (normalized.contains('length') || normalized.contains('n')) {
          _messages.add(_ai('正确。从表尾开始移动可以保护已有数据，避免前面的元素先覆盖后面的元素。'));
          _phase = 1;
          _messages.add(_ai(_currentQuestion));
        } else if (normalized.contains('i') || normalized.contains('2')) {
          _messages.add(
            _ai(
              '如果从 j = i 开始移动，data[2] 的 30 会先写到 data[3]。这样索引 3 原来的 40 会发生什么？',
            ),
          );
          _messages.add(_ai('再想想：为了避免覆盖，应该先移动靠前的元素，还是靠后的元素？'));
        } else {
          _messages.add(_ai('提示：插入时要先给新元素腾位置。为了避免覆盖已有数据，移动应该从表头开始还是从表尾开始？'));
        }
      } else if (_phase == 1) {
        if (normalized.contains('>') && !normalized.contains('>=')) {
          _messages.add(
            _ai('对，条件是 j > i。这样最后一次移动是 data[i+1] = data[i]，正好把索引 i 腾出来。'),
          );
          _phase = 2;
          _messages.add(_ai(_currentQuestion));
        } else if (normalized.contains('>=') || normalized.contains('大于等于')) {
          _messages.add(
            _ai('注意：当 j = i 时，会执行 data[i] = data[i-1]。这会把我们刚刚腾出来的插入位置也改掉。'),
          );
          _messages.add(_ai('所以循环应该在 j 等于 i 之前停止，还是包含 j = i 这一轮？'));
        } else {
          _messages.add(
            _ai(
              '这里比较的是 j 和 i。我们需要移动 data[i] 到 data[i+1]，但不应该执行 data[i] = data[i-1]。',
            ),
          );
        }
      } else {
        if (normalized.contains('2') || normalized.contains('i')) {
          _messages.add(
            _ai(
              '完成！新元素 99 应该写入索引 2。最终顺序表为 [10, 20, 99, 30, 40, 50]，length 变为 6。',
            ),
          );
        } else {
          _messages.add(
            _ai('本次调用是 insert(2, 99)，参数 2 就是插入位置。请再判断一次：99 应该写入哪个索引？'),
          );
        }
      }
      _thinking = false;
    });
    _jumpBottom();
  }

  AiMessage _ai(String text) => AiMessage(
    id: _nextId++,
    role: 'AI',
    content: text,
    createdAt: DateTime.now(),
  );
  AiMessage _user(String text) => AiMessage(
    id: _nextId++,
    role: 'USER',
    content: text,
    createdAt: DateTime.now(),
  );

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _quick(String text) {
    _controller.text = text;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(title: const Text('顺序表插入')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), AppTheme.bg],
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _questionCard(),
                  const SizedBox(height: 12),
                  Expanded(child: _answerCard()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _questionCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: AppTheme.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '顺序表插入逻辑诊断',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.titleColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          '给定 length = 5，data = [10, 20, 30, 40, 50]。现在调用 insert(2, 99)，请补全下面的移动逻辑。',
          style: TextStyle(color: AppTheme.bodyColor, height: 1.5),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'for (int j = _____; j _____ i; j--) {\n  data[j] = data[j - 1];\n}\ndata[i] = 99;',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _currentQuestion,
          style: const TextStyle(
            color: AppTheme.titleColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  Widget _answerCard() => _card(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(14),
            itemCount: _messages.length + (_thinking ? 1 : 0),
            itemBuilder: (context, i) {
              if (i >= _messages.length) {
                return _bubble(_ai('小犀正在分析你的思路...'), ghost: true);
              }
              return _bubble(_messages[i]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(alignment: Alignment.centerLeft, child: _quickChoices()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_thinking,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: '输入你的判断，例如 j = length',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FloatingActionButton.small(
                onPressed: _thinking ? null : _send,
                elevation: 0,
                child: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _quickChoices() {
    final labels = _phase == 0
        ? ['j = i', 'j = length']
        : _phase == 1
        ? ['j >= i', 'j > i']
        : ['索引 2'];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: labels
          .map((e) => ActionChip(label: Text(e), onPressed: () => _quick(e)))
          .toList(),
    );
  }

  Widget _bubble(AiMessage message, {bool ghost = false}) {
    final user = message.role == 'USER';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: user
              ? AppTheme.primary
              : (ghost ? AppTheme.primary.withValues(alpha: .06) : AppTheme.bg),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 4),
            bottomRight: Radius.circular(user ? 4 : 18),
          ),
          border: Border.all(
            color: user ? AppTheme.primary : const Color(0xFFE8EAED),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: user ? Colors.white : AppTheme.titleColor,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      border: Border.all(color: const Color(0xFFEFF2F6)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .05),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}
