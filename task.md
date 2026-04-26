# 任务目标：开发用于全国比赛录屏演示的“高保真伪造页面（Mock Pages）”

当前项目背景：我们需要为一段关于“教师经验资产化与步进式启发”的视频演示，开发两个独立的 Flutter 页面。为了保证录屏绝对不卡顿、不报错，**要求完全不请求任何后端接口**，所有对话状态、UI 联动和 DSL 动画 JSON 必须在前端硬编码实现。

请在 `frontend/src/InsightPath/lib/pages/demo/` 目录下（若无此目录请创建），新建以下两个文件，并严格按照以下指示实现逻辑。

## 任务 1：创建教师端“知径”配置演示页
**文件路径：** `lib/pages/demo/teacher_insight_mapper_demo.dart`

**UI 布局要求：**
采用左右分栏的 Web 端/Pad 端大屏布局（深色科技风主题，背景色 `#0A0A0A`）。
* **左侧 (代码与流程区, 占 60%)：**
    * 顶部标题：“知径 (Insight-Mapper) 逻辑配置台”。
    * 中间展示一段高亮的伪代码：`for(int j = length; j > i; j--) { data[j] = data[j-1]; }`。
    * 代码下方展示一个流程图节点 UI：中心是“循环边界判定”，分出两个子节点：“分叉A：顺序逆转” 和 “分叉C：正确倒序”。
* **右侧 (配置面板区, 占 40%)：**
    * 面板标题：“节点事件配置”。
    * 包含表单项（不可编辑的只读展示态即可，为了录屏）：
        * **触发条件：** 文本框显示 `[错误捕捉] 用户输入包含 "j=i"`
        * **启发提示词 (Hint)：** 文本框显示 `“观察一下：如果先移动索引为2的元素30，它会直接覆盖掉40。40还在内存里吗？”`
        * **联动 DSL 动作：** 下拉框显示 `触发动画：[数据覆盖警告动图]`

## 任务 2：创建学生端步进引导演示页
**文件路径：** `lib/pages/demo/student_step_guide_demo.dart`

**UI 布局要求：**
采用上下分栏的手机端布局。
* **上半部分 (占 40%)：** 放置 `AnimationCanvas` 组件（复用现有的画布组件）。
* **下半部分 (占 60%)：** 放置类似聊天的交互界面（一个消息列表，底部一个输入框和发送按钮）。

**核心交互状态机（硬编码逻辑）：**
页面需要维护一个消息列表 `List<AiMessage>`。
1.  **初始状态：** * 聊天区显示 AI 消息：“要在索引 2 插入元素 99，为了腾出位置，for 循环的初始变量 j 应该设为 i 还是 length？”
    * 画布置空，或者显示初始数组 `[10, 20, 30, 40, 50]`。
2.  **触发分叉 A（模拟学生犯错）：**
    * 当在输入框输入 `j = i` 或包含 `i` 的文字并发送时。
    * 把学生的文字加入聊天列表。
    * 延迟 500 毫秒（模拟请求），聊天区追加 AI 消息：“观察一下：如果你先移动索引为 2 的元素 30，它会直接覆盖掉索引为 3 的元素 40。这时 40 还在内存里吗？”（这里精准对齐老师的预设）。
    * **触发画布更新**：将硬编码的 `error_dsl_script` 传给画布，播放元素 30 移动到 40 的位置并爆红的动画。
3.  **触发分叉 C（模拟学生改正）：**
    * 当输入框输入 `length` 或 `j = length` 并发送时。
    * 聊天区追加 AI 消息：“非常精准！从表尾倒序移动可以保护现有数据。那么，接下来腾出来的空位在哪里？”
    * **触发画布更新**：将硬编码的 `correct_dsl_script` 传给画布，播放数组从后往前移位，并在索引 2 处出现一个绿色高亮空位的动画。

## 任务 3：提供硬编码的 DSL 数据结构
请在 `student_step_guide_demo.dart` 中定义以下两个常量，用于传给画布解析。请根据项目中 `AnimationScript` 的实际解析格式进行适当调整，但核心表现如下：

```dart
// 模拟错误：覆盖数据时的 DSL 指令
final String error_dsl_script = '''
{
  "version": "4.0",
  "title": "错误：数据覆盖",
  "scene": "array",
  "steps": [
    {
      "step_index": 1,
      "narration": "将 data[2] 赋值给 data[3]",
      "actions": [
        {"action": "UPDATE", "entity_id": "node_3", "theme": "error", "value": "30(覆盖)"}
      ]
    }
  ]
}
''';

// 模拟正确：腾出空位时的 DSL 指令
final String correct_dsl_script = '''
{
  "version": "4.0",
  "title": "正确：腾出空位",
  "scene": "array",
  "steps": [
    {
      "step_index": 1,
      "narration": "倒序移动元素，腾出索引 2",
      "actions": [
        {"action": "UPDATE", "entity_id": "node_5", "value": "50"},
        {"action": "UPDATE", "entity_id": "node_4", "value": "40"},
        {"action": "UPDATE", "entity_id": "node_3", "value": "30"},
        {"action": "UPDATE", "entity_id": "node_2", "theme": "active", "value": "空"}
      ]
    }
  ]
}
''';


任务 4：提供演示入口
请你在教师编辑题目时的页面创建一个入口，一个不起眼的地方添加一个图标按钮（例如一个星星图标），点击后 Navigator.push 跳转到 teacher_insight_mapper_demo.dart。
同理，在学生端的做题页面也加一个隐藏入口跳转到 student_step_guide_demo.dart。方便录屏时直接进入。

执行要求：代码要规范，直接使用项目中现有的 UI 样式库（AppTheme 等）保持视觉一致性。不要修改后端接口。