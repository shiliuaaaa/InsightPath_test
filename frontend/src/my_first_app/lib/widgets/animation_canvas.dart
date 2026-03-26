import 'package:flutter/material.dart';
import '../models/animation_dsl.dart';

/// 灵犀知径 - 交互式算法动画播放器
/// 核心功能：
/// - 步进式播放（上一步、下一步、自动播放）
/// - 历史栈管理（支持任意回退）
/// - 并发动作执行
/// - 平滑动画过渡
class AnimationCanvas extends StatefulWidget {
  final AnimationScript script;

  const AnimationCanvas({
    super.key,
    required this.script,
  });

  @override
  State<AnimationCanvas> createState() => _AnimationCanvasState();
}

class _AnimationCanvasState extends State<AnimationCanvas>
    with TickerProviderStateMixin {
  // ============ 状态管理 ============
  /// 当前画布上所有存活实体的状态快照
  late Map<String, EntityState> currentCanvasState;

  /// 历史栈：每次执行新 Step 前，深度拷贝当前状态压入栈
  late List<Map<String, EntityState>> historyStack;

  /// 当前步骤索引（0-based）
  int currentStepIndex = 0;

  /// 自动播放控制
  bool isAutoPlaying = false;
  late AnimationController autoPlayController;

  // ============ 常量 ============
  static const double gridUnit = 60.0; // 逻辑坐标到物理像素的转换单位
  static const double nodeSize = 50.0; // DataNode 方块大小
  static const int animationDurationMs = 500; // 动画时长（毫秒）

  @override
  void initState() {
    super.initState();
    currentCanvasState = {};
    historyStack = [];
    autoPlayController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    autoPlayController.addStatusListener(_onAutoPlayStatusChanged);
    _executeCurrentStep();
  }

  @override
  void dispose() {
    autoPlayController.dispose();
    super.dispose();
  }

  // ============ 自动播放控制 ============
  void _onAutoPlayStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (currentStepIndex < widget.script.steps.length - 1) {
        _nextStep();
        autoPlayController.forward(from: 0.0);
      } else {
        setState(() => isAutoPlaying = false);
      }
    }
  }

  void _toggleAutoPlay() {
    setState(() {
      isAutoPlaying = !isAutoPlaying;
      if (isAutoPlaying) {
        autoPlayController.forward();
      } else {
        autoPlayController.stop();
      }
    });
  }

  // ============ 步骤导航 ============
  /// 执行当前步骤的所有动作
  void _executeCurrentStep() {
    if (currentStepIndex >= widget.script.steps.length) return;

    final step = widget.script.steps[currentStepIndex];

    // 执行所有动作（并发）
    for (final action in step.actions) {
      _executeAction(action);
    }

    setState(() {});
  }

  /// 执行单个动作
  void _executeAction(AnimationAction action) {
    if (action is CreateAction) {
      currentCanvasState[action.entityId] = EntityState(
        entityId: action.entityId,
        type: action.type,
        value: action.value,
        index: action.index ?? [0, 0],
        targetId: action.targetId,
      );
    } else if (action is UpdateAction) {
      final entity = currentCanvasState[action.entityId];
      if (entity != null) {
        if (action.theme != null) entity.theme = action.theme!;
        if (action.targetId != null) entity.targetId = action.targetId;
        if (action.index != null) entity.index = action.index!;
      }
    } else if (action is SwapAction) {
      final entity1 = currentCanvasState[action.entityId1];
      final entity2 = currentCanvasState[action.entityId2];
      if (entity1 != null && entity2 != null) {
        final tempIndex = entity1.index;
        entity1.index = entity2.index;
        entity2.index = tempIndex;
      }
    } else if (action is DeleteAction) {
      currentCanvasState.remove(action.entityId);
    }
  }

  /// 下一步
  void _nextStep() {
    if (currentStepIndex >= widget.script.steps.length - 1) return;

    // 保存当前状态到历史栈
    _saveToHistory();

    currentStepIndex++;
    _executeCurrentStep();
  }

  /// 上一步
  void _previousStep() {
    if (historyStack.isEmpty) return;

    currentStepIndex--;
    currentCanvasState = historyStack.removeLast();
    setState(() {});
  }

  /// 重置到初始状态
  void _reset() {
    setState(() {
      currentStepIndex = 0;
      currentCanvasState = {};
      historyStack = [];
      isAutoPlaying = false;
      autoPlayController.stop();
    });
    _executeCurrentStep();
  }

  /// 保存当前状态到历史栈
  void _saveToHistory() {
    final snapshot = <String, EntityState>{};
    for (final entry in currentCanvasState.entries) {
      snapshot[entry.key] = entry.value.deepCopy();
    }
    historyStack.add(snapshot);
  }

  // ============ 颜色主题映射 ============
  Color _getThemeColor(String theme) {
    switch (theme) {
      case 'active':
        return Colors.blue;
      case 'highlight_red':
        return Colors.red;
      case 'locked_green':
        return Colors.green;
      default:
        return Colors.grey[300]!;
    }
  }

  // ============ UI 构建 ============
  @override
  Widget build(BuildContext context) {
    final currentStep = currentStepIndex < widget.script.steps.length
        ? widget.script.steps[currentStepIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.script.title),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // ========== 讲解文本区 ==========
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${currentStepIndex + 1} 步 / 共 ${widget.script.steps.length} 步',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currentStep?.narration ?? '动画已完成',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // ========== 画布区 ==========
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                  return Stack(
                    children: [
                      // 背景网格（可选）
                      CustomPaint(
                        painter: GridPainter(),
                        size: canvasSize,
                      ),
                      // 渲染所有实体（居中）
                      ..._buildEntities(canvasSize),
                    ],
                  );
                },
              ),
            ),
          ),

          // ========== 控制栏 ==========
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 重置按钮
                IconButton(
                  icon: const Icon(Icons.restart_alt),
                  tooltip: '重置',
                  onPressed: _reset,
                ),
                const SizedBox(width: 16),

                // 上一步按钮
                IconButton(
                  icon: const Icon(Icons.skip_previous),
                  tooltip: '上一步',
                  onPressed: historyStack.isNotEmpty ? _previousStep : null,
                ),
                const SizedBox(width: 16),

                // 播放/暂停按钮
                IconButton(
                  icon: Icon(isAutoPlaying ? Icons.pause : Icons.play_arrow),
                  tooltip: isAutoPlaying ? '暂停' : '播放',
                  onPressed: _toggleAutoPlay,
                ),
                const SizedBox(width: 16),

                // 下一步按钮
                IconButton(
                  icon: const Icon(Icons.skip_next),
                  tooltip: '下一步',
                  onPressed:
                      currentStepIndex < widget.script.steps.length - 1
                          ? _nextStep
                          : null,
                ),
                const SizedBox(width: 16),

                // 重做按钮
                IconButton(
                  icon: const Icon(Icons.redo),
                  tooltip: '重做',
                  onPressed: null, // 暂未实现
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建所有实体的 Widget 列表
  List<Widget> _buildEntities(Size canvasSize) {
    return currentCanvasState.values.map((entity) {
      if (entity.type == 'DataNode') {
        return _buildDataNode(entity, canvasSize);
      } else if (entity.type == 'Pointer') {
        return _buildPointer(entity, canvasSize);
      }
      return const SizedBox.shrink();
    }).toList();
  }

  Offset _computeCanvasOffset(Size canvasSize) {
    if (currentCanvasState.isEmpty) {
      return Offset(canvasSize.width / 2, canvasSize.height / 2);
    }

    final dataNodes = currentCanvasState.values
        .where((e) => e.type == 'DataNode')
        .toList();

    if (dataNodes.isEmpty) {
      return Offset(canvasSize.width / 2, canvasSize.height / 2);
    }

    final minX = dataNodes
        .map((e) => e.index[0] * gridUnit)
        .reduce((a, b) => a < b ? a : b);
    final maxX = dataNodes
        .map((e) => e.index[0] * gridUnit)
        .reduce((a, b) => a > b ? a : b);
    final minY = dataNodes
        .map((e) => e.index[1] * gridUnit)
        .reduce((a, b) => a < b ? a : b);
    final maxY = dataNodes
        .map((e) => e.index[1] * gridUnit)
        .reduce((a, b) => a > b ? a : b);

    final contentWidth = (maxX - minX) + nodeSize;
    final contentHeight = (maxY - minY) + nodeSize;

    return Offset(
      (canvasSize.width - contentWidth) / 2 - minX,
      (canvasSize.height - contentHeight) / 2 - minY,
    );
  }

  /// 构建 DataNode（数据方块）
  Widget _buildDataNode(EntityState entity, Size canvasSize) {
    final offset = _computeCanvasOffset(canvasSize);
    final x = entity.index[0] * gridUnit + offset.dx;
    final y = entity.index[1] * gridUnit + offset.dy;

    return AnimatedPositioned(
      left: x,
      top: y,
      duration: Duration(milliseconds: animationDurationMs),
      child: Container(
        width: nodeSize,
        height: nodeSize,
        decoration: BoxDecoration(
          color: _getThemeColor(entity.theme),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: entity.theme == 'default' ? Colors.grey : Colors.black,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(2, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            entity.value ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建 Pointer（指针）
  Widget _buildPointer(EntityState entity, Size canvasSize) {
    final offset = _computeCanvasOffset(canvasSize);
    // 获取指向的目标实体
    final targetEntity = entity.targetId != null
        ? currentCanvasState[entity.targetId]
        : null;

    if (targetEntity == null) {
      return const SizedBox.shrink();
    }

    final targetX = targetEntity.index[0] * gridUnit + nodeSize / 2 + offset.dx;
    final targetY = targetEntity.index[1] * gridUnit + offset.dy;

    return AnimatedPositioned(
      left: targetX - 12,
      top: targetY - 30,
      duration: Duration(milliseconds: animationDurationMs),
      child: Column(
        children: [
          // 向上的箭头
          Icon(
            Icons.arrow_upward,
            color: Colors.red,
            size: 24,
          ),
          // 指针标签
          Text(
            entity.value ?? entity.entityId,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

/// 背景网格绘制器
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[200]!
      ..strokeWidth = 0.5;

    const gridUnit = 60.0;

    // 竖线
    for (double x = 0; x < size.width; x += gridUnit) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 横线
    for (double y = 0; y < size.height; y += gridUnit) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}

