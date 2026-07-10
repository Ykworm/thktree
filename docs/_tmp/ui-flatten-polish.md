# UI 扁平化与美化 — 设计稿（ui-flatten-polish）

> 分支：`codex/ui-flatten-polish`（freemode，未走 worktree）
> 状态：方案已与用户确认方向，本文为 brainstorming 后的草稿归档

## 目标
ThkTree 三个核心页面（chat / 主题列表 / 知识树）已偏扁平（low-saturation 典雅黑金底子 + Indigo 强调）。本次优化：
1. **chat 更扁平化**——减噪、理清层级
2. **主题列表美化**——用上当前被浪费的主题色
3. **知识树**——加父子连接线（用户改主意：有连线更清晰美观，本页需改动）

## 现状诊断（基于真实代码）

### Chat 页（`chat_screen` + `message_bubble` + `chat_composer`）
- 输入区是 **4 个独立圆角 surface 容器**（TextField 20 圆角 + 碎片按钮 + 发送按钮 + 底边栏），视觉很碎
- 每条气泡底部一排操作图标（copy / tts / share / note / retry），长会话里很吵
- 顶部三层：nav 标题 → 面包屑 bar →（模型面板），气泡内还有 role·model·status 标题，信息层级略重
- 气泡靠底色区分（用户浅 indigo / 助手纯白 vs Slate50 背景），对比微妙但够用

### 主题列表（`theme_list_screen`）
- 朴素 iOS list（folder icon + divider + subtitle 预览/时间），本身已平
- **最大浪费**：`colorForTheme` 算好的香槟金 / 灰绿 / 灰紫等 5 色完全没用在列表（folder 是默认灰，主题色只在知识树节点圆点和节点卡片出现）

### 知识树（`full_tree_screen`）
- 纯缩进（28px/层）+ 小圆点（palette 色）+ 当前节点 indigo 高亮 + 左边条
- 无父子连接线；用户视觉对比后反复横跳，最终落回**无连线（纯缩进 + 主题色圆点）更清爽美观**，**保持现状不改动**

## 方案（已确认方向）

### 1. Chat 温和收敛
- 输入区：4 容器合并为 **1 个 surface 卡片**（包 TextField + 底部工具行），从 4 → 1，立刻更平
- 气泡操作行：默认隐藏，改为**点击 / 长按展开**，降噪
- 面包屑：仅深层节点显示，或降级为更轻样式
- 助手气泡：从纯白调到与背景更融合的极浅处理，减少白块堆叠

### 2. 主题列表 — 主题色卡片网格
- list → **2 列卡片网格**
- 卡片含：主题色封面 / 色条（用 `colorForTheme`）+ 标题 + 最后消息预览
- 列表 → 网格是较大视觉跃迁，需用户视觉拍板

### 3. 知识树 — 保持无连线（用户最终拍板）
- 用户在 Ardot / HTML before/after 对比后反复横跳（无连线 → 有连线 → 无连线），最终落回：**无连线（纯缩进 + 主题色圆点）更好看**，放弃加连接线方案
- 保留现有主题色圆点 + 缩进结构，本页**不做视觉改动**
- 仅可做极轻微微调（如圆点配色统一性），不作为必做项

## 验收方式
- 编译通过 + `dart analyze` 无新增错误
- 关键路径：三页 before/after 视觉对比
- ardot 可用时出画布对比稿；不可用时先文档 + 手工验证

## 待确认 / 风险
- ⚠️ **ardot 画布当前不可用**（`NO_ADAPTER`，根因：ardot 是 builtin-mcp-app，外部 kill 不自动重拉，文档渲染依赖 WorkBuddy 客户端 adapter + route key）。需**重启 WorkBuddy** 恢复。恢复前视觉稿暂缓，已沉淀排障 skill `ardot-restart`。
- dev 上 breadcrumb 未提交改动曾带入此分支；当前工作区已干净，落地 UI 改动前确保分支纯净。
- 主题卡片网格是 list→grid 跃迁，建议 ardot 恢复后出 before/after 让用户拍板再实现。

## 下一步（执行序列）
1. ✅ 草稿归档（本文件）
2. ⏳ 视觉稿：ardot 恢复后加载 `ardot-design-core` / `ardot-design-router`，在画布铺 chat / 主题 / 树 三组 before/after
3. ⏳ 实现：按方案改 Dart（输入区合并 / 操作行收起 / 列表卡片网格）
4. ⏳ context-sync：同步受影响 docs
