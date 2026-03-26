import '../models/animation_dsl.dart';

/// 动画脚本库 - 包含多个预设演示
class AnimationScriptLibrary {
  /// 冒泡排序完整演示（5 个元素）
  static AnimationScript getBubbleSortDemo() {
    return AnimationScript(
      animationId: 'bubble_sort_demo_001',
      title: '冒泡排序演示',
      steps: [
        // 第 1 步：初始化
        AnimationStep(
          stepIndex: 1,
          narration: '初始化数组 [5, 2, 8, 1, 9]。冒泡排序将通过多次比较和交换来排序。',
          actions: [
            CreateAction(
              entityId: 'node_0',
              type: 'DataNode',
              value: '5',
              index: [0, 0],
            ),
            CreateAction(
              entityId: 'node_1',
              type: 'DataNode',
              value: '2',
              index: [1, 0],
            ),
            CreateAction(
              entityId: 'node_2',
              type: 'DataNode',
              value: '8',
              index: [2, 0],
            ),
            CreateAction(
              entityId: 'node_3',
              type: 'DataNode',
              value: '1',
              index: [3, 0],
            ),
            CreateAction(
              entityId: 'node_4',
              type: 'DataNode',
              value: '9',
              index: [4, 0],
            ),
            CreateAction(
              entityId: 'pointer_i',
              type: 'Pointer',
              value: 'i',
              targetId: 'node_0',
            ),
            CreateAction(
              entityId: 'pointer_j',
              type: 'Pointer',
              value: 'j',
              targetId: 'node_1',
            ),
          ],
        ),

        // 第 2 步：比较 5 和 2
        AnimationStep(
          stepIndex: 2,
          narration: '比较 arr[0]=5 和 arr[1]=2。因为 5 > 2，需要交换。',
          actions: [
            UpdateAction(
              entityId: 'node_0',
              theme: 'highlight_red',
            ),
            UpdateAction(
              entityId: 'node_1',
              theme: 'highlight_red',
            ),
          ],
        ),

        // 第 3 步：执行交换
        AnimationStep(
          stepIndex: 3,
          narration: '执行交换。数组现在是 [2, 5, 8, 1, 9]。',
          actions: [
            SwapAction(
              entityId1: 'node_0',
              entityId2: 'node_1',
            ),
            UpdateAction(
              entityId: 'node_0',
              theme: 'default',
            ),
            UpdateAction(
              entityId: 'node_1',
              theme: 'default',
            ),
          ],
        ),

        // 第 4 步：比较 5 和 8
        AnimationStep(
          stepIndex: 4,
          narration: '比较 arr[1]=5 和 arr[2]=8。因为 5 < 8，无需交换。',
          actions: [
            UpdateAction(
              entityId: 'node_1',
              theme: 'active',
            ),
            UpdateAction(
              entityId: 'node_2',
              theme: 'active',
            ),
          ],
        ),

        // 第 5 步：比较 8 和 1
        AnimationStep(
          stepIndex: 5,
          narration: '比较 arr[2]=8 和 arr[3]=1。因为 8 > 1，需要交换。',
          actions: [
            UpdateAction(
              entityId: 'node_1',
              theme: 'default',
            ),
            UpdateAction(
              entityId: 'node_2',
              theme: 'highlight_red',
            ),
            UpdateAction(
              entityId: 'node_3',
              theme: 'highlight_red',
            ),
          ],
        ),

        // 第 6 步：执行交换
        AnimationStep(
          stepIndex: 6,
          narration: '执行交换。数组现在是 [2, 5, 1, 8, 9]。',
          actions: [
            SwapAction(
              entityId1: 'node_2',
              entityId2: 'node_3',
            ),
            UpdateAction(
              entityId: 'node_2',
              theme: 'default',
            ),
            UpdateAction(
              entityId: 'node_3',
              theme: 'default',
            ),
          ],
        ),

        // 第 7 步：比较 8 和 9
        AnimationStep(
          stepIndex: 7,
          narration: '比较 arr[3]=8 和 arr[4]=9。因为 8 < 9，无需交换。',
          actions: [
            UpdateAction(
              entityId: 'node_3',
              theme: 'active',
            ),
            UpdateAction(
              entityId: 'node_4',
              theme: 'active',
            ),
          ],
        ),

        // 第 8 步：第一轮完成
        AnimationStep(
          stepIndex: 8,
          narration: '第一轮冒泡排序完成。最大元素 9 已到达最后位置。',
          actions: [
            UpdateAction(
              entityId: 'node_3',
              theme: 'default',
            ),
            UpdateAction(
              entityId: 'node_4',
              theme: 'locked_green',
            ),
          ],
        ),
      ],
    );
  }

  /// 二分查找演示
  static AnimationScript getBinarySearchDemo() {
    return AnimationScript(
      animationId: 'binary_search_demo_001',
      title: '二分查找演示',
      steps: [
        // 初始化有序数组
        AnimationStep(
          stepIndex: 1,
          narration: '初始化有序数组 [1, 3, 5, 7, 9, 11, 13]。我们要查找目标值 7。',
          actions: [
            CreateAction(
              entityId: 'node_0',
              type: 'DataNode',
              value: '1',
              index: [0, 0],
            ),
            CreateAction(
              entityId: 'node_1',
              type: 'DataNode',
              value: '3',
              index: [1, 0],
            ),
            CreateAction(
              entityId: 'node_2',
              type: 'DataNode',
              value: '5',
              index: [2, 0],
            ),
            CreateAction(
              entityId: 'node_3',
              type: 'DataNode',
              value: '7',
              index: [3, 0],
            ),
            CreateAction(
              entityId: 'node_4',
              type: 'DataNode',
              value: '9',
              index: [4, 0],
            ),
            CreateAction(
              entityId: 'node_5',
              type: 'DataNode',
              value: '11',
              index: [5, 0],
            ),
            CreateAction(
              entityId: 'node_6',
              type: 'DataNode',
              value: '13',
              index: [6, 0],
            ),
            CreateAction(
              entityId: 'pointer_left',
              type: 'Pointer',
              value: 'L',
              targetId: 'node_0',
            ),
            CreateAction(
              entityId: 'pointer_right',
              type: 'Pointer',
              value: 'R',
              targetId: 'node_6',
            ),
          ],
        ),

        // 第一次比较
        AnimationStep(
          stepIndex: 2,
          narration: '计算中点：mid = (0 + 6) / 2 = 3。比较 arr[3]=7 与目标值 7。',
          actions: [
            CreateAction(
              entityId: 'pointer_mid',
              type: 'Pointer',
              value: 'M',
              targetId: 'node_3',
            ),
            UpdateAction(
              entityId: 'node_3',
              theme: 'highlight_red',
            ),
          ],
        ),

        // 找到目标
        AnimationStep(
          stepIndex: 3,
          narration: '找到目标！arr[3] = 7 等于目标值。查找成功。',
          actions: [
            UpdateAction(
              entityId: 'node_3',
              theme: 'locked_green',
            ),
          ],
        ),
      ],
    );
  }

  /// 链表插入演示
  static AnimationScript getLinkedListDemo() {
    return AnimationScript(
      animationId: 'linked_list_demo_001',
      title: '链表插入演示',
      steps: [
        // 初始化链表
        AnimationStep(
          stepIndex: 1,
          narration: '初始化链表：1 -> 3 -> 5。我们要在 3 后面插入 4。',
          actions: [
            CreateAction(
              entityId: 'node_1',
              type: 'DataNode',
              value: '1',
              index: [0, 0],
            ),
            CreateAction(
              entityId: 'node_3',
              type: 'DataNode',
              value: '3',
              index: [2, 0],
            ),
            CreateAction(
              entityId: 'node_5',
              type: 'DataNode',
              value: '5',
              index: [4, 0],
            ),
          ],
        ),

        // 创建新节点
        AnimationStep(
          stepIndex: 2,
          narration: '创建新节点，值为 4。',
          actions: [
            CreateAction(
              entityId: 'node_4_new',
              type: 'DataNode',
              value: '4',
              index: [3, 1],
            ),
          ],
        ),

        // 调整指针
        AnimationStep(
          stepIndex: 3,
          narration: '调整指针：node_3 的 next 指向 node_4_new，node_4_new 的 next 指向 node_5。',
          actions: [
            UpdateAction(
              entityId: 'node_4_new',
              theme: 'active',
            ),
          ],
        ),

        // 插入完成
        AnimationStep(
          stepIndex: 4,
          narration: '插入完成！链表现在是：1 -> 3 -> 4 -> 5。',
          actions: [
            UpdateAction(
              entityId: 'node_4_new',
              theme: 'locked_green',
            ),
          ],
        ),
      ],
    );
  }
}

