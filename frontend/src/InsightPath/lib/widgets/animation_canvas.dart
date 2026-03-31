import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/animation_dsl.dart';

/// 灵犀知径 - 交互式算法动画播放器（DSL V3.0）
///
/// 本版本核心升级：
/// 1. 支持树/图节点（圆形）
/// 2. 支持连线关系（CONNECT_EDGE / DISCONNECT）
/// 3. 支持 DP 格子动作（UPDATE_CELL）
/// 4. 语义化配色 + 新拟物节点质感 + 毛玻璃蒙版
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
  // ===================== 语义化配色（V3.0） =====================
  static const Color insightPrimary = Color(0xFF1A73E8); // 智慧蓝
  static const Color highlightActive = Color(0xFFFF6B6B); // 活力珊瑚红
  static const Color lockedSuccess = Color(0xFF6BCB77); // 淡雅鼠尾草绿
  static const Color warningColor = Color(0xFFFFB257); // 依赖/转移提示色
  static const Color backgroundOff = Color(0xFFF8F9FA); // 浅白背景
  static const Color textDark = Color(0xFF1D1D1F);

  // ===================== 动画尺寸参数 =====================
  static const double gridUnit = 62.0; // 网格步长（数组/DP）
  static const double dataNodeSize = 56.0;
  static const double circleNodeSize = 54.0;
  static const int transitionDurationMs = 520;

  // ===================== 核心状态 =====================
  /// 当前实体状态（节点/指针）
  late Map<String, EntityState> _entities;

  /// 当前边状态（树边/图边）
  late Map<String, EdgeState> _edges;

  /// 历史快照栈，支持“上一步”
  late List<_CanvasSnapshot> _historyStack;

  /// 当前步骤索引（0-based）
  int _currentStepIndex = 0;

  /// 自动播放标记
  bool _isAutoPlaying = false;

  /// 步骤执行过渡中的蒙版标记（毛玻璃）
  bool _isApplyingStep = false;

  late final AnimationController _autoPlayController;

  /// 该控制器只用于驱动连线重绘，保证节点 AnimatedPositioned 运动时连线跟随丝滑变化
  late final AnimationController _lineSyncController;

  @override
  void initState() {
    super.initState();
    _entities = <String, EntityState>{};
    _edges = <String, EdgeState>{};
    _historyStack = <_CanvasSnapshot>[];

    _autoPlayController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (_currentStepIndex < widget.script.steps.length - 1) {
            _nextStep();
            _autoPlayController.forward(from: 0);
          } else {
            setState(() => _isAutoPlaying = false);
          }
        }
      });

    _lineSyncController = AnimationController(
      duration: const Duration(milliseconds: transitionDurationMs),
      vsync: this,
    )..addListener(() {
        // 持续触发重建，使连线在节点位移动画期间同步刷新
        if (mounted) setState(() {});
      });

    _executeCurrentStep();
  }

  @override
  void dispose() {
    _autoPlayController.dispose();
    _lineSyncController.dispose();
    super.dispose();
  }

  // ===================== 步骤控制 =====================
  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlaying = !_isAutoPlaying;
      if (_isAutoPlaying) {
        _autoPlayController.forward(from: 0);
      } else {
        _autoPlayController.stop();
      }
    });
  }

  void _executeCurrentStep() {
    if (_currentStepIndex < 0 || _currentStepIndex >= widget.script.steps.length) {
      return;
    }

    final step = widget.script.steps[_currentStepIndex];
    for (final action in step.actions) {
      _executeAction(action);
    }

    _startVisualTransition();
  }

  void _executeAction(AnimationAction action) {
    switch (action.actionType) {
      case ActionType.create:
        final a = action as CreateAction;

        List<double> resolvedIndex;
        if (a.index != null) {
          resolvedIndex = List<double>.from(a.index!);
        } else if (a.pos != null && a.type == EntityType.dataNode) {
          resolvedIndex = [a.pos!.toDouble(), 0.0];
        } else if (a.type == EntityType.dataNode) {
          // 兜底：当 DSL 没给 DataNode 的 index 时，按创建顺序横向排开，避免全部重叠在 [0,0]。
          final existingDataNodes =
              _entities.values.where((e) => e.type == EntityType.dataNode).length;
          resolvedIndex = [existingDataNodes.toDouble(), 0.0];
        } else {
          resolvedIndex = const [0, 0];
        }

        _entities[a.entityId] = EntityState(
          entityId: a.entityId,
          type: a.type,
          value: a.value,
          index: resolvedIndex,
          theme: a.theme ?? 'default',
          targetId: a.targetId,
        );
        break;

      case ActionType.update:
        final a = action as UpdateAction;
        final entity = _entities[a.entityId];
        if (entity == null) return;

        if (a.theme != null) entity.theme = a.theme!;
        if (a.targetId != null) entity.targetId = a.targetId;
        if (a.index != null) entity.index = a.index!;
        if (a.value != null) entity.value = a.value;
        break;

      case ActionType.swap:
        final a = action as SwapAction;
        final e1 = _entities[a.entityId1];
        final e2 = _entities[a.entityId2];
        if (e1 == null || e2 == null) return;

        final temp = List<double>.from(e1.index);
        e1.index = List<double>.from(e2.index);
        e2.index = temp;
        break;

      case ActionType.delete:
        final a = action as DeleteAction;
        _entities.remove(a.entityId);

        // 删除节点时顺带清理相关边
        _edges.removeWhere((_, edge) => edge.sourceId == a.entityId || edge.targetId == a.entityId);
        break;

      case ActionType.connectEdge:
        final a = action as ConnectEdgeAction;
        final edge = EdgeState(
          sourceId: a.sourceEntityId,
          targetId: a.targetId,
          edgeType: a.edgeType,
          isDirected: a.isDirected,
          label: a.label,
          theme: a.theme ?? 'default',
        );
        _edges[edge.key] = edge;
        break;

      case ActionType.disconnect:
        final a = action as DisconnectEdgeAction;
        _edges.remove('${a.sourceEntityId}->${a.targetId}');
        break;

      case ActionType.updateCell:
        final a = action as UpdateCellAction;
        final cellId = a.entityId ?? 'cell-${a.row}-${a.col}';
        final existing = _entities[cellId];

        if (existing == null) {
          _entities[cellId] = EntityState(
            entityId: cellId,
            type: EntityType.dataNode,
            value: a.value,
            index: [a.col.toDouble(), a.row.toDouble()],
            theme: a.theme ?? 'warning',
          );
        } else {
          existing.value = a.value;
          existing.theme = a.theme ?? existing.theme;
          existing.index = [a.col.toDouble(), a.row.toDouble()];
        }
        break;
    }
  }

  void _nextStep() {
    if (_currentStepIndex >= widget.script.steps.length - 1) return;

    _saveSnapshotToHistory();
    setState(() {
      _currentStepIndex++;
    });
    _executeCurrentStep();
  }

  void _previousStep() {
    if (_historyStack.isEmpty) return;

    final snapshot = _historyStack.removeLast();
    setState(() {
      _currentStepIndex = (_currentStepIndex - 1).clamp(0, widget.script.steps.length - 1);
      _entities = snapshot.entities;
      _edges = snapshot.edges;
    });

    _startVisualTransition();
  }

  void _reset() {
    setState(() {
      _currentStepIndex = 0;
      _entities = <String, EntityState>{};
      _edges = <String, EdgeState>{};
      _historyStack.clear();
      _isAutoPlaying = false;
      _isApplyingStep = false;
    });
    _autoPlayController.stop();
    _executeCurrentStep();
  }

  void _saveSnapshotToHistory() {
    final entitySnapshot = <String, EntityState>{};
    final edgeSnapshot = <String, EdgeState>{};

    for (final entry in _entities.entries) {
      entitySnapshot[entry.key] = entry.value.deepCopy();
    }
    for (final entry in _edges.entries) {
      edgeSnapshot[entry.key] = entry.value.deepCopy();
    }

    _historyStack.add(_CanvasSnapshot(entities: entitySnapshot, edges: edgeSnapshot));
  }

  void _startVisualTransition() {
    setState(() => _isApplyingStep = true);

    _lineSyncController.forward(from: 0);

    Future<void>.delayed(const Duration(milliseconds: transitionDurationMs), () {
      if (!mounted) return;
      setState(() => _isApplyingStep = false);
    });
  }

  // ===================== 颜色映射 =====================
  Color _resolveThemeColor(String theme) {
    switch (theme.toLowerCase()) {
      case 'active':
      case 'highlight_red':
      case 'error':
        return highlightActive;
      case 'locked':
      case 'locked_green':
      case 'success':
        return lockedSuccess;
      case 'warning':
      case 'dependency':
        return warningColor;
      case 'default':
      default:
        return insightPrimary;
    }
  }

  // ===================== 坐标系统 =====================
  /// 检测 AI 是否把一维数组坐标写成了 [row, col]（会导致竖排）。
  /// 若检测到，则在渲染层自动交换为 [col, row]，保证数组水平展示。
  bool _shouldSwapArrayAxes() {
    final hasArrayContainer = _entities.values.any((e) => e.type == EntityType.arrayContainer);
    if (!hasArrayContainer) return false;

    final dataNodes = _entities.values.where((e) => e.type == EntityType.dataNode).toList();
    if (dataNodes.length < 2) return false;

    final xSet = dataNodes
        .map((e) => e.index.isNotEmpty ? e.index[0] : 0.0)
        .toSet();
    final ySet = dataNodes
        .map((e) => e.index.length > 1 ? e.index[1] : 0.0)
        .toSet();

    // 典型“竖排数组”特征：x 基本恒定，y 连续变化。
    return xSet.length == 1 && ySet.length > 1;
  }

  List<double> _normalizedGridIndex(EntityState entity, bool swapArrayAxes) {
    final ix = entity.index.isNotEmpty ? entity.index[0] : 0.0;
    final iy = entity.index.length > 1 ? entity.index[1] : 0.0;

    final shouldSwap =
        swapArrayAxes && (entity.type == EntityType.dataNode || entity.type == EntityType.arrayContainer);
    return shouldSwap ? [iy, ix] : [ix, iy];
  }

  Offset _computeGridOffset(Size canvasSize, bool swapArrayAxes) {
    final gridEntities = _entities.values.where((e) {
      // 树/图相对坐标默认不参与 grid 居中计算
      if (e.type == EntityType.treeNode || e.type == EntityType.graphNode) return false;
      if (e.type == EntityType.pointer) return false;
      return true;
    }).toList();

    if (gridEntities.isEmpty) {
      return Offset(canvasSize.width * 0.12, canvasSize.height * 0.22);
    }

    final xs = gridEntities
        .map((e) => _normalizedGridIndex(e, swapArrayAxes)[0] * gridUnit)
        .toList();
    final ys = gridEntities
        .map((e) => _normalizedGridIndex(e, swapArrayAxes)[1] * gridUnit)
        .toList();

    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);

    final contentWidth = (maxX - minX) + dataNodeSize;
    final contentHeight = (maxY - minY) + dataNodeSize;

    return Offset(
      (canvasSize.width - contentWidth) / 2 - minX,
      (canvasSize.height - contentHeight) / 2 - minY,
    );
  }

  /// 为“未提供坐标的 TreeNode”自动计算拓扑布局，避免节点堆叠到同一位置。
  ///
  /// 布局策略：
  /// 1. 根据 parent_child 边构建父子关系图
  /// 2. 自动识别根节点（入度为 0）
  /// 3. 通过 DFS 给每个节点分配 x 序号，depth 决定 y 层级
  /// 4. 最终映射到画布上的绝对坐标（top-left）
  Map<String, Offset> _computeTreeAutoLayout(Size canvasSize) {
    final treeNodes = _entities.values
        .where((e) => e.type == EntityType.treeNode)
        .toList();

    if (treeNodes.isEmpty) return const {};

    final nodeIdSet = treeNodes.map((e) => e.entityId).toSet();
    final children = <String, List<String>>{};
    final indegree = <String, int>{
      for (final id in nodeIdSet) id: 0,
    };

    for (final edge in _edges.values) {
      if (edge.edgeType != EdgeType.parentChild) continue;
      if (!nodeIdSet.contains(edge.sourceId) || !nodeIdSet.contains(edge.targetId)) continue;

      children.putIfAbsent(edge.sourceId, () => <String>[]).add(edge.targetId);
      indegree[edge.targetId] = (indegree[edge.targetId] ?? 0) + 1;
    }

    final roots = indegree.entries
        .where((e) => e.value == 0)
        .map((e) => e.key)
        .toList()
      ..sort();

    if (roots.isEmpty) {
      // 兜底：有环或无边时，按 ID 顺序退化为单层排列
      roots.addAll(nodeIdSet.toList()..sort());
    }

    final order = <String, int>{};
    final depthMap = <String, int>{};
    final visited = <String>{};
    int cursor = 0;

    void dfs(String id, int depth) {
      if (visited.contains(id)) return;
      visited.add(id);
      depthMap[id] = depth;

      final kids = List<String>.from(children[id] ?? const [])..sort();
      for (final child in kids) {
        dfs(child, depth + 1);
      }

      order[id] = cursor++;
    }

    for (final root in roots) {
      dfs(root, 0);
    }

    // 覆盖孤立节点
    for (final id in nodeIdSet) {
      if (!order.containsKey(id)) {
        order[id] = cursor++;
        depthMap[id] = 0;
      }
    }

    final maxOrder = math.max(1, order.values.isEmpty ? 1 : order.values.reduce(math.max));
    final maxDepth = math.max(1, depthMap.values.isEmpty ? 1 : depthMap.values.reduce(math.max));

    final horizontalUsable = math.max(140.0, canvasSize.width - 96.0);
    final verticalUsable = math.max(160.0, canvasSize.height - 120.0);

    final dx = maxOrder == 0 ? 0 : horizontalUsable / maxOrder;
    final dy = maxDepth == 0 ? 0 : verticalUsable / maxDepth;

    final result = <String, Offset>{};
    for (final id in nodeIdSet) {
      final ox = (order[id] ?? 0) * dx + 48.0 - circleNodeSize / 2;
      final oy = (depthMap[id] ?? 0) * dy + 40.0;
      result[id] = Offset(ox, oy);
    }

    return result;
  }

  Size _entitySize(EntityState entity) {
    if (entity.type == EntityType.treeNode || entity.type == EntityType.graphNode) {
      return const Size(circleNodeSize, circleNodeSize);
    }
    if (entity.type == EntityType.pointer) {
      return const Size(52, 24);
    }
    return const Size(dataNodeSize, dataNodeSize);
  }

  Offset _resolveEntityTopLeft(
    EntityState entity,
    Size canvasSize,
    Offset gridOffset,
    Map<String, Offset>? treeAutoLayout,
    bool swapArrayAxes,
  ) {
    // 指针：绑定 target，位置总是相对目标实体
    if (entity.type == EntityType.pointer && entity.targetId != null) {
      final target = _entities[entity.targetId!];
      if (target != null) {
        final targetPos = _resolveEntityTopLeft(
          target,
          canvasSize,
          gridOffset,
          treeAutoLayout,
          swapArrayAxes,
        );
        final targetSize = _entitySize(target);
        const pointerW = 52.0;
        const pointerH = 24.0;
        return Offset(
          targetPos.dx + targetSize.width / 2 - pointerW / 2,
          targetPos.dy - pointerH - 10,
        );
      }
    }

    // TreeNode 无显式 index 时，使用自动树布局坐标
    if (entity.type == EntityType.treeNode &&
        (entity.index.length < 2 || (entity.index[0] == 0 && entity.index[1] == 0))) {
      final auto = treeAutoLayout?[entity.entityId];
      if (auto != null) return auto;
    }

    final size = _entitySize(entity);
    final rawIx = entity.index.isNotEmpty ? entity.index[0] : 0.0;
    final rawIy = entity.index.length > 1 ? entity.index[1] : 0.0;

    // 树/图优先支持 0~1 相对坐标
    final isRelative =
        (entity.type == EntityType.treeNode || entity.type == EntityType.graphNode) &&
            rawIx >= 0 && rawIx <= 1 && rawIy >= 0 && rawIy <= 1;

    if (isRelative) {
      return Offset(
        (canvasSize.width - size.width) * rawIx,
        (canvasSize.height - size.height) * rawIy,
      );
    }

    final normalized = _normalizedGridIndex(entity, swapArrayAxes);
    final ix = normalized[0];
    final iy = normalized[1];

    // 其他默认走网格坐标
    return Offset(
      ix * gridUnit + gridOffset.dx,
      iy * gridUnit + gridOffset.dy,
    );
  }

  // ===================== 构建层级 =====================
  @override
  Widget build(BuildContext context) {
    final currentStep = _currentStepIndex < widget.script.steps.length
        ? widget.script.steps[_currentStepIndex]
        : null;

    return Scaffold(
      backgroundColor: backgroundOff,
      appBar: AppBar(
        title: Text(widget.script.title),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          _buildNarrationCard(currentStep),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  color: backgroundOff,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                      final swapArrayAxes = _shouldSwapArrayAxes();
                      final gridOffset = _computeGridOffset(canvasSize, swapArrayAxes);
                      final treeAutoLayout = _computeTreeAutoLayout(canvasSize);

                      final centers = _buildEntityCenterMap(
                        canvasSize,
                        gridOffset,
                        treeAutoLayout,
                        swapArrayAxes,
                      );
                      final edgeData = _buildEdgeRenderData(centers);

                      final nodeWidgets = _entities.values
                          .where((e) => e.type != EntityType.pointer)
                          .map((e) => _buildEntityWidget(
                                e,
                                canvasSize,
                                gridOffset,
                                treeAutoLayout,
                                swapArrayAxes,
                              ))
                          .toList();

                      final pointerLineData = _buildPointerLineData(
                        canvasSize,
                        gridOffset,
                        centers,
                        treeAutoLayout,
                        swapArrayAxes,
                      );

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // 背景毛玻璃氛围层（放在最底层，不遮挡动画主体）
                          _buildBackgroundAtmosphere(),

                          CustomPaint(
                            painter: _GridPainter(),
                          ),

                          // 底层：结构连线层（树边/图边）
                          CustomPaint(
                            painter: _EdgesPainter(edges: edgeData),
                          ),

                          // 中上层：指针线层（仅绘制线，不绘制“指针标签”实体）
                          CustomPaint(
                            painter: _PointerLinesPainter(lines: pointerLineData),
                          ),

                          // 顶层：节点层
                          ...nodeWidgets,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildNarrationCard(AnimationStep? currentStep) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '第 ${_currentStepIndex + 1} 步 / 共 ${widget.script.steps.length} 步',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  currentStep?.narration ?? '动画已完成',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textDark,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: '重置',
                  onPressed: _reset,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
                IconButton(
                  tooltip: '上一步',
                  onPressed: _historyStack.isNotEmpty ? _previousStep : null,
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton(
                  tooltip: _isAutoPlaying ? '暂停' : '自动播放',
                  onPressed: _toggleAutoPlay,
                  icon: Icon(_isAutoPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded),
                  color: insightPrimary,
                ),
                IconButton(
                  tooltip: '下一步',
                  onPressed: _currentStepIndex < widget.script.steps.length - 1 ? _nextStep : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, Offset> _buildEntityCenterMap(
    Size canvasSize,
    Offset gridOffset,
    Map<String, Offset> treeAutoLayout,
    bool swapArrayAxes,
  ) {
    final result = <String, Offset>{};
    for (final entity in _entities.values) {
      if (entity.type == EntityType.pointer) continue;
      final topLeft = _resolveEntityTopLeft(
        entity,
        canvasSize,
        gridOffset,
        treeAutoLayout,
        swapArrayAxes,
      );
      final size = _entitySize(entity);
      result[entity.entityId] = Offset(topLeft.dx + size.width / 2, topLeft.dy + size.height / 2);
    }
    return result;
  }

  List<_PointerLineData> _buildPointerLineData(
    Size canvasSize,
    Offset gridOffset,
    Map<String, Offset> centers,
    Map<String, Offset> treeAutoLayout,
    bool swapArrayAxes,
  ) {
    final lines = <_PointerLineData>[];

    for (final pointer in _entities.values.where((e) => e.type == EntityType.pointer)) {
      if (pointer.targetId == null) continue;
      final targetCenter = centers[pointer.targetId!];
      if (targetCenter == null) continue;

      final pointerTopLeft = _resolveEntityTopLeft(
        pointer,
        canvasSize,
        gridOffset,
        treeAutoLayout,
        swapArrayAxes,
      );
      const pointerSize = Size(52, 24);
      final pointerCenter = Offset(
        pointerTopLeft.dx + pointerSize.width / 2,
        pointerTopLeft.dy + pointerSize.height / 2,
      );

      final style = _resolvePointerStyle(pointer);
      lines.add(
        _PointerLineData(
          from: pointerCenter,
          to: targetCenter,
          color: style.color,
          strokeWidth: style.strokeWidth,
          dashPattern: style.dashPattern,
        ),
      );
    }

    return lines;
  }

  _PointerStyle _resolvePointerStyle(EntityState pointer) {
    final raw = '${pointer.value ?? ''} ${pointer.entityId}'.toLowerCase();

    // i 指针：主操作位，纯蓝实线
    if (raw.contains('i')) {
      return const _PointerStyle(
        color: insightPrimary,
        strokeWidth: 2.2,
        dashPattern: null,
      );
    }

    // j 指针：比较位，珊瑚红虚线
    if (raw.contains('j')) {
      return const _PointerStyle(
        color: highlightActive,
        strokeWidth: 2.0,
        dashPattern: [8, 6],
      );
    }

    // pivot：基准位，橙色点划线
    if (raw.contains('pivot') || raw.contains('p')) {
      return const _PointerStyle(
        color: warningColor,
        strokeWidth: 2.4,
        dashPattern: [2, 5],
      );
    }

    // left/right：双指针场景做区分
    if (raw.contains('left') || raw.contains('l')) {
      return const _PointerStyle(
        color: Color(0xFF34A853),
        strokeWidth: 2.1,
        dashPattern: null,
      );
    }

    if (raw.contains('right') || raw.contains('r')) {
      return const _PointerStyle(
        color: Color(0xFF7E57C2),
        strokeWidth: 2.1,
        dashPattern: [10, 5],
      );
    }

    // 兜底：沿用主题色
    return _PointerStyle(
      color: _resolveThemeColor(pointer.theme),
      strokeWidth: 2.0,
      dashPattern: null,
    );
  }

  Widget _buildBackgroundAtmosphere() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            left: -80,
            top: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: insightPrimary.withValues(alpha: _isApplyingStep ? 0.12 : 0.08),
              ),
            ),
          ),
          Positioned(
            right: -70,
            bottom: -80,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: highlightActive.withValues(alpha: _isApplyingStep ? 0.10 : 0.06),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  List<_EdgeRenderData> _buildEdgeRenderData(Map<String, Offset> centers) {
    final data = <_EdgeRenderData>[];

    for (final edge in _edges.values) {
      final start = centers[edge.sourceId];
      final end = centers[edge.targetId];
      if (start == null || end == null) continue;

      data.add(
        _EdgeRenderData(
          start: start,
          end: end,
          color: _resolveThemeColor(edge.theme),
          isDirected: edge.isDirected,
          label: edge.label,
          edgeType: edge.edgeType,
        ),
      );
    }

    return data;
  }

  Widget _buildEntityWidget(
    EntityState entity,
    Size canvasSize,
    Offset gridOffset,
    Map<String, Offset> treeAutoLayout,
    bool swapArrayAxes,
  ) {
    final topLeft = _resolveEntityTopLeft(
      entity,
      canvasSize,
      gridOffset,
      treeAutoLayout,
      swapArrayAxes,
    );
    final size = _entitySize(entity);

    return AnimatedPositioned(
      left: topLeft.dx,
      top: topLeft.dy,
      duration: const Duration(milliseconds: transitionDurationMs),
      curve: Curves.easeInOutCubic,
      child: _buildEntityVisual(entity, size),
    );
  }

  Widget _buildEntityVisual(EntityState entity, Size size) {
    final color = _resolveThemeColor(entity.theme);
    final textColor = (entity.theme == 'default') ? textDark : Colors.white;

    final isCircle = entity.type == EntityType.treeNode || entity.type == EntityType.graphNode;

    return Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: entity.theme == 'default' ? Colors.white : color,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(14),
        border: Border.all(
          color: entity.theme == 'default' ? insightPrimary.withValues(alpha: 0.7) : color,
          width: 1.6,
        ),
        // 新拟物双层阴影：底部暗阴影 + 顶部高光
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.88),
            blurRadius: 8,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        entity.value ?? '',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

/// 画布快照
class _CanvasSnapshot {
  final Map<String, EntityState> entities;
  final Map<String, EdgeState> edges;

  _CanvasSnapshot({
    required this.entities,
    required this.edges,
  });
}

/// 供连线绘制器消费的渲染数据
class _EdgeRenderData {
  final Offset start;
  final Offset end;
  final Color color;
  final bool isDirected;
  final String? label;
  final EdgeType edgeType;

  _EdgeRenderData({
    required this.start,
    required this.end,
    required this.color,
    required this.isDirected,
    required this.label,
    required this.edgeType,
  });
}

/// 指针线渲染数据（只保留线，不渲染指针实体标签）
class _PointerLineData {
  final Offset from;
  final Offset to;
  final Color color;
  final double strokeWidth;
  final List<double>? dashPattern;

  _PointerLineData({
    required this.from,
    required this.to,
    required this.color,
    required this.strokeWidth,
    required this.dashPattern,
  });
}

/// 指针样式配置
class _PointerStyle {
  final Color color;
  final double strokeWidth;
  final List<double>? dashPattern;

  const _PointerStyle({
    required this.color,
    required this.strokeWidth,
    required this.dashPattern,
  });
}

/// 指针线绘制器
class _PointerLinesPainter extends CustomPainter {
  final List<_PointerLineData> lines;

  _PointerLinesPainter({required this.lines});

  @override
  void paint(Canvas canvas, Size size) {
    for (final line in lines) {
      final paint = Paint()
        ..color = line.color.withValues(alpha: 0.9)
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final controlY = (line.from.dy + line.to.dy) / 2;
      final path = Path()
        ..moveTo(line.from.dx, line.from.dy)
        ..quadraticBezierTo(line.from.dx, controlY, line.to.dx, line.to.dy);

      if (line.dashPattern == null || line.dashPattern!.isEmpty) {
        canvas.drawPath(path, paint);
      } else {
        _drawDashedPath(canvas, path, paint, line.dashPattern!);
      }
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, List<double> dashPattern) {
    final metricList = path.computeMetrics();
    for (final metric in metricList) {
      double distance = 0.0;
      int patternIndex = 0;
      bool draw = true;

      while (distance < metric.length) {
        final dashLength = dashPattern[patternIndex % dashPattern.length];
        final next = math.min(distance + dashLength, metric.length);

        if (draw) {
          final extract = metric.extractPath(distance, next);
          canvas.drawPath(extract, paint);
        }

        draw = !draw;
        distance = next;
        patternIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PointerLinesPainter oldDelegate) => true;
}

/// 连线层绘制器（Stack 底层）
class _EdgesPainter extends CustomPainter {
  final List<_EdgeRenderData> edges;

  _EdgesPainter({required this.edges});

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final paint = Paint()
        ..color = edge.color.withValues(alpha: 0.95)
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (edge.edgeType == EdgeType.parentChild) {
        // 树边：使用柔和贝塞尔曲线
        final path = Path();
        final controlY = (edge.start.dy + edge.end.dy) / 2;
        path.moveTo(edge.start.dx, edge.start.dy);
        path.cubicTo(
          edge.start.dx,
          controlY,
          edge.end.dx,
          controlY,
          edge.end.dx,
          edge.end.dy,
        );
        canvas.drawPath(path, paint);
      } else {
        // 图边：直线
        canvas.drawLine(edge.start, edge.end, paint);
      }

      if (edge.isDirected) {
        _drawArrow(canvas, edge.start, edge.end, edge.color);
      }

      if (edge.label != null && edge.label!.trim().isNotEmpty) {
        _drawEdgeLabel(canvas, edge.start, edge.end, edge.label!);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Color color) {
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx);
    const arrowLength = 10.0;
    const arrowAngle = 0.46;

    final p1 = Offset(
      to.dx - arrowLength * math.cos(angle - arrowAngle),
      to.dy - arrowLength * math.sin(angle - arrowAngle),
    );
    final p2 = Offset(
      to.dx - arrowLength * math.cos(angle + arrowAngle),
      to.dy - arrowLength * math.sin(angle + arrowAngle),
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(to, p1, paint);
    canvas.drawLine(to, p2, paint);
  }

  void _drawEdgeLabel(Canvas canvas, Offset start, Offset end, String label) {
    final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF1D1D1F),
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final background = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(mid.dx, mid.dy - 10),
        width: textPainter.width + 10,
        height: textPainter.height + 6,
      ),
      const Radius.circular(8),
    );

    final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.86);
    canvas.drawRRect(background, bgPaint);

    textPainter.paint(
      canvas,
      Offset(mid.dx - textPainter.width / 2, mid.dy - 10 - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _EdgesPainter oldDelegate) {
    // 节点在移动期间会持续重绘，这里保持 true 保证连线实时刷新
    return true;
  }
}

/// 背景网格（弱化显示，避免喧宾夺主）
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFDDE3EA).withValues(alpha: 0.45)
      ..strokeWidth = 0.6;

    const gap = 36.0;

    for (double x = 0; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) => false;
}

