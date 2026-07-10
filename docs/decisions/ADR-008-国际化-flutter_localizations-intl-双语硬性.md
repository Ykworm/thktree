## ADR-008: 国际化 flutter_localizations + intl + 双语硬性

2026-04 决定。中英双语，arb 文件维护（`lib/l10n/app_en.arb` + `app_zh.arb`），`flutter gen-l10n` 自动生成。硬性约束：任何用户可见文案必须双语同步加，缺一个语言 = CI 拦截。原因：iOS 用户群国际化是基本要求，单语产品不利于发海外；arb 集中维护比散在代码里改字符串简单很多。影响范围：`lib/l10n/` 整个目录；所有 UI 文本（label/button/title/placeholder/error message）。实施要点：加文案走 "arb 加 key → `flutter gen-l10n` → 用 `AppLocalizations.of(context).xxx`"，**禁止**在 widget 里写中文/英文字符串字面量。
