# i18n-hardcoded-fix：清除硬编码中文

## 现状

ARB 翻译系统完备（EN/ZH 各 418 键，100% 对齐），但 22 个文件绕过 l10n 直接写了硬编码中文，约 90+ 处。

## 方案

扩展 ARB + 逐文件替换，Controller 层通过传参解决。

## 文件清单

见 `.mimocode/plans/1784568981193-misty-nebula.md`

## 状态

- [x] 探索完成
- [x] 方案确定
- [ ] 实现中
