import 'package:flutter/material.dart';
import '../models/animation_dsl.dart';
import '../services/ai_service.dart';
import '../widgets/animation_canvas.dart';
import '../utils/animation_script_library.dart';

/// 动画播放器页面
/// 支持：
///   1. 预设脚本切换（本地硬编码）
///   2. AI 生成脚本（输入自然语言 prompt，调用后端）
class AnimationPlayerPage extends StatefulWidget {
  const AnimationPlayerPage({super.key});

  @override
  State<AnimationPlayerPage> createState() => _AnimationPlayerPageState();
}

class _AnimationPlayerPageState extends State<AnimationPlayerPage> {
  // ── 预设脚本 ──
  late AnimationScript currentScript;
  int selectedScriptIndex = 0;

  final List<(String, AnimationScript Function())> _presets = [
    ('冒泡排序', AnimationScriptLibrary.getBubbleSortDemo),
    ('二分查找', AnimationScriptLibrary.getBinarySearchDemo),
    ('链表插入', AnimationScriptLibrary.getLinkedListDemo),
  ];

  // ── AI 生成 ──
  final _aiService = AiService();
  final _promptController = TextEditingController();
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    currentScript = _presets[0].$2();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  // ── 切换预设脚本 ──
  void _switchPreset(int index) {
    setState(() {
      selectedScriptIndex = index;
      currentScript = _presets[index].$2();
      _errorMessage = null;
    });
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
        selectedScriptIndex = -1; // 取消预设高亮
      });
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isGenerating = false);
    }
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
                const Icon(Icons.auto_awesome, color: Colors.deepPurple),
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
                  borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 示例提示词快捷按钮
            Wrap(
              spacing: 8,
              children: [
                '演示选择排序',
                '演示二叉树前序遍历',
                '演示快速排序',
              ].map((hint) => ActionChip(
                    label: Text(hint, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _promptController.text = hint,
                  )).toList(),
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
                  backgroundColor: Colors.deepPurple,
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
        title: const Text('算法动画播放器'),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
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
          // ── 预设脚本切换栏 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text('预设：', style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        _presets.length,
                        (index) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ElevatedButton(
                            onPressed: () => _switchPreset(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selectedScriptIndex == index
                                  ? Colors.deepPurple
                                  : Colors.grey[300],
                              foregroundColor: selectedScriptIndex == index
                                  ? Colors.white
                                  : Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              _presets[index].$1,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── 加载中覆盖层 ──
          if (_isGenerating)
            Container(
              color: Colors.deepPurple.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.deepPurple,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'AI 正在生成动画剧本，请稍候...',
                    style: TextStyle(color: Colors.deepPurple, fontSize: 13),
                  ),
                ],
              ),
            ),

          // ── 错误提示条 ──
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

          // ── 动画画布（核心） ──
          Expanded(
            child: AnimationCanvas(script: currentScript),
          ),
        ],
      ),

      // ── 悬浮 AI 按钮（辅助入口） ──
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isGenerating ? null : _showAiInputDialog,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI 生成'),
      ),
    );
  }
}
