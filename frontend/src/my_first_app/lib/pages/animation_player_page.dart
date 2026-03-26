import 'package:flutter/material.dart';
import '../models/animation_dsl.dart';
import '../services/ai_service.dart';
import '../widgets/animation_canvas.dart';
import '../utils/app_theme.dart';

/// 动画播放器页面
/// 支持：
///   1. 预设脚本切换（本地硬编码）
///   2. AI 生成脚本（输入自然语言 prompt，调用后端）
class AnimationPlayerPage extends StatefulWidget {
  const AnimationPlayerPage({
    super.key,
    this.sourceTitle,
    this.sourceContent,
  });

  final String? sourceTitle;
  final String? sourceContent;

  @override
  State<AnimationPlayerPage> createState() => _AnimationPlayerPageState();
}

class _AnimationPlayerPageState extends State<AnimationPlayerPage> {
  AnimationScript? currentScript;

  // ── AI 生成 ──
  final _aiService = AiService();
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // ── AI 生成脚本 ──
  Future<void> _generateWithAI() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _errorMessage = '请输入描述内容');
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final script = await _aiService.generateAnimationScript(prompt);
      setState(() {
        currentScript = script;
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  Future<void> _useCurrentPageForAnimation() async {
    final title = (widget.sourceTitle ?? '').trim();
    final content = (widget.sourceContent ?? '').trim();
    final prompt = [
      if (title.isNotEmpty) '页面标题：$title',
      if (content.isNotEmpty) '页面内容：$content',
      '请基于这页内容生成可视化动画讲解脚本，步骤要清晰。',
    ].join('\n');

    _promptController.text = prompt;
    await _generateWithAI();
  }

  // ── 显示 AI 输入弹窗 ──
  void _showAiInputDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primary),
                const SizedBox(width: 8),
                const Text(
                  'AI 生成动画剧本',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '用自然语言描述你想演示的算法，AI 将为你生成动画剧本。',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '例如：演示冒泡排序，数组为 [5, 3, 1, 4, 2]',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isGenerating
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _generateWithAI();
                      },
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_isGenerating ? '生成中...' : '生成动画'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(color: Colors.white),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('动画播放器'),
        centerTitle: true,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          // AI 生成按钮（右上角）
          Tooltip(
            message: 'AI 生成动画',
            child: IconButton(
              icon: const Icon(Icons.auto_awesome),
              onPressed: _showAiInputDialog,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if ((widget.sourceTitle ?? '').trim().isNotEmpty ||
              (widget.sourceContent ?? '').trim().isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Colors.grey[100],
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _isGenerating ? null : _useCurrentPageForAnimation,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('使用动画讲解此页面'),
                ),
              ),
            ),

          if (_isGenerating)
            Container(
              color: AppTheme.primary.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'AI 正在生成动画剧本，请稍候...',
                    style: TextStyle(color: AppTheme.primary, fontSize: 13),
                  ),
                ],
              ),
            ),

          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: Colors.red[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.red,
                    onPressed: () => setState(() => _errorMessage = null),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

          Expanded(
            child: currentScript == null
                ? _buildEmptyState()
                : AnimationCanvas(script: currentScript!),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECF2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 44, color: AppTheme.primary),
              const SizedBox(height: 12),
              const Text(
                '还没有动画内容',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.titleColor),
              ),
              const SizedBox(height: 6),
              const Text(
                '点击“使用动画讲解此页面”或右上角 AI 生成',
                style: TextStyle(fontSize: 13, color: AppTheme.hintColor),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: ((widget.sourceTitle ?? '').trim().isNotEmpty ||
                        (widget.sourceContent ?? '').trim().isNotEmpty)
                    ? _useCurrentPageForAnimation
                    : _showAiInputDialog,
                icon: const Icon(Icons.play_circle_outline_rounded),
                label: const Text('开始生成动画'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
