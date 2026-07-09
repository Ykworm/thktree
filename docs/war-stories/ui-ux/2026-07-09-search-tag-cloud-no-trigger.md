# Tag Cloud 点击不触发搜索 — ValueNotifier 初始值陷阱

> **日期**：2026-07-09  
> **模块**：search  
> **EC 关联**：EC-015（FTS5 CJK 分词）  
> **影响范围**：`search_content.dart`、`search_service.dart`

---

## 现象

1. 搜索框输入关键词（如 `flutter`），搜索正常触发，有结果
2. 从 tag cloud（搜索历史标签）点击同一个词，**无搜索日志、无结果**，显示"换个角度试试"
3. 在关键词后加空格（如 `flutter `），搜索正常触发

## 根因

**`ValueNotifier` 只在值变化时触发 listener，不触发初始值。**

具体链路：

1. tag cloud 点击 → `_queryNotifier.value = tag`（设值）
2. `ValueListenableBuilder` 重建 → query 非空 → 从 `RecentSearchTags` 切换到 `SearchResults`
3. `SearchResults` 是**新创建的 widget** → `initState` 添加 `queryNotifier` listener
4. 但 `queryNotifier.value` 已经是 `tag` 了 → listener 只在**值变化**时触发 → **`_onQueryChanged` 从未被调用**

时序图：

```
tag cloud tap
  → _queryNotifier.value = "flutter"
  → ValueListenableBuilder rebuild
  → query != "" → 创建 SearchResults（新 widget）
  → SearchResults.initState() → addListener(_onQueryChanged)
  → 但 value 没变（已经是 "flutter"）→ listener 不触发
  → 搜索从未执行
```

而手动输入时：

```
keyboard type "f"
  → _queryNotifier.value = "f"
  → listener 触发 → _onQueryChanged → debounce 300ms → search("f")
keyboard type "l"
  → _queryNotifier.value = "fl"
  → listener 触发 → debounce 300ms → search("fl")
...
keyboard type "t" (完成 "flutter")
  → _queryNotifier.value = "flutter"
  → listener 触发 → debounce 300ms → search("flutter")
```

手动输入时 listener 在每次字符变化时都触发，所以搜索正常。tag cloud 一次性设值，创建新 widget 后 listener 不会再触发。

## 修复

在 `SearchResults.initState()` 中，添加 listener 后立即检查：如果 `queryNotifier` 已有非空值，直接调 `_onQueryChanged()`：

```dart
@override
void initState() {
  super.initState();
  widget.queryNotifier.addListener(_onQueryChanged);
  // 如果 queryNotifier 已有非空值（如从 tag cloud 点击），
  // 立即触发搜索 — ValueNotifier 只在值变化时通知，不通知初始值。
  if (widget.queryNotifier.value.trim().isNotEmpty) {
    _onQueryChanged();
  }
}
```

**涉及文件**：`lib/ui/features/search/search_content.dart`

## 调试过程

1. 加 `print` 到 `search()` 入口 → tag cloud 点击时无输出 → `search()` 未被调用
2. 加 `print` 到 `_onQueryChanged` → tag cloud 点击时无输出 → listener 未触发
3. 定位到 `ValueListenableBuilder` 动态创建 `SearchResults` 的时序问题

**教训**：当 widget 被动态创建且依赖 `ValueNotifier` 的当前值时，必须在 `initState` 中处理初始值，不能仅依赖 listener。

## 防御建议

- 在使用 `ValueListenableBuilder` 动态创建子 widget 时，如果子 widget 依赖 `ValueNotifier` 的值，应在 `initState` 中检查并处理初始值
- 考虑封装一个 `ValueNotifierInitialHandler` mixin，统一处理这类场景
