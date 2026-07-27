# readme_i18n

多语言 README 目录。根目录 [`README.md`](../README.md) 为 GitHub 默认展示，**中英双语合并在同一文件**，通过页内锚点切换：

| 锚点 | 语言 |
|------|------|
| [`#en`](../README.md#en) | English |
| [`#zh-cn`](../README.md#zh-cn) | 简体中文 |

| 文件 | 说明 |
|------|------|
| [`README_en_US.md`](README_en_US.md) | 跳转至首页 `#en` |
| [`README_zh_CN.md`](README_zh_CN.md) | 跳转至首页 `#zh-cn` |

维护约定：

- **正文只维护根目录 `README.md`**（英文在上、`#zh-cn` 锚点以下为中文）
- 子目录文件仅为兼容旧链接的跳转页，无需同步全文
- 视觉素材路径：根目录 README 用 `./assets/readme/`、`./screenshots/readme_static/`
