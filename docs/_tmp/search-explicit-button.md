# 搜索改为「显式按钮触发」

> **状态**：✅ 已实现（2026-07-09）。见 `docs/modules/search/README.md` 关键设计原则「显式搜索」。代码在 `lib/ui/features/search/search_content.dart`（笔记 tab 的 live 搜索零改动）。

## 背景

当前搜索是 live search：`onChanged` 更新 `queryNotifier` → `SearchResults` 监听变化、300ms 防抖后自动搜索并写历史。
副作用：慢打字 / 边想边打时，每个 ≥300ms 停顿都会触发一次搜索并写入历史，导致最近搜索里出现 `b`/`be`/`bea`…`beautiful` 这种「输入过程」垃圾（见对话 2026-07-09）。

目标：**去掉边输入边搜索，改为显式搜索按钮（或键盘回车）触发**。

## 设计

核心思路：把「输入框当前文本」和「已提交的搜索词」拆成两个 notifier。
- `_queryNotifier`：输入框当前文本，仅用于 UI 空/非空切换（决定显示 RecentSearchTags 还是 SearchResults）。
- `_committedNotifier`：已提交的搜索词，真正驱动 `SearchResults` 去搜索 + 写历史。

### 改动点（全部在 `lib/ui/features/search/search_content.dart`）

1. **SearchBox**
 - 新增 `VoidCallback? onSearch` 参数。
 - `CupertinoSearchTextField` 加 `onSubmitted: (_) => widget.onSearch?.call()`（键盘回车 / 搜索键也能触发）。
 - `onChanged` 仍只更新 `queryNotifier`，**不再触发搜索**。

2. **_SearchContentState**
 - 新增 `_committedNotifier = ValueNotifier<String>('')`，dispose 时释放。
 - 新增 `_commitSearch() => _committedNotifier.value = _queryNotifier.value;`（空输入时不动作 / 可禁用按钮）。
 - build 里把 `SearchBox` 放进 `Row`，右侧加 `CupertinoButton(child: Text(l10n.searchAction), onPressed: _commitSearch)`。
 - `ValueListenableBuilder` 仍按 `_queryNotifier` 空/非空切 RecentSearchTags / SearchResults（打字时立即显示结果区，但结果等 commit 才有内容）。
 - 点 recent tag：`onTagTap: (tag) { _queryNotifier.value = tag; _committedNotifier.value = tag; }`（标签点击是显式动作，直接搜）。

3. **SearchResults**
 - 构造参数由 `queryNotifier` 改为接收 `_committedNotifier`（建议改名 `committedNotifier`）。
 - `_onQueryChanged` 基于 committed 值搜索 + 成功写历史（行为不变）。
 - **去掉 300ms 防抖**：显式提交已天然去重（onSubmitted 与按钮设同值不会重复 notify），直接搜更跟手。
 - `initState` 里若 committed 非空则立即搜（适配标签回填场景）。

4. **文案（l10n）**
 - `lib/l10n/app_zh.arb` 加 `"searchAction": "搜索"`，`app_en.arb` 加 `"searchAction": "Search"`。
 - 按钮用 `l10n.searchAction`。

## 验收

- 编译通过 + `dart analyze` 无新增错误。
- 手工验证：
 1. 输入 `beautiful` 过程中**不**出结果、**不**写历史；
 2. 点「搜索」按钮 / 键盘回车后才出结果，且最近搜索只多一条 `beautiful`；
 3. 点历史标签立即搜并回填；
 4. 清空输入框回到标签云；
 5. 空输入时点按钮不报错、不写空历史。

## 边界 / 待确认

- 按钮在空输入时：方案选「禁用」（灰显）还是「点击无效」？（默认：点击无效，简单）
- 是否需要保留一个极短防抖（如 100ms）防止按钮+onSubmitted 双触发？（默认：不需要，ValueNotifier 同值不 notify 已去重）
