# Screenshots

产品截图与 README / App Store 演示素材。不进 `pubspec.yaml`，不打进 App 包。

## 目录结构

```
screenshots/
  readme_static/          # README 专用截图
    themes/                 # 知识树、主题列表
    chat/                   # 对话、Pin 对照栏
    clips/                  # Clips
  app_store/                # （可选）App Store 素材
```

## readme_static 文件清单

| 文件 | 说明 |
|------|------|
| `readme_static/themes/themes_zh_CN.png` | 主题列表（中文界面） |
| `readme_static/themes/themes_english.jpg` | 主题列表（英文界面） |
| `readme_static/themes/tree.png` | 知识树视图 |
| `readme_static/themes/merge-chat_zh_CN.png` | 合并 & 创建新 Chat（中文界面） |
| `readme_static/chat/pin-chat-before.jpeg` | Pin 对照栏 — 钉之前 |
| `readme_static/chat/pin-chat-after.png` | Pin 对照栏 — 钉之后 |
| `readme_static/chat/pin-view.png` | Pin 对照视图 |
| `readme_static/clips/clips.png` | Clips 功能 |
| `readme_static/clips/clips-processing.png` | Clips 处理中 |

在 README 中引用示例：

```markdown
![知识树](./screenshots/readme_static/themes/tree.png)
```
