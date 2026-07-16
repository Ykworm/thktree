# 对话页模型选择面板交互简化

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-26 |
| 范围 | chat 模块（`ModelSelectorPanel` 关闭交互 + `ChatScreen` 集成） |
| 设计文档 | `docs/_tmp/chat-model-panel-dismiss.md`（brainstorming 草稿，merge 后清理） |
| War Story | （无） |
| 状态 | ✅ 完成 |

## 背景

`ModelSelectorPanel` 原来有一行标题栏：「选择模型」+ 右侧 X 关闭按钮。问题是：

- **关闭按钮冗余**：iOS 用户对 sheet 的关闭预期是「点 sheet 外部即可收起」+「下拉手势」，多一个 X 按钮属于桌面 / 网页残留风格
- **点击外部不响应**：用户点消息列表 / 输入框 / context bar 时 panel 不消失，必须先点 X 才能继续操作，体感卡顿
- **标题栏占位**：标题栏占 44pt 高度，但右侧 X 按钮本身就是「点 panel 自身才能关闭」的反向语义

产品决定：移除关闭按钮，panel 唯一关闭方式变为「点 panel 外部」。

## 方案

走 **方案 A：透明遮罩 + 删按钮**——`Stack` 外层包 `Positioned.fill` 透明 `GestureDetector` + 标题栏只保留「选择模型」文字。

放弃方案：

- **方案 B（下拉手势）**：iOS sheet 标配，但 Flutter `CupertinoSheetRoute` 在 panel 嵌入 Column 时手势衔接不自然；产品接受「点外部关闭」就足够
- **方案 C（保留按钮 + 加外部关闭）**：违背「移除按钮」的需求

## 实施内容

### 修改文件（2）

```
lib/ui/features/chat/chat_screen.dart                    # Stack + Listener + Positioned.fill 透明遮罩
lib/ui/features/chat/widgets/model_selector_panel.dart   # 删除 onClose 回调，标题栏只留 Text
```

### 关键改动

**`chat_screen.dart` — Column 外层包 Stack：**

```dart
child: Stack(
  children: [
    Column(
      children: [
        // 消息列表（自身 GestureDetector 保留）
        Expanded(child: GestureDetector(...)),
        // Context 使用条
        messagesAsync.maybeWhen(...),
        // 输入框：包 Listener(onPointerDown) 关闭 panel
        Listener(
          onPointerDown: (_) {
            if (_showModelPanel) setState(() => _showModelPanel = false);
          },
          child: ChatComposer(...),
        ),
        // 模型面板（删除 onClose 参数）
        if (_showModelPanel && !isStreaming)
          Flexible(
            child: ModelSelectorPanel(
              currentProviderId: currentProviderId,
              currentModelId: currentModelId,
              onModelSelected: (providerId, modelId) async {...},
            ),
          ),
      ],
    ),
    // 透明遮罩：点 panel 外部触发关闭
    if (_showModelPanel && !isStreaming)
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => setState(() => _showModelPanel = false),
        ),
      ),
  ],
),
```

**`model_selector_panel.dart` — 删除关闭按钮：**

- 删除 `onClose` 回调参数
- 标题栏从 `Row(Text + Spacer + CupertinoButton)` 简化为 `Text('选择模型')`
- 文档注释更新 dismiss 语义

### 关键技术点：为什么 `ChatComposer` 用 `Listener` 而非 `GestureDetector`

输入框内嵌 `TextField`，`TextField` 的 `TapGestureRecognizer` 会在 gesture arena 中抢占 tap。如果用 `GestureDetector` 包外层，arena 竞争时 `TextField` 胜出，输入框点击不再触发外层关闭。

`Listener(onPointerDown)` 不参与 arena，pointer down 阶段立即触发，绕开冲突——输入框点击也能关闭 panel。`Positioned.fill` 透明遮罩用 `HitTestBehavior.translucent`（不挡 panel 内部 hit test）+ 暴露 tap 给透明区域。

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 无错（增量） |
| 集成测试 | ⚠️ 未新增。本改动属于纯 UI 交互（hit test / arena），无业务逻辑分支，不适合抽 unit test；集成测试仅适合关键路径业务流，本场景由手工验证覆盖 |
| 场景覆盖（手工） | ① 消息列表任意空白处点击 → panel 收起 ② context bar 点击 → panel 收起 ③ 输入框任意位置点击 → panel 收起 ④ 标题栏空白处点击 → panel 收起 ⑤ panel 内模型项点击 → 选中并收起 panel ⑥ 同一模型再次点击 → toggle 收起 panel ⑦ 流式响应中 → panel 隐藏（保留既有行为） |

## 文档同步

`context-sync` 同步至：

- `docs/modules/chat/visual/README.md` 第 5 节 ModelSelectorPanel 表格新增「关闭」行 + 新增「关闭行为约束」小节
- `docs/modules/chat/design-tokens.yaml` `modelSelector` 字段新增 `dismiss` + `dismissImpl`
- `docs/FEATURES.md` 最近变更列表新增 2026-06-26 记录
- 本 CHANGELOG

## 已知风险（留给后续决定）

- **无障碍 / 屏幕阅读器**：`Positioned.fill` 透明 `GestureDetector` 在 TalkBack/VoiceOver 下的可访问性未单独验证。如未来发现 a11y 投诉，需补 `Semantics` 节点或换 dismiss 方式
- **键盘焦点 / Web**：`Listener(onPointerDown)` 在 Web 端可能不响应键盘 Escape。Web 不在本项目当前目标平台，可忽略
- **panel 关闭动画**：当前是 `setState` 直接消失，无 fade / slide 动画。如未来有「关闭动画丝滑度」反馈，再补 `AnimatedSwitcher`

## 关联

- `docs/_tmp/chat-model-panel-dismiss.md` — brainstorming 草稿（merge 后清理）
- [`docs/modules/chat/visual/README.md`](../modules/chat/visual/README.md) 第 5 节 — 视觉规范同步更新
- [`docs/modules/chat/design-tokens.yaml`](../modules/chat/design-tokens.yaml) `modelSelector` — design token 同步更新
