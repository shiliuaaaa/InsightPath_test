import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/ai_message.dart';
import '../../utils/app_theme.dart';

// ignore: non_constant_identifier_names
final String error_dsl_script =
    '{"action":"OVERWRITE","from":"node_2","to":"node_3","effect":"SHAKE_RED"}';

// ignore: non_constant_identifier_names
final String correct_dsl_script =
    '{"action":"SHIFT_RIGHT_FROM_TAIL","range":"[2,5]","empty_slot":2,"effect":"GREEN_GLOW"}';

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
  _VisualMode _mode = _VisualMode.initial;

  String get _currentQuestion {
    if (_phase == 0) return '第一步：为了给索引 2 腾出位置，循环变量 j 的初始值应该是多少？';
    if (_phase == 1) return '第二步：很好。那么循环条件应该是 j > i 还是 j >= i？';
    return '第三步：现在把新元素 99 放入哪个索引？';
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
          _mode = _VisualMode.correctShift;
          _messages.add(
            _ai('正确。从表尾开始移动可以保护已有数据。你看，50、40、30 都依次向右移动，索引 2 被腾出来了。'),
          );
          _phase = 1;
          _messages.add(_ai(_currentQuestion));
        } else if (normalized.contains('i') || normalized.contains('2')) {
          _mode = _VisualMode.overwrite;
          _messages.add(
            _ai(
              '如果从 j=i 开始向后赋值，data[2] 的 30 会先写到 data[3]，索引 3 原来的 40 就被覆盖了。这时 40 还在内存里吗？',
            ),
          );
          _messages.add(_ai('请修正第一步：j 应该从哪里开始？'));
        } else {
          _messages.add(_ai('提示：为了避免覆盖，应该先移动靠后的元素，还是靠前的元素？'));
        }
      } else if (_phase == 1) {
        if (normalized.contains('>') && !normalized.contains('>=')) {
          _mode = _VisualMode.boundaryCorrect;
          _messages.add(
            _ai('对，条件是 j > i。这样最后一次执行是 data[i+1] = data[i]，正好把索引 2 腾出来。'),
          );
          _phase = 2;
          _messages.add(_ai(_currentQuestion));
        } else if (normalized.contains('>=') || normalized.contains('大于等于')) {
          _mode = _VisualMode.boundaryWrong;
          _messages.add(
            _ai('注意，当 j=i 时会执行 data[i] = data[i-1]。这会把索引 2 的插入位置也改掉，空位就不干净了。'),
          );
          _messages.add(_ai('再试一次：循环应该在 j 等于 i 前停止，还是包含 i？'));
        } else {
          _messages.add(
            _ai(
              '这里比较的是 j 和 i。想想：我们需要移动 data[i] 到 data[i+1]，但不应该执行 data[i] = data[i-1]。',
            ),
          );
        }
      } else {
        if (normalized.contains('2') || normalized.contains('i')) {
          _mode = _VisualMode.inserted;
          _messages.add(
            _ai('完成！最终 data = [10, 20, 99, 30, 40, 50]，length 从 5 变为 6。'),
          );
        } else {
          _messages.add(_ai('新元素要放进本次调用 insert(2, 99) 指定的位置，也就是索引 2。'));
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
      appBar: AppBar(title: const Text('顺序表插入 · 步进引导')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), AppTheme.bg],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 820;
            final left = Column(
              children: [
                _questionCard(),
                const SizedBox(height: 12),
                Expanded(child: _chatCard()),
              ],
            );
            final right = _visualCard();
            return Padding(
              padding: const EdgeInsets.all(14),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: left),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: right),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 260, child: right),
                        const SizedBox(height: 12),
                        Expanded(child: left),
                      ],
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _questionCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
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
          '给定 length = 5，data = [10, 20, 30, 40, 50]。调用 insert(2, 99)，补全移动逻辑：',
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

  Widget _visualCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.movie_filter_rounded, color: AppTheme.secondary),
            SizedBox(width: 8),
            Text(
              'DSL 画布联动',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.titleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(child: _ArrayVisual(mode: _mode)),
        const SizedBox(height: 8),
        _DslBadge(mode: _mode),
      ],
    ),
  );

  Widget _chatCard() => _card(
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
                return _bubble(_ai('小犀正在匹配老师预设的知径分叉...'), ghost: true);
              }
              return _bubble(_messages[i]);
            },
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _phase == 0
              ? [
                  ActionChip(
                    label: const Text('j = i'),
                    onPressed: () => _quick('j = i'),
                  ),
                  ActionChip(
                    label: const Text('j = length'),
                    onPressed: () => _quick('j = length'),
                  ),
                ]
              : _phase == 1
              ? [
                  ActionChip(
                    label: const Text('j >= i'),
                    onPressed: () => _quick('j >= i'),
                  ),
                  ActionChip(
                    label: const Text('j > i'),
                    onPressed: () => _quick('j > i'),
                  ),
                ]
              : [
                  ActionChip(
                    label: const Text('索引 2'),
                    onPressed: () => _quick('索引 2'),
                  ),
                ],
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
                    hintText: '输入你的判断，例如 j = i',
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

  Widget _bubble(AiMessage m, {bool ghost = false}) {
    final user = m.role == 'USER';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
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
          m.content,
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

enum _VisualMode {
  initial,
  overwrite,
  correctShift,
  boundaryWrong,
  boundaryCorrect,
  inserted,
}

class _ArrayVisual extends StatelessWidget {
  const _ArrayVisual({required this.mode});
  final _VisualMode mode;

  @override
  Widget build(BuildContext context) {
    final items = switch (mode) {
      _VisualMode.correctShift ||
      _VisualMode.boundaryCorrect => ['10', '20', '空', '30', '40', '50'],
      _VisualMode.inserted => ['10', '20', '99', '30', '40', '50'],
      _VisualMode.overwrite => ['10', '20', '30', '30', '50'],
      _VisualMode.boundaryWrong => ['10', '20', '20', '30', '40', '50'],
      _ => ['10', '20', '30', '40', '50'],
    };
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 12,
        children: List.generate(items.length, (i) {
          final error =
              (mode == _VisualMode.overwrite && i == 3) ||
              (mode == _VisualMode.boundaryWrong && i == 2);
          final good =
              (mode == _VisualMode.correctShift && i == 2) ||
              (mode == _VisualMode.inserted && i == 2) ||
              (mode == _VisualMode.boundaryCorrect && i == 2);
          final shifted = mode == _VisualMode.correctShift && i >= 3;
          final color = error
              ? AppTheme.errorColor
              : good
              ? AppTheme.successColor
              : shifted
              ? AppTheme.primary
              : AppTheme.bodyColor;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 360),
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(
                    alpha: error || good || shifted ? .14 : .06,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(
                      alpha: error || good || shifted ? .65 : .22,
                    ),
                    width: 1.4,
                  ),
                ),
                child: Text(
                  items[i],
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '$i',
                style: const TextStyle(color: AppTheme.hintColor, fontSize: 12),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _DslBadge extends StatelessWidget {
  const _DslBadge({required this.mode});
  final _VisualMode mode;
  @override
  Widget build(BuildContext context) {
    final text = switch (mode) {
      _VisualMode.overwrite => '触发老师预设：分叉 A · OVERWRITE 红色预警',
      _VisualMode.correctShift => '触发老师预设：分叉 C · 从表尾倒序移位',
      _VisualMode.boundaryWrong => '触发老师预设：边界错误 · j >= i',
      _VisualMode.boundaryCorrect => '边界修正：j > i，索引 2 成为空位',
      _VisualMode.inserted => '插入完成：data[2] = 99，length = 6',
      _ => '等待学生输入，画布保持初始数组',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.titleColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
