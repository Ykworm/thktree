# 碎片库（Clips Drawer）— 实现计划

> 日期：2026-07-08
> 模式：Freemode（代码直接在 dev 上改）
> 状态：方案已确认，技术可行性已验证，待实现
> 草稿：`docs/_tmp/clips-drawer.md`（brainstorming 全过程）

## 1. 背景与功能定位

ThkTree 现有的记录方式都比较"重"——开一轮完整对话、写一篇正式笔记。缺少一个**轻量、中转、可反复取用**的文本暂存层。

碎片库填的是这个空缺：一个全局的文本暂存区，存术语、关键词、常用句式，在不同对话/场景里反复取用。不是草稿箱，不是笔记——是**还没决定归属、但需要反复复用的文本碎片**。

## 2. 用户场景

- 讨论 A2UI 时，把"A2UI"存起来，在后续每个 sub chat 里反复取用
- 看到对话里一段有价值的描述，先摘出来存着，后面可能用
- 存常用包名、命令、配置片段，省得每次重打

## 3. 交互设计

### 3.1 存入

- **入口**：长按选中文本 → 系统选区菜单追加"放入抽屉"按钮（与"复制""全选""分支"并列，共 4 项）
- **来源**：对话消息文本（`MessageBubble` 内的 `SelectionArea`）
- **反馈**：
  - sheet 当前打开 → 末端短暂高亮新 item + 微振动
  - sheet 未打开 → 仅微振动

> **选区菜单共 4 项**：复制 / 全选 / 分支 / 放入抽屉。其中"复制""分支""放入抽屉"都消费选区，
> 执行后清除全局选区状态（`currentSelectionProvider`），避免后续分支流程误用残留选区。
> "分支"从**活跃选区**即时触发（读取 `branchFromSelectionProvider` 回调），详见
> [war-story：选区文本在分支预览残留](../../war-stories/flutter/2026-07-09-chat-selection-residual-branch-preview.md)。

### 3.2 取出

- **入口**：对话输入框发送按钮左侧，加一个抽屉图标按钮（与发送按钮风格统一的方块按钮）
- **不碰工具条**：工具条已有联网/深度思考/图片三个按钮，SE 上已顶死（~280pt / 288pt 可用），不再加
- **交互**：点击 → 弹出底部 sheet → 列出所有碎片 → 点一条插入到输入框光标位置
- **sheet 行为**：点一条后 sheet **保持打开**，支持连续取多条
- **笔记编辑器不碰**：本次只在对话页做

```
当前布局：                          改后布局：
[输入框 Expanded] [发送]            [输入框(缩~40pt)] [抽屉] [发送]
```

### 3.3 长文本预览

- **触发**：长按 sheet 中的某个 item
- **预览区域**：弹出大尺寸 card（覆盖 sheet 大部分区域），显示更多内容
- **尺寸适配**：符合 iOS 规范，适配多种 iOS 设备屏幕尺寸（safe area、不同屏幕高度）
- **预览内无操作按钮**：长按 = 纯查看，不塞任何插入按钮。插入只通过直接点击 item 完成
- **手势职责分明**：长按 = 看，点击 = 用
- **关闭**：点击预览区域外或关闭按钮
- **设计哲学**：预览区域尽量大，看不到的内容用户自行脑补——因为是用户自己放的，有印象。这种展示方式本身引导用户别放太长的东西

### 3.4 碎片展示

- 短文本：全文显示
- 长文本：2-3 行截断，截断处用半透明 overlay 做 fade 效果，暗示"还有更多"
- 不搞标题/标签字段

## 4. 管理入口

- **位置**：sheet 本身顶部右侧"管理"文字按钮
- **进入后**：独立管理页
  - 列表形式展示所有碎片
  - 左滑删除（`Dismissible`）
  - 底部"清空全部"按钮（需二次确认）
- **不在 chat more 菜单和 settings 里放**——管理碎片时用户的第一直觉是"打开抽屉看看"

## 5. 数据规则

### 5.1 去重

- 同一文本内容已存在 → 不创建新条目
- 刷新该碎片的"放入时间"（`putAt`）为当前时间 → 排序排到最前面
- 判重依据：文本内容 trim 后完全一致

### 5.2 排序

- 按放入时间倒序（LIFO）：最近放入的排最前面
- 去重时刷新 `putAt` = "重新放入"，排到最前

### 5.3 数量上限

- 最多 18 条
- 满了后继续添加 → 自动清理 `putAt` 最早的条目（FIFO 淘汰）
- 不弹提示，静默清理

### 5.4 持久化

- 磁盘存储，App 重启后还在
- 全局作用域，不绑定 session/node/theme
- 存储格式见 §6

## 6. 存储契约

### 6.1 磁盘路径

```
{rootDir}/clips.json
```

与 `keyword_global.json` 同级，遵循 ThkTree 全局数据存储惯例（全局数据放在 `{root}/` 下，不在 `themes/` 下）。

### 6.2 文件格式

```json
{
  "schema": "clips/v1",
  "updatedAt": "2026-07-08T15:32:00.000Z",
  "clips": [
    {
      "id": "clip_01J8Z9128M0X0Z8XJ2A1C4D3E5",
      "text": "A2UI",
      "createdAt": "2026-07-08T15:30:00.000Z",
      "putAt": "2026-07-08T15:32:00.000Z"
    }
  ]
}
```

字段：
- `schema`：固定 `clips/v1`
- `updatedAt`：最近一次写入时间（UTC ISO8601）
- `clips[].id`：`clip_<ULID>`，全局唯一
- `clips[].text`：碎片正文，不可为空
- `clips[].createdAt`：首次创建时间（UTC ISO8601）
- `clips[].putAt`：最近放入时间（UTC ISO8601），排序依据，去重时刷新

### 6.3 原子写

遵循 `storage-format.md` §2.4 原子写规范：写入 `clips.json.tmp` 同目录临时文件后 `rename` 原子替换。

### 6.4 向后兼容

文件不存在时视为空列表，首次写入时创建文件并写入空骨架。

## 7. 数据模型

```dart
class Clip {
  final String id;         // clip_<ULID>
  final String text;       // 碎片正文
  final DateTime createdAt; // 首次创建时间
  final DateTime putAt;    // 最近放入时间（去重时刷新，排序依据）
}
```

## 8. 技术方案

### 8.1 数据层

**新增文件**：`lib/data/services/clip_storage.dart`

参照 `KeywordGlobalStorage` 模式：
- 构造接收 `rootDir`
- `loadOrInit()`：读取或初始化空文件
- `add(String text)`：去重 + 排序刷新 + 上限淘汰 + 写入
- `remove(String id)`：删除单条
- `clearAll()`：清空全部
- 原子写使用 `KeywordStorageUtils.atomicWriteString`（复用现有工具）

### 8.2 Provider 层

**新增**：`clipStorageProvider`（Riverpod `Provider`）

- 在 `app_services.dart` 中注册，接收 `appPathsProvider` 的 `rootDir`
- 暴露 `ClipStorage` 实例供 UI 层调用

### 8.3 存入 — TextSelection 菜单扩展

`MessageBubble` 内的 `SelectionArea` 已经通过 `selection_state.dart` 的 `currentSelectionProvider` 捕获选区文本。选区菜单在此基础之上追加按钮，固定 4 项：复制 / 全选 / **分支** / 放入抽屉。

- **分支**：仅当 `branchFromSelectionProvider` 已注册回调（当前在聊天页）时显示，点击从**活跃选区**即时分支，不经过 `currentSelectionProvider` 残留值。
- **消费即清**：复制 / 放入抽屉 / 分支三个消费选区的动作执行后都 `currentSelectionProvider.notifier.state = null`，避免后续分支流程误用残留选区（详见 [war-story：选区文本在分支预览残留](../../war-stories/flutter/2026-07-09-chat-selection-residual-branch-preview.md)）。

**技术确认**：Flutter 3.44（项目当前版本），`SelectableText` / `SelectionArea` 的 `contextMenuBuilder` 回调是稳定 API（3.3+ 就有）。可行。

**实现方案**：`SelectionArea.contextMenuBuilder`

```dart
SelectionArea(
  contextMenuBuilder: (context, editableTextState) {
    final value = editableTextState.textEditingValue;
    final sel = value.selection;
    if (sel.isCollapsed) {
      // 光标定位（非选区），不弹自定义菜单
      return editableTextState.contextMenu;
    }
    final selectedText = value.text.substring(sel.start, sel.end);
    final onBranch = ref.read(branchFromSelectionProvider);
    return CupertinoAdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: [
        ContextMenuButtonItem(
          label: '复制',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: selectedText));
            editableTextState.hideToolbar();
            ref.read(currentSelectionProvider.notifier).state = null; // 消费即清
          },
        ),
        ContextMenuButtonItem(
          label: '全选',
          onPressed: () => editableTextState.selectAll(
            SelectionChangedCause.toolbar,
          ),
        ),
        if (onBranch != null)
          ContextMenuButtonItem(
            label: '分支',
            onPressed: () {
              editableTextState.hideToolbar();
              ref.read(currentSelectionProvider.notifier).state = null;
              onBranch(selectedText); // 从活跃选区即时分支
            },
          ),
        ContextMenuButtonItem(
          label: '放入抽屉',
          onPressed: () {
            ref.read(clipStorageProvider).add(selectedText);
            editableTextState.hideToolbar();
            ref.read(currentSelectionProvider.notifier).state = null; // 消费即清
            // 可选：HapticFeedback 反馈
          },
        ),
      ],
    );
  },
  onSelectionChanged: (v) => syncSelection(context, v),
  child: GptMarkdown(...),
)
```

**需覆盖的 SelectionArea 位置（共 4 处）**：

| # | 文件 | 行号 | 场景 |
|---|------|------|------|
| 1 | `message_bubble.dart` | ~589 | assistant 消息正文 |
| 2 | `message_bubble.dart` | ~775 | reasoning 展开区 |
| 3 | `chat_screen.dart` | ~421 | 消息列表外层 |
| 4 | `chat_markdown_sheet.dart` | ~190 | markdown 全屏查看 sheet |

建议抽取一个公共 `buildClipsContextMenu(context, ref, editableTextState)` 函数，4 处共用，避免重复代码。

**风险点与应对**：

1. **嵌套 SelectionArea 菜单归属**：Flutter 嵌套时通常只显示最内层菜单。现有代码的"嵌套策略"需验证——如果外层 `chat_screen.dart` 的 SelectionArea 也会弹菜单，需要让它回退到默认行为或显式吞掉。

2. **`gpt_markdown` 内部 SelectableText**：`gpt_markdown` 包对 inline code、链接等可能自建 `SelectableText`。如果它没有暴露 `contextMenuBuilder` 透传口子，这些子区域长按时会走包内默认菜单（只有复制/全选，没有"放入抽屉"）。实现第 3 步时先翻 `gpt_markdown` 源码确认，若无透传口子则接受这个局限（只影响 inline code / 链接文本，正文段落不受影响）。

3. **光标过滤**：`contextMenuBuilder` 在长按定位光标时也会触发，必须用 `sel.isCollapsed` 早退，否则光标处会弹出菜单。

4. **默认菜单项取舍**：系统默认菜单可能有 Share / Look Up / Search Web 等。本方案只保留"复制""全选""放入抽屉"三项，其他默认项不保留。如果后续需要可再加回。

**改动文件**：`lib/ui/core/shared/message_bubble.dart`、`lib/ui/features/chat/chat_screen.dart`、`lib/ui/features/chat/widgets/chat_markdown_sheet.dart`

### 8.4 取出 — ChatComposer 改动

**改动文件**：`lib/ui/core/shared/chat_composer.dart`

当前布局（第 174-196 行）：
```dart
const SizedBox(width: 4),
Container(  // 发送按钮
  ...
  CupertinoButton(onPressed: _send, child: Icon(AppIcons.send)),
),
```

改后布局：
```dart
const SizedBox(width: 4),
Container(  // 抽屉按钮（新增）
  ...
  CupertinoButton(onPressed: _openClipsSheet, child: Icon(AppIcons.clips)),
),
const SizedBox(width: 4),
Container(  // 发送按钮
  ...
  CupertinoButton(onPressed: _send, child: Icon(AppIcons.send)),
),
```

- 输入框 `Expanded` 自动缩窄约 40pt（两个 SizedBox(4) + 按钮宽 36 ≈ 44pt）
- SE 上仍可用（消息输入框不需要很宽）

**新增参数**：
- `ChatComposer` 需要能访问 `ClipStorage`，通过 `Ref` 或回调注入

### 8.5 Sheet — 碎片列表

**新增文件**：`lib/ui/features/chat/widgets/clips_sheet.dart`

- `showModalBottomSheet` 弹出
- 顶部：标题"碎片" + 右侧"管理"文字按钮
- 列表：`ListView.builder`，每条 item 显示截断文本
- item 点击：插入文本到 `TextEditingController` 光标位置，sheet 保持打开
- item 长按：弹出预览 card（§3.3）
- 截断 fade：`ShaderMask` + `LinearGradient` 实现底部渐变
- 空状态：居中提示"暂无碎片，长按选中文本可存入"

### 8.6 预览 — 长按弹出

- `GestureDetector.onLongPress` → 弹出预览 card
- 预览 card：`showCupertinoModalPopup` 或自定义 `OverlayEntry`
- 尺寸：覆盖 sheet 大部分区域，但留出边缘可点击关闭
- 内容：`SingleChildScrollView` + `SelectableText`（全文可滚动查看）
- 适配：safe area insets + `MediaQuery.sizeOf` 计算可用高度
- 无操作按钮，纯展示

### 8.7 管理 — 独立页面

**新增文件**：`lib/ui/features/chat/widgets/clips_management_screen.dart`

- `Navigator.push`（CupertinoPageRoute）进入
- `CupertinoNavigationBar`：标题"管理碎片" + 返回按钮
- 列表：`Dismissible` 实现左滑删除
- 底部：`CupertinoButton` "清空全部" → `showCupertinoDialog` 二次确认
- 删除/清空后实时更新列表

### 8.8 图标

在 `app_icons.dart` 中新增碎片图标。候选：CupertinoIcons 的 `tray` / `archivebox` / `rectangle_stack`，选一个语义最贴近的。

## 9. 实现步骤

### Phase 1：数据层（无 UI 依赖，可独立验证）
1. **`Clip` 模型 + `ClipStorage`**：新建 `clip_storage.dart`，参照 `KeywordGlobalStorage` 模式，实现 `loadOrInit / add / remove / clearAll` + 原子写
2. **Provider 注册**：`app_services.dart` 新增 `clipStorageProvider`，接收 `appPathsProvider.rootDir`

### Phase 2：存入（选区菜单扩展）
3. **公共函数**：新建 `clips_context_menu.dart`，导出 `buildClipsContextMenu(context, ref, editableTextState)`，封装复制/全选/放入抽屉三项
4. **先验证 `gpt_markdown` 源码**：确认包内 `SelectableText` 是否暴露 `contextMenuBuilder` 透传口子，决定 inline code / 链接文本是否覆盖
5. **覆盖 4 处 SelectionArea**：`message_bubble.dart`（2 处）、`chat_screen.dart`（1 处）、`chat_markdown_sheet.dart`（1 处），全部接入 `contextMenuBuilder`
6. **嵌套验证**：确认嵌套 SelectionArea 下菜单只弹最内层，外层不重复弹

### Phase 3：取出（Sheet + 按钮）
7. **图标**：`app_icons.dart` 新增碎片图标
8. **ChatComposer 改动**：发送按钮左侧加抽屉按钮，输入框自动缩窄
9. **Sheet 列表**：新建 `clips_sheet.dart`，碎片列表 + 截断 fade + 空状态 + 点击插入光标位置 + sheet 自动关闭
10. **长按预览**：大尺寸 card + iOS safe area 适配 + 纯展示无按钮

### Phase 4：管理
11. **管理页**：新建 `clips_management_screen.dart`，左滑删除 + 清空全部（二次确认）

### Phase 5：验证
12. **编译验证**：`dart analyze` 无新增 issue
13. **集成测试**：按 §10 验收清单逐项验证

## 10. 验收方式

1. **编译通过** + diagnostics 无新增错误
2. **关键路径集成测试**：
   - 存入：选中文本 → 菜单出现"放入抽屉" → 点击 → 碎片出现在列表
   - 取出：打开 sheet → 点一条 → 文本插入输入框光标位置
   - 去重：存入已存在文本 → 不新增，排到最前
   - 上限：存满 18 条后继续存 → 自动淘汰最早的
   - 预览：长按 item → 弹出纯预览（无插入按钮）→ 关闭后点 item 才插入
   - 管理：进入管理页 → 左滑删除 → 清空全部
3. **手工验证**：App 杀掉重启后碎片还在

## 11. 不做的事

- 不碰笔记编辑器的 MarkdownToolbar
- 不在 chat more 菜单和 settings 里放管理入口
- 不搞分类/标签/文件夹
- 不搞碎片搜索（18 条上限，滚动够了）
- 不做碎片编辑（只能删除后重新存）

## 12. 涉及文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `lib/data/services/clip_storage.dart` | 新增 | `Clip` 模型 + `ClipStorage` 读写 |
| `lib/ui/core/app_services.dart` | 修改 | 注册 `clipStorageProvider` |
| `lib/ui/core/shared/message_bubble.dart` | 修改 | 2 处 SelectionArea 追加 contextMenuBuilder |
| `lib/ui/features/chat/chat_screen.dart` | 修改 | 1 处外层 SelectionArea 追加 contextMenuBuilder |
| `lib/ui/features/chat/widgets/chat_markdown_sheet.dart` | 修改 | 1 处 SelectionArea 追加 contextMenuBuilder |
| `lib/ui/core/shared/clips_context_menu.dart` | 新增 | 公共 `buildClipsContextMenu()` 函数，4 处共用 |
| `lib/ui/core/shared/chat_composer.dart` | 修改 | 发送按钮左侧加抽屉按钮 |
| `lib/ui/features/chat/widgets/clips_sheet.dart` | 新增 | 碎片列表 sheet |
| `lib/ui/features/chat/widgets/clips_management_screen.dart` | 新增 | 管理页 |
| `lib/ui/core/theme/app_icons.dart` | 修改 | 新增碎片图标 |
| `docs/_shared/storage-format.md` | 待同步 | context-sync 阶段补充 `clips/v1` 格式定义 |
