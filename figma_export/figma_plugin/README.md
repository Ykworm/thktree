# ThkTree Figma Node Importer

把 `figma_export/thk_tree_ui.figma.json` 这种 Figma Node Export JSON 一键导入到 Figma 中，生成**可编辑**的图层。

## 文件清单

```
figma_plugin/
├── manifest.json   # 插件元数据
├── code.js         # 已预编译，可直接被 Figma 加载
├── code.ts         # TypeScript 源码（修改后用 `npm run build` 重新生成 code.js）
├── ui.html         # 插件 UI（textarea + Import）
├── package.json    # 仅含 dev 依赖（TypeScript + Figma 类型）
├── tsconfig.json
└── README.md
```

## 在 Figma 中导入运行

1. 打开 Figma 桌面端（Plugin 开发仅在桌面端可用）。
2. 顶部菜单：`Plugins` → `Development` → `Import plugin from manifest…`
3. 选择本目录下的 `manifest.json` 即可。
4. 在任意 Figma 文件中通过 `Plugins` → `Development` → `ThkTree Figma Node Importer` 启动。
5. 把 `figma_export/thk_tree_ui.figma.json` 的内容粘贴到 textarea，点击 **Import**。
6. 插件会为每个 `CANVAS` 创建一个新页面，并按 `FRAME / TEXT / INSTANCE` 递归生成图层。

## 支持范围

| 节点类型 | 行为 |
| --- | --- |
| `DOCUMENT` | 仅作为容器递归处理 children |
| `CANVAS` | 创建一个新的 Page；可选 `backgroundColor` |
| `FRAME` | 创建 FrameNode，应用 Auto Layout / fills / 尺寸 |
| `TEXT` | 创建 TextNode，加载字体后写入 `characters` |
| `INSTANCE` | 按 `componentName` 映射成可视占位（见下） |

为了健壮性，额外兼容：`RECTANGLE`、`COMPONENT`、`COMPONENT_SET`（按 Frame/Rectangle 渲染）。

### FRAME 属性映射
- `absoluteBoundingBox.{width,height}` → `node.resize(w,h)`；当父级**不是** Auto Layout 时还会写入 `x/y`。
- `layoutMode=VERTICAL/HORIZONTAL` → Figma Auto Layout。
- `itemSpacing` → Auto Layout spacing。
- `paddingLeft/Right/Top/Bottom` → Auto Layout padding。
- `primaryAxisAlignItems` / `counterAxisAlignItems` → 主轴 / 副轴对齐（`MIN/CENTER/MAX/SPACE_BETWEEN`，`FLEX_END` 自动归一为 `MAX`）。
- `fills`：仅支持 `{ "type":"SOLID", "color":{"r":0~1,"g":0~1,"b":0~1,"a"?:0~1} }`。
- `cornerRadius`、`visible` 透传。

### TEXT 属性映射
- `characters` → `text.characters`
- `style.fontFamily`、`style.fontWeight`（数字 → Light/Regular/Medium/Semi Bold/Bold/Black）
- `style.fontSize` → `text.fontSize`
- `visible` 透传
- 字体加载失败时自动 fallback 到 `Inter Regular`，避免抛错中断。

### INSTANCE 映射规则
| componentName | 生成结果 |
| --- | --- |
| `FAB` | 56×56 圆形 Frame（蓝色背景，白色文字），中心展示 `iconName` |
| `IconButton` | 48×48 透明 Frame（Auto Layout 居中），中心展示 `iconName` |
| `Icon` | 直接生成文本节点显示 `iconName` |
| 其他 | 兜底生成带标签的 Frame（白底 + `componentName` 文本） |

## 修改源码 → 重新构建（可选）

```bash
cd figma_export/figma_plugin
npm install
npm run build
```

这会把 `code.ts` 编译为 `code.js`（manifest 中加载的就是 `code.js`）。如果你只是要使用，**不需要执行 npm install**，仓库内自带的 `code.js` 已可直接运行。

## 已知限制

- `VECTOR` 节点（如树形连接线）会被跳过——Figma 插件 API 没有简单的方式从坐标重建任意路径。
- `STROKES`、`strokeWeight`、阴影等视觉细节未做映射，可按需扩展 `applyFills` / 增加 `applyStrokes`。
- `dynamic-page` 模式下切换当前页使用 `figma.setCurrentPageAsync`；老版本环境会回退到同步赋值。
