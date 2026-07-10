# ThkTree UI Design System — Phase 2 完成概述

## 已完成

- 读取并分析笔记模块全流程源码：
  - 笔记浏览/首页、笔记编辑器、AI 生成标题、笔记详情、主题笔记列表
  - 主题选择器（Bottom Sheet）、主题列表、主题详情树
- 将笔记模块真实 Design Token 追加到 `thktree-design-spec.html`：
  - 新增 §7 Note Module，覆盖页面骨架、编辑器排版、生成标题、主题选择器、主题列表/详情
  - 汇总笔记模块中新增的 8 类硬编码/系统色偏差
- 扩展 `thktree-prototype.html`：
  - 新增 6 个高保真屏幕：笔记首页、笔记编辑器、生成标题、笔记详情、主题列表、主题详情
  - 新增主题选择器 Bottom Sheet 交互
  - 外部切换器增加对应入口

## 关键发现

- 笔记编辑器使用 28px/w600 大标题输入 + 17px/1.6 正文，标题为空时自动取正文前 8 字符
- AI 生成标题页采用「自定义输入 + 候选列表」双模式，选中态用 `accentLight` 底色
- 主题详情树使用节点配色盘（palette），节点行高 56pt，缩进 `depth * 28`
- 新增偏差：大量 Cupertino 系统色（systemRed/destructiveRed/separator/systemBlue/systemIndigo/systemGreen）未走 `AppColors` token

## 后续

- 切换到支持 vision 的模型 / 用户提供文字描述，对真机截图逐像素对比偏差
- 根据对比结果回修源码或更新规范
