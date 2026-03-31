// 灵犀知径 - DS&A 可视化动画 DSL V3.0
//
// 设计目标：
// 1) 兼容旧版 V1/V2（CREATE/UPDATE/SWAP/DELETE + DataNode/Pointer）
// 2) 支持树/图结构（TreeNode/GraphNode + CONNECT_EDGE）
// 3) 支持 DP 语义动作（UPDATE_CELL）
// 4) 为画布渲染层提供类型安全、可扩展的数据模型

/// 整个动画剧本
class AnimationScript {
  final String animationId;
  final String title;
  final String scene;
  final List<AnimationStep> steps;

  AnimationScript({
    required this.animationId,
    required this.title,
    required this.scene,
    required this.steps,
  });

  factory AnimationScript.fromJson(Map<String, dynamic> json) {
    return AnimationScript(
      animationId: (json['animation_id'] ?? json['animationId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      scene: (json['scene'] ?? '').toString(),
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .map((e) => AnimationStep.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'animation_id': animationId,
      'title': title,
      if (scene.isNotEmpty) 'scene': scene,
      'steps': steps.map((e) => e.toJson()).toList(),
    };
  }
}

/// 单个步骤：每次点击“下一步”执行一步中的全部动作
class AnimationStep {
  final int stepIndex;
  final String narration;
  final List<AnimationAction> actions;

  AnimationStep({
    required this.stepIndex,
    required this.narration,
    required this.actions,
  });

  factory AnimationStep.fromJson(Map<String, dynamic> json) {
    return AnimationStep(
      stepIndex: _toInt(json['step_index'] ?? json['stepIndex']) ?? 0,
      narration: (json['narration'] ?? '').toString(),
      actions: (json['actions'] as List<dynamic>? ?? const [])
          .map((e) => AnimationAction.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step_index': stepIndex,
      'narration': narration,
      'actions': actions.map((e) => e.toJson()).toList(),
    };
  }
}

/// 实体类型：V3 新增 TreeNode / GraphNode
///
/// - dataNode: 一维数组、普通格子
/// - pointer: 指针或标记（i / j / left / right）
/// - arrayContainer: 容器（可选）
/// - treeNode: 树节点（圆形）
/// - graphNode: 图节点（圆形）
enum EntityType {
  dataNode,
  pointer,
  arrayContainer,
  treeNode,
  graphNode;

  static EntityType fromString(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    switch (value) {
      case 'datanode':
      case 'arraynode':
        return EntityType.dataNode;
      case 'pointer':
        return EntityType.pointer;
      case 'arraycontainer':
        return EntityType.arrayContainer;
      case 'treenode':
        return EntityType.treeNode;
      case 'graphnode':
        return EntityType.graphNode;
      default:
        return EntityType.dataNode;
    }
  }

  String toWire() {
    switch (this) {
      case EntityType.dataNode:
        return 'DataNode';
      case EntityType.pointer:
        return 'Pointer';
      case EntityType.arrayContainer:
        return 'ArrayContainer';
      case EntityType.treeNode:
        return 'TreeNode';
      case EntityType.graphNode:
        return 'GraphNode';
    }
  }
}

/// 动作类型：V3 新增 CONNECT_EDGE / UPDATE_CELL / DISCONNECT
///
/// 兼容：CONNECT 也会按 CONNECT_EDGE 解析
enum ActionType {
  create,
  update,
  swap,
  delete,
  connectEdge,
  disconnect,
  updateCell;

  static ActionType fromString(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    switch (value) {
      case 'CREATE':
        return ActionType.create;
      case 'UPDATE':
        return ActionType.update;
      case 'SWAP':
        return ActionType.swap;
      case 'DELETE':
        return ActionType.delete;
      case 'CONNECT':
      case 'CONNECT_EDGE':
        return ActionType.connectEdge;
      case 'DISCONNECT':
        return ActionType.disconnect;
      case 'UPDATE_CELL':
        return ActionType.updateCell;
      default:
        return ActionType.update;
    }
  }

  String toWire() {
    switch (this) {
      case ActionType.create:
        return 'CREATE';
      case ActionType.update:
        return 'UPDATE';
      case ActionType.swap:
        return 'SWAP';
      case ActionType.delete:
        return 'DELETE';
      case ActionType.connectEdge:
        return 'CONNECT_EDGE';
      case ActionType.disconnect:
        return 'DISCONNECT';
      case ActionType.updateCell:
        return 'UPDATE_CELL';
    }
  }
}

/// 连线类型
/// - parentChild: 树父子边（更适合曲线）
/// - graphEdge: 图边（直线）
enum EdgeType {
  parentChild,
  graphEdge;

  static EdgeType fromString(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    switch (value) {
      case 'parent_child':
      case 'parentchild':
        return EdgeType.parentChild;
      case 'graph_edge':
      case 'graphedge':
      default:
        return EdgeType.graphEdge;
    }
  }

  String toWire() {
    switch (this) {
      case EdgeType.parentChild:
        return 'parent_child';
      case EdgeType.graphEdge:
        return 'graph_edge';
    }
  }
}

/// 动作基类
sealed class AnimationAction {
  ActionType get actionType;

  factory AnimationAction.fromJson(Map<String, dynamic> json) {
    final type = ActionType.fromString(json['action']?.toString());
    switch (type) {
      case ActionType.create:
        return CreateAction.fromJson(json);
      case ActionType.update:
        return UpdateAction.fromJson(json);
      case ActionType.swap:
        return SwapAction.fromJson(json);
      case ActionType.delete:
        return DeleteAction.fromJson(json);
      case ActionType.connectEdge:
        return ConnectEdgeAction.fromJson(json);
      case ActionType.disconnect:
        return DisconnectEdgeAction.fromJson(json);
      case ActionType.updateCell:
        return UpdateCellAction.fromJson(json);
    }
  }

  Map<String, dynamic> toJson();
}

/// CREATE：创建实体（节点、指针等）
class CreateAction implements AnimationAction {
  @override
  final ActionType actionType = ActionType.create;

  final String entityId;
  final EntityType type;
  final String? value;
  final List<double>? index; // 支持整数网格，也支持 0~1 相对坐标
  final int? pos; // V4: 一维数组槽位
  final String? targetId; // 指针可指向目标
  final String? theme;

  CreateAction({
    required this.entityId,
    required this.type,
    this.value,
    this.index,
    this.pos,
    this.targetId,
    this.theme,
  });

  factory CreateAction.fromJson(Map<String, dynamic> json) {
    return CreateAction(
      entityId: (json['entity_id'] ?? json['entityId'] ?? '').toString(),
      type: EntityType.fromString(json['type']?.toString()),
      value: json['value']?.toString(),
      index: _toDoubleList(json['index']),
      pos: _toInt(json['pos']),
      targetId: (json['target_id'] ?? json['targetId'])?.toString(),
      theme: json['theme']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionType.toWire(),
      'entity_id': entityId,
      'type': type.toWire(),
      if (value != null) 'value': value,
      if (index != null) 'index': index,
      if (pos != null) 'pos': pos,
      if (targetId != null) 'target_id': targetId,
      if (theme != null) 'theme': theme,
    };
  }
}

/// UPDATE：更新实体（主题、位置、目标、文本）
class UpdateAction implements AnimationAction {
  @override
  final ActionType actionType = ActionType.update;

  final String entityId;
  final String? theme;
  final String? targetId;
  final List<double>? index;
  final String? value;

  UpdateAction({
    required this.entityId,
    this.theme,
    this.targetId,
    this.index,
    this.value,
  });

  factory UpdateAction.fromJson(Map<String, dynamic> json) {
    return UpdateAction(
      entityId: (json['entity_id'] ?? json['entityId'] ?? '').toString(),
      theme: json['theme']?.toString(),
      targetId: (json['target_id'] ?? json['targetId'])?.toString(),
      index: _toDoubleList(json['index']),
      value: json['value']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionType.toWire(),
      'entity_id': entityId,
      if (theme != null) 'theme': theme,
      if (targetId != null) 'target_id': targetId,
      if (index != null) 'index': index,
      if (value != null) 'value': value,
    };
  }
}

/// SWAP：交换两个实体的逻辑位置
class SwapAction implements AnimationAction {
  @override
  final ActionType actionType = ActionType.swap;

  final String entityId1;
  final String entityId2;

  SwapAction({
    required this.entityId1,
    required this.entityId2,
  });

  factory SwapAction.fromJson(Map<String, dynamic> json) {
    return SwapAction(
      entityId1: (json['entity_id_1'] ?? json['entityId1'] ?? '').toString(),
      entityId2: (json['entity_id_2'] ?? json['entityId2'] ?? '').toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionType.toWire(),
      'entity_id_1': entityId1,
      'entity_id_2': entityId2,
    };
  }
}

/// DELETE：删除实体
class DeleteAction implements AnimationAction {
  @override
  final ActionType actionType = ActionType.delete;

  final String entityId;

  DeleteAction({required this.entityId});

  factory DeleteAction.fromJson(Map<String, dynamic> json) {
    return DeleteAction(
      entityId: (json['entity_id'] ?? json['entityId'] ?? '').toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionType.toWire(),
      'entity_id': entityId,
    };
  }
}

/// CONNECT_EDGE：创建连线关系（不是创建新实体）
class ConnectEdgeAction implements AnimationAction {
  @override
  final ActionType actionType = ActionType.connectEdge;

  final String sourceEntityId;
  final String targetId;
  final EdgeType edgeType;
  final bool isDirected;
  final String? label;
  final String? theme;

  ConnectEdgeAction({
    required this.sourceEntityId,
    required this.targetId,
    required this.edgeType,
    this.isDirected = false,
    this.label,
    this.theme,
  });

  factory ConnectEdgeAction.fromJson(Map<String, dynamic> json) {
    return ConnectEdgeAction(
      sourceEntityId: (json['source_entity_id'] ?? json['source_id'] ?? '').toString(),
      targetId: (json['target_id'] ?? json['targetId'] ?? '').toString(),
      edgeType: EdgeType.fromString((json['type'] ?? json['edge_type'])?.toString()),
      isDirected: _toBool(json['is_directed']) ?? false,
      label: json['label']?.toString(),
      theme: json['theme']?.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionType.toWire(),
      'source_entity_id': sourceEntityId,
      'target_id': targetId,
      'type': edgeType.toWire(),
      'is_directed': isDirected,
      if (label != null) 'label': label,
      if (theme != null) 'theme': theme,
    };
  }
}

/// DISCONNECT：删除连线关系
class DisconnectEdgeAction implements AnimationAction {
  @override
  final ActionType actionType = ActionType.disconnect;

  final String sourceEntityId;
  final String targetId;

  DisconnectEdgeAction({
    required this.sourceEntityId,
    required this.targetId,
  });

  factory DisconnectEdgeAction.fromJson(Map<String, dynamic> json) {
    return DisconnectEdgeAction(
      sourceEntityId: (json['source_entity_id'] ?? json['source_id'] ?? '').toString(),
      targetId: (json['target_id'] ?? json['targetId'] ?? '').toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionType.toWire(),
      'source_entity_id': sourceEntityId,
      'target_id': targetId,
    };
  }
}

/// UPDATE_CELL：DP 专用更新动作
///
/// 语义：
/// - row/col 标识二维格子
/// - value 为填充值
/// - theme 体现状态流：依赖高亮 -> 填充值 -> 锁定
class UpdateCellAction implements AnimationAction {
  @override
  final ActionType actionType = ActionType.updateCell;

  final int row;
  final int col;
  final String value;
  final String? theme;
  final String? entityId; // 可选，若无则画布可按 row/col 生成稳定 ID

  UpdateCellAction({
    required this.row,
    required this.col,
    required this.value,
    this.theme,
    this.entityId,
  });

  factory UpdateCellAction.fromJson(Map<String, dynamic> json) {
    return UpdateCellAction(
      row: _toInt(json['row']) ?? 0,
      col: _toInt(json['col']) ?? 0,
      value: (json['value'] ?? '').toString(),
      theme: json['theme']?.toString(),
      entityId: (json['entity_id'] ?? json['entityId'])?.toString(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'action': actionType.toWire(),
      'row': row,
      'col': col,
      'value': value,
      if (theme != null) 'theme': theme,
      if (entityId != null) 'entity_id': entityId,
    };
  }
}

/// 画布实体状态
class EntityState {
  final String entityId;
  final EntityType type;
  String? value;
  List<double> index; // [x, y]，统一逻辑坐标
  String theme;
  String? targetId;

  EntityState({
    required this.entityId,
    required this.type,
    this.value,
    this.index = const [0, 0],
    this.theme = 'default',
    this.targetId,
  });

  EntityState deepCopy() {
    return EntityState(
      entityId: entityId,
      type: type,
      value: value,
      index: List<double>.from(index),
      theme: theme,
      targetId: targetId,
    );
  }
}

/// 画布连线状态
class EdgeState {
  final String sourceId;
  final String targetId;
  final EdgeType edgeType;
  final bool isDirected;
  final String? label;
  final String theme;

  EdgeState({
    required this.sourceId,
    required this.targetId,
    required this.edgeType,
    required this.isDirected,
    this.label,
    this.theme = 'default',
  });

  /// 为 Map 存储生成稳定 key
  String get key => '$sourceId->$targetId';

  EdgeState deepCopy() {
    return EdgeState(
      sourceId: sourceId,
      targetId: targetId,
      edgeType: edgeType,
      isDirected: isDirected,
      label: label,
      theme: theme,
    );
  }
}

int? _toInt(dynamic raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  if (raw is String) return int.tryParse(raw);
  return null;
}

bool? _toBool(dynamic raw) {
  if (raw is bool) return raw;
  if (raw is String) {
    final value = raw.toLowerCase();
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return null;
}

List<double>? _toDoubleList(dynamic raw) {
  if (raw is! List) return null;
  final values = raw.map((e) {
    if (e is num) return e.toDouble();
    return double.tryParse(e.toString()) ?? 0.0;
  }).toList();
  if (values.length < 2) return null;
  return [values[0], values[1]];
}
