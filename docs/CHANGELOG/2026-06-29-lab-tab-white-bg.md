# Lab tab 视觉规范化——tab label 统一 + 白底占位 + 装饰图

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-29 |
| 范围 | lab 模块（tab label 统一 + 占位屏视觉规范化） |
| 设计文档 | [`docs/_tmp/lab-bg-image-replace.md`](../_tmp/lab-bg-image-replace.md)（早期 brainstorm 草稿，实际方案与草稿不同，详见 § 方案） |
| War Story | （无） |
| 状态 | ✅ 完成 |

## 背景

承接 ADR-017（2026-06-28 lab tab 上线）的占位实现 `ThkNavBar + Center(Text)`——单 tab 视觉单薄，且与上游"借用 `lab_bg_32pt.png` 当整页 background"的早期 brainstorm 方案在细节上冲突。本期做两项细节修订：(a) tab label 中英文统一；(b) 占位屏视觉规范化。

触发问题两条：

- **字宽失衡**：英文 tab label 原生 "Lab"（4 字符），中文硬译 "实验室"（3 字符）——但中文字符宽约英文两倍，5 个 tab 字宽排开目视发现 "实验室" 明显比 "搜索 / 主题 / 笔记 / 设置" 偏宽，视觉上失衡。
- **占位屏单薄**：原占位屏只有 `ThkNavBar + Center(Text)`，下方完全留白；同时 ADR-017 引入的 `assets/background/lab_bg_32pt.png` 装饰图资产未被使用（在 `pubspec.yaml` 声明但无引用，存在 dead asset 风险）。

## 方案

**tab label 统一**——`app_zh.arb::labTabLabel` 由 "实验室" 改为 "Lab"，与 `app_en.arb` 对齐；`flutter gen-l10n` 重新生成 `app_localizations_zh.dart`。集成测试 `integration_test/lab_tab_test.dart` 的 `find.text('实验室')` 同步改 `find.text('Lab')`（中文 locale 实际渲染值）；`find.text('实验功能筹备中')` 不变（hint 文案字面值）。

**占位屏视觉规范化**——重写 `LabPlaceholderScreen.build()` 为 `CupertinoPageScaffold + SafeArea(Column([顶部 hint Padding + 下方 Expanded(Align.topCenter, Image.asset)]))`。`AppColors.surface` 兜底（light #FFFFFF / dark #0F172A，已存在于 [`docs/_shared/design-tokens.yaml` §1](../_shared/design-tokens.yaml)），顶部 `l10n.labEmptyHint` 占位文案 16pt 居中（24/16 横向 + 顶部 16 padding），下方 `assets/background/lab_bg_32pt.png` 装饰图 `BoxFit.contain` 保持原比例居顶对齐（`Align.topCenter` + `Expanded` 占满剩余高度）。

**关键改动 vs 早期草稿**：[`docs/_tmp/lab-bg-image-replace.md`](../_tmp/lab-bg-image-replace.md) 早期提出 `Stack + Positioned.fill + Image.asset` 把装饰图当整页 background——本期**否定**该方案。理由：`BoxFit.contain` 不撑满时该方案实际不会改变视觉效果（装饰图仍按原比例渲染），但 `Positioned.fill` 会强制 1:1 占满 viewport，导致窄屏（iPhone SE 4.7"）装饰图被压缩变形，违背 `lab_bg_32pt.png` 是"装饰图"而非"背景图"的设计意图。最终方案用 `Column + Expanded + Align.topCenter`——文字在上、图片在下、装饰图保持原比例自然过渡。

## 实施内容

### 修改文件（4）

```
integration_test/lab_tab_test.dart                  # tab label 断言 '实验室' → 'Lab'
lib/l10n/app_zh.arb                                 # labTabLabel: '实验室' → 'Lab'
lib/l10n/generated/app_localizations_zh.dart        # 重新生成（同步 zh）
lib/ui/features/lab/lab_placeholder_screen.dart     # 重写 build 方法为 Column 布局
```

### 关键改动

**`lab_placeholder_screen.dart` —— Column 布局（最终方案）**：

```dart
class LabPlaceholderScreen extends ConsumerWidget {
  const LabPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.surface,  // 兜底白，dark mode 自动 #0F172A
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.labTabLabel)),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部 hint 文字
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Text(l10n.labEmptyHint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            ),
            // 下方装饰图
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Image.asset(
                  'assets/background/lab_bg_32pt.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**`app_zh.arb` —— labTabLabel 统一**：

```json
"labTabLabel": "Lab",  // 原 "实验室"
```

**`lab_tab_test.dart` —— 断言同步**：所有 `find.text('实验室')` → `find.text('Lab')`（zh locale 实际渲染值）；`find.text('实验功能筹备中')` 不变（hint 文案字面值）。

## 验证

| 类别 | 状态 |
|---|---|
| `flutter analyze` | ✅ 无新增 error（增量） |
| 集成测试 | ⚠️ 待开发者手动跑（项目无 iOS/Android simulator，集成测试需真机/模拟器） |
| 场景覆盖（手工） | ① 切换到 Lab tab → 顶部显示"实验功能筹备中"占位文案 + 下方居中显示 `lab_bg_32pt.png` 装饰图（非全屏 background，原比例居顶）② labTabLabel 在中文 locale 下渲染为 "Lab" 而非 "实验室" ③ 5 个 tab 字宽排开目视接近 |
| dark mode | `AppColors.surface` 自动切 dark #0F172A，无需额外适配 |

## 文档同步

context-sync 同步至：

- `docs/FEATURES.md` § 8 — 标题 + 表格行（最后更新 2026-06-29 + 描述追加白底/hint/装饰图）+ 最近变更倒序首行
- `docs/modules/lab/README.md` — 标题 + LabPlaceholderScreen 描述 + 功能列表行（最后更新 2026-06-29 + 描述追加）+ 代码文件行数（32→51）+ 历史新增 2026-06-29 行
- `docs/DECISIONS.md` — ADR-017 末尾追加"ADR-017 修订（2026-06-29）"小节
- `docs/_shared/design-tokens.yaml` § 8 icons — `lab.usage` 注释（"实验室 tab" → "Lab tab"）
- `docs/_tmp/lab-bg-image-replace.md` — 加废弃说明（标注实际方案与草稿差异）
- 本 CHANGELOG

## 已知风险（留给后续决定）

无新增风险。沿用 [ADR-017 § 已知风险](2026-06-28-lab-tab-and-bar-red.md#已知风险留给后续决定)：

- 顶栏改红与 design-system §2.4 destructive 约束冲突
- `flutter_svg` 依赖体量评估

## 关联

- [`docs/_tmp/lab-bg-image-replace.md`](../_tmp/lab-bg-image-replace.md) — 早期 brainstorm 草稿（实际方案已与草稿不同：装饰图不撑满 + Column 布局，保留作为迭代历史）
- [`docs/DECISIONS.md`](../DECISIONS.md) — ADR-017（2026-06-28 lab tab 上线）+ ADR-017 修订（2026-06-29）
- [`docs/modules/lab/README.md`](../modules/lab/README.md) — lab 模块说明
- [`docs/CHANGELOG/2026-06-28-lab-tab-and-bar-red.md`](2026-06-28-lab-tab-and-bar-red.md) — 上游入口决策（ADR-017）
