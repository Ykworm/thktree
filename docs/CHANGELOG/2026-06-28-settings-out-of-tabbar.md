# 设置入口从底部 tab 移出

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-28 |
| 范围 | navigation（`router.dart`）+ search 模块（`search_screen.dart`）+ settings 模块（隐式受益） |
| 设计文档 | [`docs/_tmp/settings-out-of-tabbar.md`](../_tmp/settings-out-of-tabbar.md)（brainstorming 草稿，merge 后清理） |
| War Story | （无） |
| 状态 | ✅ 完成 |

## 背景

底部 tab bar 原为 4 个（搜索 / 主题 / 笔记 / 设置）。日常使用时问题：

- **设置入口过于显眼**：设置是低频入口（语言 / 大模型 / 生物认证 / 备份等），但占据底部 tab 一席，与「笔记 / 主题」这种高频入口并列，浪费用户注意力 + 浪费屏幕空间（tab bar 高度被均分）
- **iOS HIG 不鼓励设置入主导航**：iOS Human Interface Guidelines 明确建议「设置 / 关于 / 偏好」放在深层入口（如个人头像页或专门页面），主 tab bar 只放用户最核心的任务
- **产品决策反转**：项目早期 v0 阶段有过「设置即 tab」的临时决策（用于快速验证），但 v1 上线前需要按 HIG 重新审视

产品决定：设置移出底部 tab，迁至搜索页顶栏右上角齿轮按钮（push 进入）。

## 方案

走 **方案 B：搜索页顶栏齿轮 + push**——`SearchScreen` 顶栏 `trailing` slot 加 `CupertinoButton` 渲染 `AppIcons.settings`（=`SFIcons.sf_gearshape`），点击 `context.push('/settings')` 进入 `SettingsScreen`。

放弃方案：

- **方案 A（维持底部 tab）**：违背反转决策，浪费 tab 资源
- **方案 C（profile / 头像入口）**：项目无登录系统，无个人中心概念，硬塞反而抽象
- **方案 D（独立设置页 + 卡片入口）**：在主题列表页加设置卡片，与主题列表本身职责混淆

## 实施内容

### 修改文件（3）+ 新增文件（1）

```
lib/ui/core/router.dart # 路由改造
lib/ui/features/search/search_screen.dart # 顶栏加齿轮按钮
docs/FEATURES.md # 最近变更 + 设置模块 row 更新
docs/CHANGELOG/2026-06-28-settings-out-of-tabbar.md # 本文件

integration_test/search_settings_button_test.dart # 新增集成测试（1 case）
```

### 关键改动

**`router.dart` — `/settings` 由 StatefulShellBranch 提升为外层 GoRoute：**

```dart
// 移除：StatefulShellBranch for settings（连带 _settingsNavigatorKey）
// 改为外层 GoRoute，与 /llm-providers 同层：
GoRoute(
 path: '/settings',
 parentNavigatorKey: _rootNavigatorKey,
 pageBuilder: (context, state) => CupertinoPage(
 child: const SettingsScreen(),
 ),
),
```

**`_buildTabBar` — items 列表移除 settings 项：**

```dart
// 原：4 个 tab（含 settings）
// 改：3 个 tab（搜索 / 主题 / 笔记）
final items = <({IconData icon, String label})>[
 (icon: CupertinoIcons.search, label: l10n.searchTabLabel),
 (icon: AppIcons.accountTree, label: l10n.themesTabLabel),
 (icon: AppIcons.note, label: l10n.notes),
];
```

**`search_screen.dart` — 顶栏 `trailing` 加齿轮按钮：**

```dart
return CupertinoPageScaffold(
 navigationBar: CupertinoNavigationBar(
 middle: Text(l10n.searchTabLabel),
 trailing: CupertinoButton(
 key: const ValueKey('settings_button'),
 padding: EdgeInsets.zero,
 minSize: 0,
 onPressed: () => context.push('/settings'),
 child: SFIcon(AppIcons.settings, fontSize: 22),
 ),
 ),
 child: SafeArea(child: SearchContent()),
);
```

### 关键技术点

**为什么 `/settings` 用外层 GoRoute 而非继续放 StatefulShellBranch**：

- 设置是「任何页面都可能进入的横切入口」，不放进任何具体 branch 是合理抽象
- `parentNavigatorKey: _rootNavigatorKey` 让 `/settings` 跨 branch 共享一个栈，按系统返回手势直接回到来源 branch（而非新建分支栈）
- 与 `/llm-providers` 同层（已有此模式），保持一致

**为什么复用 `l10n.settingsTabLabel` 而非新增 key**：

- 字面「设置 tab label」虽带 "tab" 后缀，但实际值「设置」/「Settings」作为「设置入口文案」完全通用
- 避免 i18n 重复 key 污染 ARB 文件
- 后续若用户反馈字面歧义，再迁移至独立 key `settingsEntryLabel`

**为什么用 `AppIcons.settings`（=`SFIcons.sf_gearshape`）而非 `SFIcons.sf_gear`**：

- `sf_gear` 是 macOS only SF Symbol，iOS 端可能渲染失败或 fallback
- `sf_gearshape` 是 iOS + macOS 通用
- 项目已在 `app_icons.dart` 集中管理 `AppIcons.settings = SFIcons.sf_gearshape`，保持一致性

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 无错（增量） |
| 集成测试 | ✅ 新增 `search_settings_button_test.dart`（1 case 全绿） |
| 场景覆盖（手工） | ① 启动 → 默认搜索页 → 顶栏右上角齿轮可见 ② 点齿轮 → push 进入 settings 页（顶栏出现返回箭头） ③ 设置页点返回 → 回到搜索页（齿轮按钮仍在） ④ 主题 / 笔记 tab 切换 → 齿轮按钮不在该 tab 顶栏（验证只在搜索 tab 可见） ⑤ 切换语言 → 「设置」/「Settings」文案均正常 |

## 文档同步

`context-sync` 同步至：

- `docs/FEATURES.md` 第 6 节 设置模块 row 更新「最后更新」日期 + 说明列补充入口位置； 最近变更列表新增 2026-06-28 记录
- 本 CHANGELOG

## 已知风险（留给后续决定）

- **入口发现性下降**：底部 tab 是用户「一看就知道」的入口，顶栏齿轮按钮需要用户主动探索。后续如出现「用户找不到设置」反馈，再考虑加 onboarding 提示或短期保留 tab 入口
- **多页面入口一致性**：当前齿轮按钮只在搜索页顶栏存在，主题 / 笔记 tab 顶栏没有。若后续有「其他页面也想直达设置」需求，需评估是所有页面都加齿轮、还是只在搜索页保留（避免重复）
- **`l10n.settingsTabLabel` 字面歧义**：英文 "Settings" 无歧义，中文「设置」也无歧义，但 key 名称带 "Tab" 后缀与新用途不完全吻合。后续如做 i18n 全面 review，可考虑迁移 key 名称（不破坏向后兼容）

## 关联

- [`docs/_tmp/settings-out-of-tabbar.md`](../_tmp/settings-out-of-tabbar.md) — brainstorming 草稿（merge 后清理）
- `docs/FEATURES.md` 第 6 节 设置模块 row + 最近变更列表 — 同步更新