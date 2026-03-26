  // 灵犀知径 - 交互式动画 DSL 数据模型
// 将 JSON 协议映射为 Dart class，提供类型安全和序列化支持

// ============ 根对象 ============
/// 整个动画剧本
class AnimationScript {
  final String animationId;
  final String title;
  final List<AnimationStep> steps;

  AnimationScript({
    required this.animationId,
    required this.title,
    required this.steps,
  });

  factory AnimationScript.fromJson(Map<String, dynamic> json) {
    return AnimationScript(
      animationId: json['animation_id'] ?? '',
      title: json['title'] ?? '',
      steps: (json['steps'] as List?)
              ?.map((s) => AnimationStep.fromJson(s))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'animation_id': animationId,
        'title': title,
        'steps': steps.map((s) => s.toJson()).toList(),
      };
}

// ============ 步骤 ============
/// 单个步骤：每次点击"下一步"执行一个 Step
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
      stepIndex: json['step_index'] ?? 0,
      narration: json['narration'] ?? '',
      actions: (json['actions'] as List?)
              ?.map((a) => AnimationAction.fromJson(a))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'step_index': stepIndex,
        'narration': narration,
        'actions': actions.map((a) => a.toJson()).toList(),
      };
}

// ============ 动作基类与子类 ============
/// 动作基类：所有画布操作指令
sealed class AnimationAction {
  String get actionType;

  factory AnimationAction.fromJson(Map<String, dynamic> json) {
    final actionType = json['action'] as String?;
    switch (actionType) {
      case 'CREATE':
        return CreateAction.fromJson(json);
      case 'UPDATE':
        return UpdateAction.fromJson(json);
      case 'SWAP':
        return SwapAction.fromJson(json);
      case 'DELETE':
        return DeleteAction.fromJson(json);
      default:
        throw Exception('Unknown action type: $actionType');
    }
  }

  Map<String, dynamic> toJson();
}

/// CREATE: 在画布上创建新实体
class CreateAction implements AnimationAction {
  @override
  String get actionType => 'CREATE';
  final String entityId;
  final String type; // "DataNode" | "Pointer" | "ArrayContainer"
  final String? value;
  final List<int>? index; // [x, y]
  final String? targetId;

  CreateAction({
    required this.entityId,
    required this.type,
    this.value,
    this.index,
    this.targetId,
  });

  factory CreateAction.fromJson(Map<String, dynamic> json) {
    return CreateAction(
      entityId: json['entity_id'] ?? '',
      type: json['type'] ?? 'DataNode',
      value: json['value'],
      index: (json['index'] as List?)?.cast<int>(),
      targetId: json['target_id'],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'action': actionType,
        'entity_id': entityId,
        'type': type,
        if (value != null) 'value': value,
        if (index != null) 'index': index,
        if (targetId != null) 'target_id': targetId,
      };
}

/// UPDATE: 更新实体属性或位置
class UpdateAction implements AnimationAction {
  @override
  String get actionType => 'UPDATE';
  final String entityId;
  final String? theme; // "default" | "active" | "highlight_red" | "locked_green"
  final String? targetId;
  final List<int>? index;

  UpdateAction({
    required this.entityId,
    this.theme,
    this.targetId,
    this.index,
  });

  factory UpdateAction.fromJson(Map<String, dynamic> json) {
    return UpdateAction(
      entityId: json['entity_id'] ?? '',
      theme: json['theme'],
      targetId: json['target_id'],
      index: (json['index'] as List?)?.cast<int>(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'action': actionType,
        'entity_id': entityId,
        if (theme != null) 'theme': theme,
        if (targetId != null) 'target_id': targetId,
        if (index != null) 'index': index,
      };
}

/// SWAP: 交换两个实体的物理位置
class SwapAction implements AnimationAction {
  @override
  String get actionType => 'SWAP';
  final String entityId1;
  final String entityId2;

  SwapAction({
    required this.entityId1,
    required this.entityId2,
  });

  factory SwapAction.fromJson(Map<String, dynamic> json) {
    return SwapAction(
      entityId1: json['entity_id_1'] ?? '',
      entityId2: json['entity_id_2'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'action': actionType,
        'entity_id_1': entityId1,
        'entity_id_2': entityId2,
      };
}

/// DELETE: 销毁实体
class DeleteAction implements AnimationAction {
  @override
  String get actionType => 'DELETE';
  final String entityId;

  DeleteAction({
    required this.entityId,
  });

  factory DeleteAction.fromJson(Map<String, dynamic> json) {
    return DeleteAction(
      entityId: json['entity_id'] ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'action': actionType,
        'entity_id': entityId,
      };
}

// ============ 画布实体状态 ============
/// 画布上单个实体的状态快照
class EntityState {
  final String entityId;
  final String type; // "DataNode" | "Pointer" | "ArrayContainer"
  String? value;
  List<int> index; // 逻辑坐标 [x, y]
  String theme; // 颜色主题
  String? targetId; // 仅对 Pointer 有效

  EntityState({
    required this.entityId,
    required this.type,
    this.value,
    this.index = const [0, 0],
    this.theme = 'default',
    this.targetId,
  });

  /// 深度拷贝，用于历史栈
  EntityState deepCopy() {
    return EntityState(
      entityId: entityId,
      type: type,
      value: value,
      index: List<int>.from(index),
      theme: theme,
      targetId: targetId,
    );
  }
}

