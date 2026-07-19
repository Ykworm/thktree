# wiki

> 状态：plan-ready
> 更新：2026-07-19

## 背景

用户提出：ThkTree 的核心价值是「用 tree 的思维对话」，但对话积累后变成历史。历史要重新有价值，需要变成 wiki。相比「备份/恢复」到桌面端，更直接的方式是把某个 tree 转换成独立的 wiki 文件夹，App 内可当电子书阅读，也可导出 zip 到电脑或 Kimi Work。

## 核心决策

- **Wiki 是独立数据**：从 tree 生成 `themes/{themeId}/wiki/` 文件夹（`index.md` + `{nodeId}.md` + `assets/`），不是 tree 的实时视图。
- **App 内阅读器验证体验**：ThemeDetailScreen 增加 Tree / Wiki 双 tab，Wiki tab 提供真实的电子书阅读体验（连续长文 + 层级 TOC + 当前位置高亮 + 阅读进度）。
- **只读**：Wiki 生成后不可编辑，tree 是唯一真相源。
- **快照语义**：tree 更新后 wiki 不自动变，用户可手动「重新生成」。
- **导出后置**：导出 zip 功能作为第二步，当前优先级低于 App 内阅读体验验证。

## 目标用户场景

1. 用户打开某个 theme 的详情页，发现顶部有 Tree / Wiki 两个 tab。
2. 首次点击 Wiki tab，看到空态：「还没有 Wiki」+「生成 Wiki」按钮。
3. 点击生成，App 把当前 tree 的对话转换成 `wiki/` 文件夹。
4. Wiki tab 显示电子书阅读器：连续长文、层级目录、阅读进度。
5. 用户可以像看书一样把旧对话读完。

## 非目标

- 不做 wiki 编辑。
- 不做 wiki 版本管理（只保留最新生成的一份）。
- 不做 Kimi Work 深度集成（导出 zip 即可）。
- 不做桌面端同步。

## 开放问题

- 超大 tree 的生成性能与阅读性能是否需要分页？首版暂不做。
- 图片在 wiki 中如何渲染？首版复用现有图片预览。
- 是否需要在 Wiki tab 显示「已过期」提示？首版只在生成时记录时间，不主动提示。

## 实现进度链接

- 实现分支：`ThkTree/wiki`
- Worktree：`../ThkTree-worktrees/wiki`
- 模块文档：`docs/modules/wiki/README.md`
