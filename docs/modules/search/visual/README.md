# 搜索模块视觉设计

> 与 [`../../../_shared/design-system.md`](../../../_shared/design-system.md) 配套阅读。

---

## 屏幕地图

```
┌─────────────────────────────────────────────────────┐
│  TabBar:  主题   笔记   [搜索]  设置                   │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────┐
│  SearchScreen                                        │
│  ─────────────────────────────────────────────────── │
│  NavBar: CupertinoNavigationBar                      │
│          middle: l10n.searchTabLabel                  │
│  ─────────────────────────────────────────────────── │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │ CupertinoSearchTextField                         │ │
│  │ placeholder: l10n.searchHint                     │ │
│  │ debounce: 300ms                                  │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  ┌─────────────────────────────────────────────────┐ │
│  │ 📝 笔记标题                                      │ │
│  │ 匹配片段...关键词高亮...                          │ │
│  │ 主题名                                           │ │
│  ├─────────────────────────────────────────────────┤ │
│  │ 💬 对话节点标题                                   │ │
│  │ ...关键词高亮...                                  │ │
│  │ 主题名                                           │ │
│  └─────────────────────────────────────────────────┘ │
│                                                      │
│  (空态):                                             │
│  ┌─────────────────────────────────────────────────┐ │
│  │         🔍                                       │ │
│  │    l10n.searchEmpty                              │ │
│  │    (或 l10n.searchNoResults)                     │ │
│  └─────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## 1. SearchScreen 布局

```dart
CupertinoPageScaffold(
  navigationBar: CupertinoNavigationBar(
    middle: Text(l10n.searchTabLabel),
  ),
  child: SafeArea(
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: CupertinoSearchTextField(...),
        ),
        if (_loading) CupertinoActivityIndicator(),
        if (_error != null) Text(l10n.searchError, color: destructiveRed),
        Expanded(child: _results.isEmpty ? 空态 : ListView.builder(...)),
      ],
    ),
  ),
)
```

| 元素 | 规范 |
|------|------|
| NavBar | `CupertinoNavigationBar`（非 ThkNavBar，因为搜索 Tab 无大标题） |
| 搜索框 | `CupertinoSearchTextField`，padding 16，placeholder `l10n.searchHint` |
| 防抖 | 300ms（`Timer(Duration(milliseconds: 300))`） |
| Loading | `CupertinoActivityIndicator`，padding 16 |
| 错误 | `l10n.searchError`，`CupertinoColors.destructiveRed` |

---

## 2. 搜索结果项（`_SearchResultItem`）

每条结果的布局：

```
┌─────────────────────────────────────────────────┐
│ 📝 实体标题                                      │
│ 主题名                                           │
└─────────────────────────────────────────────────┘
```

| 元素 | 规范 |
|------|------|
| 容器 | `Container`，padding `horizontal: 16, vertical: 12` |
| 分隔线 | `Border(bottom: BorderSide(color: AppColors.border, width: 0.5))` |
| 图标 | `entityType == 'note'` → `CupertinoIcons.doc_text`，否则 → `CupertinoIcons.chat_bubble` |
| 图标尺寸 | 16pt |
| 图标颜色 | `AppColors.textTertiary` |
| 标题 | 16pt, w500，单行省略 |
| 主题名 | 12pt, `AppColors.textTertiary`，单行省略 |
| 高亮 | 关键词在 snippet 中加粗显示 |
| 点击 | `onTap` → 按 entityType 跳转到对应页面 |

---

## 3. 空状态

| 状态 | 图标 | 文案 | 颜色 |
|------|------|------|------|
| 未输入 | `CupertinoIcons.search` (40pt) | `l10n.searchEmpty` | `AppColors.textSecondary` |
| 无结果 | `CupertinoIcons.search` (40pt) | `l10n.searchNoResults` | `AppColors.textSecondary` |

图标颜色：`AppColors.textTertiary`，距顶间距 12px。

---

## 4. 搜索历史

- 最近 10 次搜索关键词本地保存
- 输入框为空时显示历史记录
- 点击历史关键词直接填充并搜索

---

## 5. 跨模块跳转

| entityType | 跳转目标 |
|-----------|---------|
| `note` | 笔记详情页 |
| `message` | 对应主题 → 节点对话页 |

通过 `routeName + args` 解耦，不在 search 模块里直接 import 其他模块的 widget。
