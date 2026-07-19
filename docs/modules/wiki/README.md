# Wiki 模块

> 把 theme tree 转换为独立 wiki 快照，提供 App 内电子书阅读体验。
> 维护者：人类 + AI 共同维护。

> ⚠️ **AI 改模块前必读**
> 1. **Wiki 是独立快照，不是 tree 的实时视图**——tree 更新不会自动同步到 wiki，必须显式「重新生成」。
> 2. **真相源边界**——tree/session.md 是真相源；`themes/{themeId}/wiki/` 是派生只读产物，禁止反向写回 tree。
> 3. **入口在 themes 模块**——Wiki tab 挂在 `ThemeDetailScreen`，但业务逻辑（生成/读取/导出）归 wiki 模块。

## 1. 职责

| 组件 | 职责 |
|------|------|
| **WikiStore** | 生成/读取/删除 `themes/{themeId}/wiki/` 快照 |
| **WikiReaderView** | Wiki tab 内的电子书阅读视图（连续长文 + TOC + 进度） |
| **WikiExportService** | 把 wiki 快照打包为 zip 导出 |
| **ThemeDetailScreen** | Tree / Wiki 双 tab 容器（属 themes 模块） |

## 2. 存储格式

Wiki 以 **单个 tree**（root node 及其子孙）为单位生成。一个 theme 下可存在多个 wiki 快照：

```text
themes/{themeId}/
  wiki/
    {rootNodeId}/
      wiki.meta.json    # 快照元数据
      index.md          # 封面 + 目录
      {nodeId}.md       # 每个节点一个文件
      assets/           # 图片等附件
```

`wiki.meta.json` 示例：

```json
{
  "schema": "wiki_meta/v1",
  "themeId": "thm_...",
  "themeTitle": "My Theme",
  "rootNodeId": "nd_...",
  "generatedAt": "2026-07-19T12:00:00.000Z",
  "sourceUpdatedAt": "2026-07-19T11:30:00.000Z",
  "nodeCount": 12
}
```

## 3. 功能列表

| Feature | 状态 | 最后更新 | 备注 |
|---------|------|----------|------|
| Per-tree Wiki 快照生成 | ✅ 完成 | 2026-07-19 | 以 root node 为单位生成 `wiki/{rootNodeId}/` |
| Wiki 目录页 | ✅ 完成 | 2026-07-19 | ThemeDetailScreen Wiki tab 首页为书籍封面 + 层级目录 |
| Wiki 章节阅读页 | ✅ 完成 | 2026-07-19 | 单章节内容 + 上一章/下一章导航 |
| Tree 选择器 | ✅ 完成 | 2026-07-19 | 紧凑下拉按钮；点击弹出底部 sheet 垂直列表，带选中勾选 |
| 导出 zip | ✅ 完成 | 2026-07-19 | WikiExportService |

## 4. 代码文件

```text
lib/ui/features/wiki/
├── wiki_reader_view.dart       # Wiki 阅读视图（嵌入 ThemeDetailScreen）
├── wiki_toc_view.dart          # 层级目录底部 sheet
└── wiki_reader_controller.dart # 状态管理（加载/生成/刷新）

lib/data/services/
├── wiki_store.dart             # 快照生成/读取/删除
└── wiki_export_service.dart    # zip 导出
```

## 5. 关键设计原则

### 5.1 快照语义

- Wiki 生成后即为只读快照。
- 用户可在 Wiki tab 看到「生成于 {time}」。
- tree 更新后，wiki 不变；用户可手动「重新生成」覆盖。

### 5.2 阅读体验底线

- **Catalog-first**：Wiki tab 首页为书籍封面 + 层级目录，不是直接铺满内容。
- **连续目录页**：封面、操作按钮、目录标题与目录列表合并为单一连续滚动布局，避免块间大段空白。
- **章节阅读**：点击目录项进入单章节阅读页，支持上一章/下一章导航。
- **层级目录**：目录按 tree 深度缩进，显示每章消息数。
- **Tree 选择器**：多 tree 时使用紧凑下拉按钮，点击展开底部 sheet 列表，对少量/大量 tree 都友好。

### 5.3 内容过滤

- 过滤 `system` 消息。
- 过滤未完成（streaming）或失败（error）的 assistant 消息。
- 保留 user 与成功 assistant 消息，reasoning 可选折叠。

## 6. 维护要点

- **新增 wiki 功能**：在本 README 第 3 节更新状态，并同步 `docs/FEATURES.md`。
- **改存储格式**：必须更新 `wiki.meta.json` schema 版本，并提供迁移说明。
- **改阅读器样式**：同步更新 visual 设计文档（如有）。

## 7. 相关历史

- **2026-07-19** — 模块创建，初始实现进行中（见 `docs/_tmp/wiki.md`）。
