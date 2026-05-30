// ThkTree Figma Node Importer
// 读取 Figma Node Export JSON，并在 Figma 中生成可编辑的图层。
// 支持节点类型：DOCUMENT / CANVAS / FRAME / TEXT / INSTANCE
// 同时为了健壮性，对 RECTANGLE / COMPONENT / COMPONENT_SET 也做了基础渲染。

figma.showUI(__html__, { width: 520, height: 600 });

interface NodeJson {
  id?: string;
  name?: string;
  type: string;
  visible?: boolean;
  absoluteBoundingBox?: { x?: number; y?: number; width?: number; height?: number };
  layoutMode?: 'VERTICAL' | 'HORIZONTAL' | 'NONE';
  itemSpacing?: number;
  paddingLeft?: number;
  paddingRight?: number;
  paddingTop?: number;
  paddingBottom?: number;
  primaryAxisAlignItems?: 'MIN' | 'CENTER' | 'MAX' | 'SPACE_BETWEEN' | string;
  counterAxisAlignItems?: 'MIN' | 'CENTER' | 'MAX' | 'FLEX_START' | string;
  fills?: Array<{ type: string; color?: { r: number; g: number; b: number; a?: number } }>;
  cornerRadius?: number;
  characters?: string;
  style?: { fontFamily?: string; fontSize?: number; fontWeight?: number };
  componentName?: string;
  iconName?: string;
  backgroundColor?: { r: number; g: number; b: number; a?: number };
  children?: NodeJson[];
}

const DEFAULT_FONT: FontName = { family: 'Inter', style: 'Regular' };
const loadedFonts = new Set<string>();

function clamp01(n: number): number {
  if (typeof n !== 'number' || isNaN(n)) return 0;
  return Math.max(0, Math.min(1, n));
}

async function loadFontSafe(font: FontName): Promise<FontName> {
  const key = `${font.family}|${font.style}`;
  if (loadedFonts.has(key)) return font;
  try {
    await figma.loadFontAsync(font);
    loadedFonts.add(key);
    return font;
  } catch (_e) {
    const fallbackKey = `${DEFAULT_FONT.family}|${DEFAULT_FONT.style}`;
    if (!loadedFonts.has(fallbackKey)) {
      await figma.loadFontAsync(DEFAULT_FONT);
      loadedFonts.add(fallbackKey);
    }
    return DEFAULT_FONT;
  }
}

function fontStyleFromWeight(weight?: number): string {
  if (!weight || typeof weight !== 'number') return 'Regular';
  if (weight <= 300) return 'Light';
  if (weight <= 400) return 'Regular';
  if (weight <= 500) return 'Medium';
  if (weight <= 600) return 'Semi Bold';
  if (weight <= 700) return 'Bold';
  return 'Black';
}

function applyFills(node: GeometryMixin | FrameNode, fills?: NodeJson['fills']): void {
  if (!fills || !Array.isArray(fills)) return;
  const out: Paint[] = [];
  for (const f of fills) {
    if (f && f.type === 'SOLID' && f.color) {
      out.push({
        type: 'SOLID',
        color: {
          r: clamp01(f.color.r),
          g: clamp01(f.color.g),
          b: clamp01(f.color.b),
        },
        opacity: typeof f.color.a === 'number' ? clamp01(f.color.a) : 1,
      });
    }
  }
  try { (node as any).fills = out; } catch (_) { /* ignore */ }
}

function mapPrimaryAxis(v?: string): 'MIN' | 'CENTER' | 'MAX' | 'SPACE_BETWEEN' {
  if (v === 'CENTER') return 'CENTER';
  if (v === 'MAX' || v === 'FLEX_END') return 'MAX';
  if (v === 'SPACE_BETWEEN') return 'SPACE_BETWEEN';
  return 'MIN';
}
function mapCounterAxis(v?: string): 'MIN' | 'CENTER' | 'MAX' {
  if (v === 'CENTER') return 'CENTER';
  if (v === 'MAX' || v === 'FLEX_END') return 'MAX';
  return 'MIN';
}

function applyAutoLayout(frame: FrameNode, n: NodeJson): void {
  const mode = n.layoutMode;
  if (mode === 'VERTICAL' || mode === 'HORIZONTAL') {
    frame.layoutMode = mode;
    if (typeof n.itemSpacing === 'number') frame.itemSpacing = n.itemSpacing;
    if (typeof n.paddingLeft === 'number') frame.paddingLeft = n.paddingLeft;
    if (typeof n.paddingRight === 'number') frame.paddingRight = n.paddingRight;
    if (typeof n.paddingTop === 'number') frame.paddingTop = n.paddingTop;
    if (typeof n.paddingBottom === 'number') frame.paddingBottom = n.paddingBottom;
    frame.primaryAxisAlignItems = mapPrimaryAxis(n.primaryAxisAlignItems);
    frame.counterAxisAlignItems = mapCounterAxis(n.counterAxisAlignItems);
  } else {
    frame.layoutMode = 'NONE';
  }
}

function applySizeAndPosition(node: SceneNode & LayoutMixin, n: NodeJson, hasAutoLayoutParent: boolean): void {
  const box = n.absoluteBoundingBox;
  if (!box) return;
  const w = typeof box.width === 'number' && box.width > 0 ? box.width : undefined;
  const h = typeof box.height === 'number' && box.height > 0 ? box.height : undefined;
  // 在 Auto Layout 容器中，Figma 会自动管理子节点尺寸/位置；只在顶层或非 AutoLayout 父级时设置
  if (w && h) {
    try { node.resize(w, h); } catch (_) { /* ignore */ }
  }
  if (!hasAutoLayoutParent) {
    if (typeof box.x === 'number') (node as any).x = box.x;
    if (typeof box.y === 'number') (node as any).y = box.y;
  }
}

async function createTextNode(n: NodeJson): Promise<TextNode> {
  const family = (n.style && n.style.fontFamily) || 'Inter';
  const styleName = fontStyleFromWeight(n.style && n.style.fontWeight);
  const used = await loadFontSafe({ family, style: styleName });
  const text = figma.createText();
  text.name = n.name || n.characters || 'Text';
  text.fontName = used;
  text.characters = typeof n.characters === 'string' ? n.characters : '';
  if (n.style && typeof n.style.fontSize === 'number' && n.style.fontSize > 0) {
    text.fontSize = n.style.fontSize;
  }
  if (typeof n.visible === 'boolean') text.visible = n.visible;
  return text;
}

async function createInstanceNode(n: NodeJson): Promise<SceneNode> {
  const componentName = n.componentName || '';
  const iconName = n.iconName || '';

  // 规则 1：FAB → 圆形按钮 + 中心 iconName
  if (componentName === 'FAB') {
    const frame = figma.createFrame();
    frame.name = `FAB(${iconName || 'fab'})`;
    frame.resize(56, 56);
    frame.cornerRadius = 28;
    frame.fills = [{ type: 'SOLID', color: { r: 0.39, g: 0.50, b: 0.96 } }];
    frame.layoutMode = 'HORIZONTAL';
    frame.primaryAxisAlignItems = 'CENTER';
    frame.counterAxisAlignItems = 'CENTER';
    frame.primaryAxisSizingMode = 'FIXED';
    frame.counterAxisSizingMode = 'FIXED';
    const label = await createTextNode({
      type: 'TEXT', characters: iconName || '+',
      style: { fontSize: 14, fontWeight: 500 },
    });
    try { label.fills = [{ type: 'SOLID', color: { r: 1, g: 1, b: 1 } }]; } catch (_) {}
    frame.appendChild(label);
    if (typeof n.visible === 'boolean') frame.visible = n.visible;
    return frame;
  }

  // 规则 2：IconButton → 48x48 Frame + 中心 iconName
  if (componentName === 'IconButton') {
    const frame = figma.createFrame();
    frame.name = `IconButton(${iconName || 'icon'})`;
    frame.resize(48, 48);
    frame.fills = [];
    frame.layoutMode = 'HORIZONTAL';
    frame.primaryAxisAlignItems = 'CENTER';
    frame.counterAxisAlignItems = 'CENTER';
    frame.primaryAxisSizingMode = 'FIXED';
    frame.counterAxisSizingMode = 'FIXED';
    const label = await createTextNode({
      type: 'TEXT', characters: iconName || '?',
      style: { fontSize: 12 },
    });
    frame.appendChild(label);
    if (typeof n.visible === 'boolean') frame.visible = n.visible;
    return frame;
  }

  // 规则 3：Icon → 文本节点显示 iconName
  if (componentName === 'Icon') {
    const t = await createTextNode({
      type: 'TEXT',
      name: `Icon(${iconName || ''})`,
      characters: iconName || '',
      style: { fontSize: 14 },
    });
    if (typeof n.visible === 'boolean') t.visible = n.visible;
    return t;
  }

  // 通用 INSTANCE 兜底：创建带标签的 Frame
  const frame = figma.createFrame();
  frame.name = n.name || componentName || 'INSTANCE';
  const box = n.absoluteBoundingBox;
  const w = (box && box.width) || 120;
  const h = (box && box.height) || 40;
  frame.resize(Math.max(1, w), Math.max(1, h));
  frame.fills = [{ type: 'SOLID', color: { r: 0.95, g: 0.95, b: 0.97 } }];
  frame.cornerRadius = 6;
  frame.layoutMode = 'HORIZONTAL';
  frame.primaryAxisAlignItems = 'CENTER';
  frame.counterAxisAlignItems = 'CENTER';
  frame.primaryAxisSizingMode = 'FIXED';
  frame.counterAxisSizingMode = 'FIXED';
  const labelText =
    (n.characters && String(n.characters)) ||
    componentName ||
    iconName ||
    'INSTANCE';
  const label = await createTextNode({
    type: 'TEXT', characters: labelText, style: { fontSize: 12 },
  });
  frame.appendChild(label);
  if (typeof n.visible === 'boolean') frame.visible = n.visible;
  return frame;
}

async function buildNode(
  n: NodeJson,
  parent: BaseNode & ChildrenMixin,
  parentHasAutoLayout: boolean,
): Promise<void> {
  if (!n || !n.type) return;
  const type = n.type;

  // DOCUMENT：递归处理 children（不创建实体节点）
  if (type === 'DOCUMENT') {
    if (Array.isArray(n.children)) {
      for (const c of n.children) await buildNode(c, parent, parentHasAutoLayout);
    }
    return;
  }

  // CANVAS：创建一个新页面（PageNode），在其中放置 children
  if (type === 'CANVAS') {
    const page = figma.createPage();
    page.name = n.name || 'Imported Page';
    if (n.backgroundColor) {
      page.backgrounds = [{
        type: 'SOLID',
        color: {
          r: clamp01(n.backgroundColor.r),
          g: clamp01(n.backgroundColor.g),
          b: clamp01(n.backgroundColor.b),
        },
      }];
    }
    if (Array.isArray(n.children)) {
      for (const c of n.children) await buildNode(c, page, false);
    }
    return;
  }

  // FRAME
  if (type === 'FRAME') {
    const f = figma.createFrame();
    f.name = n.name || 'Frame';
    parent.appendChild(f);
    applyFills(f, n.fills);
    if (typeof n.cornerRadius === 'number') {
      try { f.cornerRadius = n.cornerRadius; } catch (_) {}
    }
    applyAutoLayout(f, n);
    applySizeAndPosition(f, n, parentHasAutoLayout);
    if (typeof n.visible === 'boolean') f.visible = n.visible;
    const childAutoLayout = n.layoutMode === 'VERTICAL' || n.layoutMode === 'HORIZONTAL';
    if (Array.isArray(n.children)) {
      for (const c of n.children) await buildNode(c, f, childAutoLayout);
    }
    return;
  }

  // TEXT
  if (type === 'TEXT') {
    const t = await createTextNode(n);
    parent.appendChild(t);
    applySizeAndPosition(t, n, parentHasAutoLayout);
    return;
  }

  // INSTANCE
  if (type === 'INSTANCE') {
    const node = await createInstanceNode(n);
    parent.appendChild(node);
    applySizeAndPosition(node as any, n, parentHasAutoLayout);
    return;
  }

  // 额外健壮性：RECTANGLE / VECTOR / COMPONENT / COMPONENT_SET
  if (type === 'RECTANGLE') {
    const r = figma.createRectangle();
    r.name = n.name || 'Rectangle';
    parent.appendChild(r);
    applyFills(r, n.fills);
    if (typeof n.cornerRadius === 'number') {
      try { r.cornerRadius = n.cornerRadius; } catch (_) {}
    }
    applySizeAndPosition(r as any, n, parentHasAutoLayout);
    if (typeof n.visible === 'boolean') r.visible = n.visible;
    return;
  }
  if (type === 'COMPONENT' || type === 'COMPONENT_SET') {
    const f = figma.createFrame();
    f.name = `${type}: ${n.name || ''}`.trim();
    parent.appendChild(f);
    applyFills(f, n.fills);
    if (typeof n.cornerRadius === 'number') {
      try { f.cornerRadius = n.cornerRadius; } catch (_) {}
    }
    applyAutoLayout(f, n);
    applySizeAndPosition(f, n, parentHasAutoLayout);
    if (typeof n.visible === 'boolean') f.visible = n.visible;
    const childAutoLayout = n.layoutMode === 'VERTICAL' || n.layoutMode === 'HORIZONTAL';
    if (Array.isArray(n.children)) {
      for (const c of n.children) await buildNode(c, f, childAutoLayout);
    }
    return;
  }
  // VECTOR / 其他类型：忽略（按本插件规范不强求支持）
}

figma.ui.onmessage = async (msg: { type: string; json?: string }) => {
  if (msg.type === 'cancel') {
    figma.closePlugin();
    return;
  }
  if (msg.type !== 'import') return;

  const raw = msg.json || '';
  let data: any;
  try {
    data = JSON.parse(raw);
  } catch (e: any) {
    figma.ui.postMessage({ type: 'error', message: 'JSON 解析失败：' + (e.message || String(e)) });
    return;
  }

  try {
    await loadFontSafe(DEFAULT_FONT);

    const root: NodeJson = (data && data.document) ? data.document : data;
    let firstNewPage: PageNode | null = null;
    let createdPageCount = 0;

    if (root && root.type === 'DOCUMENT' && Array.isArray(root.children)) {
      for (const child of root.children) {
        if (child && child.type === 'CANVAS') {
          const page = figma.createPage();
          page.name = child.name || `Imported Page ${createdPageCount + 1}`;
          if (child.backgroundColor) {
            page.backgrounds = [{
              type: 'SOLID',
              color: {
                r: clamp01(child.backgroundColor.r),
                g: clamp01(child.backgroundColor.g),
                b: clamp01(child.backgroundColor.b),
              },
            }];
          }
          if (!firstNewPage) firstNewPage = page;
          createdPageCount++;
          if (Array.isArray(child.children)) {
            for (const c of child.children) await buildNode(c, page, false);
          }
        } else {
          // DOCUMENT 直接挂了非 CANVAS 子节点：放到当前页
          await buildNode(child, figma.currentPage, false);
        }
      }
    } else {
      // 不是 DOCUMENT 包裹：直接渲染到当前页
      await buildNode(root, figma.currentPage, false);
    }

    if (firstNewPage) {
      try {
        // dynamic-page 模式下需要 await
        await figma.setCurrentPageAsync(firstNewPage);
      } catch (_e) {
        try { (figma as any).currentPage = firstNewPage; } catch (_) {}
      }
    }

    const summary = createdPageCount > 0
      ? `导入成功，已创建 ${createdPageCount} 个页面。`
      : '导入成功。';
    figma.ui.postMessage({ type: 'success', message: summary });
    figma.notify('ThkTree Importer：' + summary);
  } catch (e: any) {
    const msgText = '导入失败：' + (e && e.message ? e.message : String(e));
    figma.ui.postMessage({ type: 'error', message: msgText });
    figma.notify(msgText, { error: true });
  }
};
