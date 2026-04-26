import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';

class TeacherInsightMapperDemo extends StatelessWidget {
  const TeacherInsightMapperDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('创建习题 · 知径预设'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.check_rounded),
            label: const Text('保存'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF3FF), AppTheme.bg],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: c.maxWidth >= 900
                    ? const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: _QuestionCard()),
                          SizedBox(width: 14),
                          Expanded(flex: 6, child: _MapperCard()),
                        ],
                      )
                    : const Column(
                        children: [
                          _QuestionCard(),
                          SizedBox(height: 14),
                          _MapperCard(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard();

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: '顺序表插入逻辑诊断',
      sub: '题目设计：边界与覆盖',
      icon: Icons.quiz_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Input('题目名称', '顺序表插入逻辑诊断'),
          const SizedBox(height: 12),
          const _Input(
            '题目情境',
            '给定 length = 5，data = [10, 20, 30, 40, 50]。现在调用 insert(2, 99)，需要先移动元素，为新元素腾出位置。',
            lines: 4,
          ),
          const SizedBox(height: 12),
          const _Input(
            '学生要补全的伪代码',
            'for (int j = _____; j _____ i; j--) {\n  data[j] = data[j - 1];\n}\ndata[i] = 99;',
            lines: 5,
            mono: true,
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Tag('for 起点'),
              _Tag('终止条件'),
              _Tag('数据覆盖'),
              _Tag('DSL 联动'),
            ],
          ),
          const SizedBox(height: 18),
          _Tip('录屏重点：让评委看到老师不是写死答案，而是在关键代码行上预设“错误模式 → 启发话术 → 动画片段”。'),
        ],
      ),
    );
  }
}

class _MapperCard extends StatelessWidget {
  const _MapperCard();

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: '知径编辑器 Insight-Mapper',
      sub: '教师预设：逻辑锚点、错误模式、启发链',
      icon: Icons.account_tree_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Title('1. 代码槽位锚点 Code Anchors'),
          const SizedBox(height: 10),
          _codeBox(),
          const SizedBox(height: 18),
          const _Title('2. 错误模式匹配器 Error Pattern Matcher'),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: _Pattern(
                  '分叉 A',
                  '顺序逆转：j = i，从前往后移动',
                  AppTheme.errorColor,
                  true,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _Pattern(
                  '分叉 B',
                  '边界错误：length - 1，少腾一个槽',
                  AppTheme.accent,
                  false,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _Pattern(
                  '分叉 C',
                  '正确路径：j = length，倒序移动',
                  AppTheme.successColor,
                  true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _Title('3. 启发引导链 Heuristic Chain'),
          const SizedBox(height: 10),
          const _Hook(
            'A1',
            '学生回答包含 “j=i / 从 i 开始”',
            '如果从 j=i 开始向后赋值，想一想索引 i+1 原有的数据会发生什么？',
            '覆盖预警：30 覆盖 40，红色震动',
            AppTheme.errorColor,
          ),
          const SizedBox(height: 10),
          const _Hook(
            'C1',
            '学生回答包含 “length / 最后面开始”',
            '正确。从表尾开始移动可以保护数据。那么，循环应该在什么时候停止？',
            '倒序移位：50→5、40→4、30→3，索引2发光',
            AppTheme.successColor,
          ),
          const SizedBox(height: 10),
          const _Hook(
            'A2',
            '学生选择 “j >= i”',
            '注意，当 j=i 时，执行的是 data[i] = data[i-1]。这会改变我们要插入的位置吗？',
            '边界警告：插入槽被覆盖，黄色闪烁',
            AppTheme.accent,
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.save_rounded),
              label: const Text('已保存知径预设到本题'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _codeBox() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Code('01', 'bool insert(int i, int e) {', false),
        _Code('02', '  if (i < 0 || i > length) return false;', false),
        _Code('03', '  for (int j = length; j > i; j--) {', true),
        _Code('04', '    data[j] = data[j - 1];', true),
        _Code('05', '  }', false),
        _Code('06', '  data[i] = e; length++; return true;', false),
      ],
    ),
  );
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.title,
    required this.sub,
    required this.icon,
    required this.child,
  });
  final String title, sub;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      border: Border.all(color: const Color(0xFFEFF2F6)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .05),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.titleColor,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.hintColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _Input extends StatelessWidget {
  const _Input(this.label, this.text, {this.lines = 1, this.mono = false});
  final String label, text;
  final int lines;
  final bool mono;
  @override
  Widget build(BuildContext context) => TextField(
    controller: TextEditingController(text: text),
    readOnly: true,
    maxLines: lines,
    style: TextStyle(
      fontFamily: mono ? 'monospace' : null,
      height: 1.5,
      color: AppTheme.titleColor,
    ),
    decoration: InputDecoration(labelText: label),
  );
}

class _Code extends StatelessWidget {
  const _Code(this.no, this.text, this.active);
  final String no, text;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: active
          ? AppTheme.primary.withValues(alpha: .25)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      border: active
          ? Border.all(color: AppTheme.primary.withValues(alpha: .55))
          : null,
    ),
    child: Row(
      children: [
        SizedBox(
          width: 28,
          child: Text(
            no,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontFamily: 'monospace',
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
              fontSize: 13.5,
            ),
          ),
        ),
        if (active)
          const Icon(
            Icons.ads_click_rounded,
            color: Color(0xFF93C5FD),
            size: 16,
          ),
      ],
    ),
  );
}

class _Pattern extends StatelessWidget {
  const _Pattern(this.title, this.desc, this.color, this.active);
  final String title, desc;
  final Color color;
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 104),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: active ? .10 : .05),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: active ? .45 : .16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              active
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          style: const TextStyle(
            color: AppTheme.titleColor,
            fontSize: 12.5,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}

class _Hook extends StatelessWidget {
  const _Hook(this.step, this.trigger, this.hint, this.dsl, this.color);
  final String step, trigger, hint, dsl;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.bg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8EAED)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: .12),
          child: Text(
            step,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                trigger,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.titleColor,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                hint,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.bodyColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.movie_filter_rounded, color: color, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      dsl,
                      style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: AppTheme.titleColor,
    ),
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(text),
    avatar: const Icon(Icons.check_rounded, size: 16),
  );
}

class _Tip extends StatelessWidget {
  const _Tip(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppTheme.radiusS),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lightbulb_outline_rounded,
          color: AppTheme.primary,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.titleColor,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    ),
  );
}
