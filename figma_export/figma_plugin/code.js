// ThkTree Figma Node Importer - 预编译 JS（与 code.ts 同源，可直接被 Figma 加载）
// 如修改了 code.ts，请运行 `npm run build` 重新生成本文件。
"use strict";

figma.showUI(__html__, { width: 520, height: 600 });

var DEFAULT_FONT = { family: "Inter", style: "Regular" };
var loadedFonts = new Set();

function clamp01(n) {
  if (typeof n !== "number" || isNaN(n)) return 0;
  return Math.max(0, Math.min(1, n));
}

async function loadFontSafe(font) {
  var key = font.family + "|" + font.style;
  if (loadedFonts.has(key)) return font;
  try {
    await figma.loadFontAsync(font);
    loadedFonts.add(key);
    return font;
  } catch (e) {
    var fallbackKey = DEFAULT_FONT.family + "|" + DEFAULT_FONT.style;
    if (!loadedFonts.has(fallbackKey)) {
      await figma.loadFontAsync(DEFAULT_FONT);
      loadedFonts.add(fallbackKey);
    }
    return DEFAULT_FONT;
  }
}

function fontStyleFromWeight(weight) {
  if (!weight || typeof weight !== "number") return "Regular";
  if (weight <= 300) return "Light";
  if (weight <= 400) return "Regular";
  if (weight <= 500) return "Medium";
  if (weight <= 600) return "Semi Bold";
  if (weight <= 700) return "Bold";
  return "Black";
}

function applyFills(node, fills) {
  if (!fills || !Array.isArray(fills)) return;
  var out = [];
  for (var i = 0; i < fills.length; i++) {
    var f = fills[i];
    if (f && f.type === "SOLID" && f.color) {
      out.push({
        type: "SOLID",
        color: {
          r: clamp01(f.color.r),
          g: clamp01(f.color.g),
          b: clamp01(f.color.b),
        },
        opacity: typeof f.color.a === "number" ? clamp01(f.color.a) : 1,
      });
    }
  }
  try { node.fills = out; } catch (_) {}
}

function mapPrimaryAxis(v) {
  if (v === "CENTER") return "CENTER";
  if (v === "MAX" || v === "FLEX_END") return "MAX";
  if (v === "SPACE_BETWEEN") return "SPACE_BETWEEN";
  return "MIN";
}
function mapCounterAxis(v) {
  if (v === "CENTER") return "CENTER";
  if (v === "MAX" || v === "FLEX_END") return "MAX";
  return "MIN";
}

function applyAutoLayout(frame, n) {
  var mode = n.layoutMode;
  if (mode === "VERTICAL" || mode === "HORIZONTAL") {
    frame.layoutMode = mode;
    if (typeof n.itemSpacing === "number") frame.itemSpacing = n.itemSpacing;
    if (typeof n.paddingLeft === "number") frame.paddingLeft = n.paddingLeft;
    if (typeof n.paddingRight === "number") frame.paddingRight = n.paddingRight;
    if (typeof n.paddingTop === "number") frame.paddingTop = n.paddingTop;
    if (typeof n.paddingBottom === "number") frame.paddingBottom = n.paddingBottom;
    frame.primaryAxisAlignItems = mapPrimaryAxis(n.primaryAxisAlignItems);
    frame.counterAxisAlignItems = mapCounterAxis(n.counterAxisAlignItems);
  } else {
    frame.layoutMode = "NONE";
  }
}

function applySizeAndPosition(node, n, parentHasAutoLayout) {
  var box = n.absoluteBoundingBox;
  if (!box) return;
  var w = typeof box.width === "number" && box.width > 0 ? box.width : undefined;
  var h = typeof box.height === "number" && box.height > 0 ? box.height : undefined;
  if (w && h) {
    try { node.resize(w, h); } catch (_) {}
  }
  if (!parentHasAutoLayout) {
    if (typeof box.x === "number") { try { node.x = box.x; } catch (_) {} }
    if (typeof box.y === "number") { try { node.y = box.y; } catch (_) {} }
  }
}

async function createTextNode(n) {
  var family = (n.style && n.style.fontFamily) || "Inter";
  var styleName = fontStyleFromWeight(n.style && n.style.fontWeight);
  var used = await loadFontSafe({ family: family, style: styleName });
  var text = figma.createText();
  text.name = n.name || n.characters || "Text";
  text.fontName = used;
  text.characters = typeof n.characters === "string" ? n.characters : "";
  if (n.style && typeof n.style.fontSize === "number" && n.style.fontSize > 0) {
    text.fontSize = n.style.fontSize;
  }
  if (typeof n.visible === "boolean") text.visible = n.visible;
  return text;
}

async function createInstanceNode(n) {
  var componentName = n.componentName || "";
  var iconName = n.iconName || "";

  // FAB → 圆形按钮 + 中心 iconName
  if (componentName === "FAB") {
    var frame = figma.createFrame();
    frame.name = "FAB(" + (iconName || "fab") + ")";
    frame.resize(56, 56);
    frame.cornerRadius = 28;
    frame.fills = [{ type: "SOLID", color: { r: 0.39, g: 0.5, b: 0.96 } }];
    frame.layoutMode = "HORIZONTAL";
    frame.primaryAxisAlignItems = "CENTER";
    frame.counterAxisAlignItems = "CENTER";
    frame.primaryAxisSizingMode = "FIXED";
    frame.counterAxisSizingMode = "FIXED";
    var label = await createTextNode({
      type: "TEXT", characters: iconName || "+",
      style: { fontSize: 14, fontWeight: 500 },
    });
    try { label.fills = [{ type: "SOLID", color: { r: 1, g: 1, b: 1 } }]; } catch (_) {}
    frame.appendChild(label);
    if (typeof n.visible === "boolean") frame.visible = n.visible;
    return frame;
  }

  // IconButton → 48x48 Frame + 中心 iconName
  if (componentName === "IconButton") {
    var ib = figma.createFrame();
    ib.name = "IconButton(" + (iconName || "icon") + ")";
    ib.resize(48, 48);
    ib.fills = [];
    ib.layoutMode = "HORIZONTAL";
    ib.primaryAxisAlignItems = "CENTER";
    ib.counterAxisAlignItems = "CENTER";
    ib.primaryAxisSizingMode = "FIXED";
    ib.counterAxisSizingMode = "FIXED";
    var ibLabel = await createTextNode({
      type: "TEXT", characters: iconName || "?",
      style: { fontSize: 12 },
    });
    ib.appendChild(ibLabel);
    if (typeof n.visible === "boolean") ib.visible = n.visible;
    return ib;
  }

  // Icon → 文本节点显示 iconName
  if (componentName === "Icon") {
    var t = await createTextNode({
      type: "TEXT",
      name: "Icon(" + (iconName || "") + ")",
      characters: iconName || "",
      style: { fontSize: 14 },
    });
    if (typeof n.visible === "boolean") t.visible = n.visible;
    return t;
  }

  // 通用 INSTANCE 兜底
  var gen = figma.createFrame();
  gen.name = n.name || componentName || "INSTANCE";
  var box = n.absoluteBoundingBox;
  var w = (box && box.width) || 120;
  var h = (box && box.height) || 40;
  gen.resize(Math.max(1, w), Math.max(1, h));
  gen.fills = [{ type: "SOLID", color: { r: 0.95, g: 0.95, b: 0.97 } }];
  gen.cornerRadius = 6;
  gen.layoutMode = "HORIZONTAL";
  gen.primaryAxisAlignItems = "CENTER";
  gen.counterAxisAlignItems = "CENTER";
  gen.primaryAxisSizingMode = "FIXED";
  gen.counterAxisSizingMode = "FIXED";
  var labelText =
    (n.characters && String(n.characters)) ||
    componentName ||
    iconName ||
    "INSTANCE";
  var genLabel = await createTextNode({
    type: "TEXT", characters: labelText, style: { fontSize: 12 },
  });
  gen.appendChild(genLabel);
  if (typeof n.visible === "boolean") gen.visible = n.visible;
  return gen;
}

async function buildNode(n, parent, parentHasAutoLayout) {
  if (!n || !n.type) return;
  var type = n.type;

  if (type === "DOCUMENT") {
    if (Array.isArray(n.children)) {
      for (var i = 0; i < n.children.length; i++) {
        await buildNode(n.children[i], parent, parentHasAutoLayout);
      }
    }
    return;
  }

  if (type === "CANVAS") {
    var page = figma.createPage();
    page.name = n.name || "Imported Page";
    if (n.backgroundColor) {
      page.backgrounds = [{
        type: "SOLID",
        color: {
          r: clamp01(n.backgroundColor.r),
          g: clamp01(n.backgroundColor.g),
          b: clamp01(n.backgroundColor.b),
        },
      }];
    }
    if (Array.isArray(n.children)) {
      for (var j = 0; j < n.children.length; j++) {
        await buildNode(n.children[j], page, false);
      }
    }
    return;
  }

  if (type === "FRAME") {
    var f = figma.createFrame();
    f.name = n.name || "Frame";
    parent.appendChild(f);
    applyFills(f, n.fills);
    if (typeof n.cornerRadius === "number") {
      try { f.cornerRadius = n.cornerRadius; } catch (_) {}
    }
    applyAutoLayout(f, n);
    applySizeAndPosition(f, n, parentHasAutoLayout);
    if (typeof n.visible === "boolean") f.visible = n.visible;
    var childAutoLayout = n.layoutMode === "VERTICAL" || n.layoutMode === "HORIZONTAL";
    if (Array.isArray(n.children)) {
      for (var k = 0; k < n.children.length; k++) {
        await buildNode(n.children[k], f, childAutoLayout);
      }
    }
    return;
  }

  if (type === "TEXT") {
    var t = await createTextNode(n);
    parent.appendChild(t);
    applySizeAndPosition(t, n, parentHasAutoLayout);
    return;
  }

  if (type === "INSTANCE") {
    var node = await createInstanceNode(n);
    parent.appendChild(node);
    applySizeAndPosition(node, n, parentHasAutoLayout);
    return;
  }

  // 健壮性：RECTANGLE / COMPONENT / COMPONENT_SET
  if (type === "RECTANGLE") {
    var r = figma.createRectangle();
    r.name = n.name || "Rectangle";
    parent.appendChild(r);
    applyFills(r, n.fills);
    if (typeof n.cornerRadius === "number") {
      try { r.cornerRadius = n.cornerRadius; } catch (_) {}
    }
    applySizeAndPosition(r, n, parentHasAutoLayout);
    if (typeof n.visible === "boolean") r.visible = n.visible;
    return;
  }
  if (type === "COMPONENT" || type === "COMPONENT_SET") {
    var cf = figma.createFrame();
    cf.name = (type + ": " + (n.name || "")).trim();
    parent.appendChild(cf);
    applyFills(cf, n.fills);
    if (typeof n.cornerRadius === "number") {
      try { cf.cornerRadius = n.cornerRadius; } catch (_) {}
    }
    applyAutoLayout(cf, n);
    applySizeAndPosition(cf, n, parentHasAutoLayout);
    if (typeof n.visible === "boolean") cf.visible = n.visible;
    var cAuto = n.layoutMode === "VERTICAL" || n.layoutMode === "HORIZONTAL";
    if (Array.isArray(n.children)) {
      for (var m = 0; m < n.children.length; m++) {
        await buildNode(n.children[m], cf, cAuto);
      }
    }
    return;
  }
}

figma.ui.onmessage = async function (msg) {
  if (!msg) return;
  if (msg.type === "cancel") {
    figma.closePlugin();
    return;
  }
  if (msg.type !== "import") return;

  var raw = msg.json || "";
  var data;
  try {
    data = JSON.parse(raw);
  } catch (e) {
    figma.ui.postMessage({ type: "error", message: "JSON 解析失败：" + (e && e.message ? e.message : String(e)) });
    return;
  }

  try {
    await loadFontSafe(DEFAULT_FONT);

    var root = (data && data.document) ? data.document : data;
    var firstNewPage = null;
    var createdPageCount = 0;

    if (root && root.type === "DOCUMENT" && Array.isArray(root.children)) {
      for (var i = 0; i < root.children.length; i++) {
        var child = root.children[i];
        if (child && child.type === "CANVAS") {
          var page = figma.createPage();
          page.name = child.name || ("Imported Page " + (createdPageCount + 1));
          if (child.backgroundColor) {
            page.backgrounds = [{
              type: "SOLID",
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
            for (var j = 0; j < child.children.length; j++) {
              await buildNode(child.children[j], page, false);
            }
          }
        } else {
          await buildNode(child, figma.currentPage, false);
        }
      }
    } else {
      await buildNode(root, figma.currentPage, false);
    }

    if (firstNewPage) {
      try {
        if (typeof figma.setCurrentPageAsync === "function") {
          await figma.setCurrentPageAsync(firstNewPage);
        } else {
          figma.currentPage = firstNewPage;
        }
      } catch (_) {}
    }

    var summary = createdPageCount > 0
      ? ("导入成功，已创建 " + createdPageCount + " 个页面。")
      : "导入成功。";
    figma.ui.postMessage({ type: "success", message: summary });
    figma.notify("ThkTree Importer：" + summary);
  } catch (e) {
    var msgText = "导入失败：" + (e && e.message ? e.message : String(e));
    figma.ui.postMessage({ type: "error", message: msgText });
    figma.notify(msgText, { error: true });
  }
};
