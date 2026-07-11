# ThkTree UI 设计审计 · Step 4 回修归零报告

> 代码真源：`lib/ui/core/theme/app_colors.dart`（code-first）。
> 审计基线快照：`docs/_shared/design-audit/overview.md`（旧版，仅 notes 模块）。
> 本文件为 Step 4 完成后的**全 app 审计证据**：裸色偏差 **92 → 0**。

## 结论

- **修复前（baseline）**：`lib/` 内 **92 处**绕过 `AppColors` 的裸色偏差
  - `CupertinoColors.*` 系统色：78 处（15 种名字）
  - 裸 `Color(0x…)` 字面量：14 处（含 scrim 家族与 lab/波形装饰色）
- **修复后**：**0 处**。`lib/` 内所有颜色均通过 `AppColors` token 引用（`app_colors.dart` 自身定义除外，它是真源）。
- `AppColors` 引用数：535 → **626**（+91 处裸色收口 + 部分 const 上下文调整）。
- `flutter analyze lib/`：**0 error**（仅预存 `avoid_print` / `deprecated_member_use` info/warning，与本次无关）。

## 逐模块 before / after

| 模块 | 修复前 | 修复后 |
|------|-------:|-------:|
| ui/core（auth_gate / message_bubble / markdown / 各类 widget） | 24 | 0 |
| settings（tts / llm / clean_images / backup） | 15 | 0 |
| chat（chat_screen / user_questions / clips / model_selector） | 14 | 0 |
| themes（merge_confirm / theme_detail） | 10 | 0 |
| backup_restore | 8 | 0 |
| notes（browse / detail / select） | 8 | 0 |
| lab（placeholder / thinking_collision / user_input_summary） | 6 | 0 |
| search（search_screen / search_content） | 4 | 0 |
| llm（providers / provider_detail） | 3 | 0 |
| **合计** | **92** | **0** |

> 注：handoff 早期记录的「157 处（100 Cupertino + 57 Color）」已漂移，以本审计 lib/ 实测 92 处为准——这正是 code-first + 防回归机制的必要性证据。

## 偏差类别 → token 映射（修复对照）

### Cupertino 系统色 → AppColors
| 裸色 | 归入 token | 处数 |
|------|-----------|-----:|
| `CupertinoColors.white` | `AppColors.white`（新增原语） | 19 |
| `CupertinoColors.systemRed` | `AppColors.destructive` | 13 |
| `CupertinoColors.systemBlue` | `AppColors.accent` | 7 |
| `CupertinoColors.separator` | `AppColors.border` | 7 |
| `CupertinoColors.destructiveRed` | `AppColors.destructive` | 7 |
| `CupertinoColors.black` | `AppColors.black`（新增原语） | 6 |
| `CupertinoColors.systemGrey` | `AppColors.textSecondary` | 5 |
| `CupertinoColors.systemBackground` | `AppColors.pageBg` | 4 |
| `CupertinoColors.transparent` | `AppColors.transparent`（新增原语） | 2 |
| `CupertinoColors.systemIndigo` | `AppColors.accent` | 2 |
| `CupertinoColors.label` | `AppColors.textPrimary` | 2 |
| `CupertinoColors.systemTeal` | `AppColors.waveTeal`（装饰 token） | 1 |
| `CupertinoColors.systemOrange` | `AppColors.waveOrange`（装饰 token） | 1 |
| `CupertinoColors.systemGreen` | `AppColors.success` | 1 |
| `CupertinoColors.secondaryLabel` | `AppColors.textSecondary` | 1 |

### 裸 `Color(0x…)` → AppColors
| 裸字面量 | 归入 token | 处数 |
|----------|-----------|-----:|
| `Color(0x00000000)` | `AppColors.transparent` | 3 |
| `Color(0x0D000000)` / `Color(0x0F000000)` | `AppColors.scrimSoft`（新增） | 2 |
| `Color(0x80000000)` | `AppColors.scrim` | 1 |
| `Color(0xF0000000)` | `AppColors.scrimStrong`（新增） | 1 |
| `Color(0x61000000)` | `AppColors.scrimMid`（新增） | 1 |
| `Color(0xFF0F1035)` | `AppColors.labBg`（装饰 token） | 1 |
| `Color(0xFF3B82F6)` | `AppColors.labAccentBlue`（装饰 token） | 1 |
| `Color(0xFFF97316)` | `AppColors.labAccentOrange`（装饰 token） | 1 |
| `Color(0xFFA855F7)` | `AppColors.labAccentPurple`（装饰 token） | 2 |

### 动态阴影（特殊处理）
- `ui.Color.fromRGBO(0,0,0, 动态alpha)`（tts 回到顶部按钮）→ `AppColors.black.withOpacity(动态alpha)`，等价且走 token。

## 新增 token（补进真源 app_colors.dart）
- 中性原语：`white` / `black` / `transparent`
- scrim 家族：`scrimStrong`(~94%) / `scrimMid`(~38%) / `scrimSoft`(~5%，合并 0x0D/0x0F)
- 装饰特征色（lab / 波形指示器，非核心系统色，但一律走 token，guard 无需白名单）：
  `labBg` / `labAccentBlue` / `labAccentOrange` / `labAccentPurple` / `waveTeal` / `waveOrange` / `wavePurple`

## 修复过程中的编译修复
- `AppColors` 语义 token 是 getter（随亮度变化，**非编译期常量**）。原 `CupertinoColors.*` 是常量，用在 `const TextStyle/BoxDecoration/Icon` 中合法；替换后需去掉外层 `const`（共 4 处 TextStyle、1 处 BoxDecoration、1 处 Icon）。
- `const AppColors.transparent` 触发 Dart「把静态访问误读为构造器」解析歧义 → 去掉冗余 `const` 前缀（9 处）。
- `CupertinoColors.x.resolveFrom(context)` 跨行写法：替换脚本已支持跨行去 `.resolveFrom`（AppColors getter 已随亮度变化，无需 resolveFrom）。
- `tts_tokens.actionIdle` 原为 `static const` 引用 getter → 改为 getter `static Color get actionIdle => AppColors.textSecondary;`（该字段代码内未使用）。

## 防回归（见 Tier 4）
- `scripts/sync-design-tokens.dart`：`app_colors/app_spacing/app_durations` → `docs/_shared/design-tokens.yaml` 单向生成（color + dimension + time），每次改色重跑即锁死文档。
- `scripts/check_color_tokens`：扫描 `lib/` 裸 `CupertinoColors.` / `Color(0x` / `Color.fromARGB` / `Color.fromRGBO` / `Color.from`，先 warn 后 block。
- git pre-commit hook + `design-system.md` 约定：改色先改 `app_colors.dart`，跑脚本同步文档，CI 拦裸色。
