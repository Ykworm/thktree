# ThkTree Design System · 约定（code-first）

> 代码是真源。设计 token 写在手写类里，文档只是镜像，CI 拦裸色防止漂移。

## 单一真源

| 类别 | 真源文件 | 镜像字典 |
|------|----------|----------|
| 颜色 color | `lib/ui/core/theme/app_colors.dart` | `docs/_shared/design-tokens.yaml` → `color` |
| 间距/圆角 dimension | `lib/ui/core/theme/app_spacing.dart` | `docs/_shared/design-tokens.yaml` → `dimension` |
| 动效时长/曲线 time | `lib/ui/core/theme/app_durations.dart` | `docs/_shared/design-tokens.yaml` → `time` |
| 图标 icon | `lib/ui/core/theme/app_icons.dart` | — |
| 字体 typography | `lib/ui/core/theme/app_theme.dart`（`textTheme`） | — |

`docs/_shared/design-tokens.yaml` 由 `scripts/sync-design-tokens.dart` **单向生成**，不要手改。

## 改色流程（必读）

1. **改真源**：在 `app_colors.dart`（或 `app_spacing` / `app_durations`）增 / 改 token。
2. **改 widget**：把裸色 `CupertinoColors.*` / `Color(0x…)` 改为 `AppColors.<token>`。
   - 语义 token 是 **getter**（随 `AppColors.setBrightness` 变），不是编译期常量——
     在 `const TextStyle / BoxDecoration / Icon` 里用时**去掉外层 `const`**。
   - `CupertinoColors.x.resolveFrom(context)` 直接换成 `AppColors.<token>`（getter 已随亮度变，无需 resolveFrom）。
3. **同步文档**：`dart run scripts/sync-design-tokens.dart` → 重新生成 `design-tokens.yaml`。
4. **提交**：pre-commit hook 跑 `scripts/check_color_tokens.dart` 拦裸色。

## 禁止（防回归）

`lib/` 内禁止出现以下裸写法（app_colors.dart 自身除外，它是真源）：

- `CupertinoColors.*`
- `Color(0x…)`（含 `Color.fromARGB` / `Color.fromRGBO` / `Color.from`）
- 装饰性特征色也走 token：`AppColors.labBg / labAccentBlue / labAccentOrange / labAccentPurple / waveTeal / waveOrange / wavePurple`

> 注：Material `Colors.*` 当前未强制拦截，但同样建议走 token；后续可纳入 guard。

## 防回归机制

- `scripts/check_color_tokens.dart`：`--mode=warn`（只报告）/ `--mode=block`（发现即 exit 1）。
- `.git/hooks/pre-commit`：提交前自动跑 block 模式。
- **CI 接入**：当前仓库无 CI（Gitee remote），待搭建 Gitee CI 后，在流水线加一步
  `dart run scripts/check_color_tokens.dart --mode=block` 即可常态化拦裸色。

## 审计证据

- `docs/_shared/design-audit/overview.md`：Step 4 回修前后对照，lib/ 裸色偏差 **92 → 0**。
- `docs/_shared/design-audit/thktree-design-spec.html` 第 9 节：全局 Color Token 对照表。

## 历史

- Step 4（2026-07-11）：code-first 收敛。原 handoff 记录的「157 处」已漂移，以 lib/ 实测 92 处为准。
  新增中性原语 `white/black/transparent`、scrim 家族 `scrimStrong/scrimMid/scrimSoft`、装饰 token `lab*/wave*`。
