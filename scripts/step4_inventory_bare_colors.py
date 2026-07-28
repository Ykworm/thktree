#!/usr/bin/bin/python3
"""Step 4 · Tier 1 裸色清点器。
扫描 lib/（排除 app_colors.dart）所有裸色，输出 file:line + 当前值 + 建议 AppColors token 映射。
读的是代码真源 app_colors.dart 的已知 token 值做匹配；匹配不上则标 FLAG 待人工判断。
"""
import os
import re

ROOT = "/Users/yuweikang/dev/ykcode/ThkTree"
LIB = os.path.join(ROOT, "lib")
EXCLUDE = {"lib/ui/core/theme/app_colors.dart"}

# ── AppColors 已知 token 值（取自 app_colors.dart，light/dark 取值统一映射 getter）──
# key = 8位hex（含 alpha），value = 建议 AppColors 引用
KNOWN = {
    0xFF6366F1: "accent",
    0xFF4F46E5: "accentDeep",
    0xFFEEF2FF: "accentLight",
    0xFF1E1B4B: "accentLight",
    0xFFF8FAFC: "pageBg",
    0xFF020617: "pageBg",
    0xFFFFFFFF: "surface / onSurface",
    0xFF0F172A: "surface",
    0xFFF1F5F9: "surfaceMuted / textPrimary",
    0xFF1E293B: "surfaceMuted / textPrimary",
    0xFF64748B: "textSecondary / textTertiary",
    0xFF94A3B8: "textSecondary / textTertiary",
    0xFFE2E8F0: "border",
    0xFF334155: "border",
    0xFFDC2626: "destructive",
    0xFF34C759: "success",
    0x80000000: "scrim",
    0x1F000000: "elevationShadow",
    0x806366F1: "questionSourceTag",
    0xFFC4A77D: "champagneGold",
    0xFF8E8B82: "warmGray",
    0xFFA89090: "dustyRose",
    0xFF8B9080: "sageGray",
    0xFF6B7B8E: "slateBlue",
}

# ── Cupertino 系统色 → AppColors token ──
CUPERTINO = {
    "systemRed": "destructive",
    "destructiveRed": "destructive",
    "systemBlue": "accent",
    "systemIndigo": "accent",
    "link": "accent",
    "systemGreen": "success",
    "label": "textPrimary",
    "secondaryLabel": "textSecondary",
    "tertiaryLabel": "textTertiary",
    "quaternaryLabel": "textTertiary",
    "separator": "border",
    "opaqueSeparator": "border",
    "systemGrey": "textSecondary",
    "systemGrey2": "textSecondary",
    "systemGrey3": "textTertiary",
    "systemGrey4": "border",
    "systemGrey5": "border",
    "systemGrey6": "surfaceMuted",
    "systemFill": "surfaceMuted",
    "secondarySystemFill": "surfaceMuted",
    "tertiarySystemFill": "surfaceMuted",
    "quaternarySystemFill": "surfaceMuted",
    "systemBackground": "pageBg",
    "secondarySystemBackground": "surfaceMuted",
    "tertiarySystemBackground": "surfaceMuted",
    "systemGroupedBackground": "pageBg",
    "secondarySystemGroupedBackground": "surfaceMuted",
    "lightBackgroundGray": "pageBg",
    "extraLightBackgroundGray": "pageBg",
    "darkBackgroundGray": "pageBg",
}

# 无对应 token 的 Cupertino 色（需人工/新增 token）
CUPERTINO_FLAG = {
    "systemTeal", "systemOrange", "systemPurple", "systemYellow",
    "systemPink", "systemCyan", "systemMint", "darkText",
}

# Material Colors.xxx —— 超出 handoff 主范围，单独标 FLAG 供 review
MATERIAL = {
    "transparent": "transparent (保留)",
}

hex_re = re.compile(r"Color\(0x([0-9A-Fa-f]{8})\)")
argb_re = re.compile(r"Color\.fromARGB\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)")
rgb_o_re = re.compile(r"Color\.fromRGBO\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*([0-9.]+)\s*\)")
from_re = re.compile(r"Color\.from\(\s*alpha:\s*([0-9.]+)\s*,\s*red:\s*([0-9.]+)\s*,\s*green:\s*([0-9.]+)\s*,\s*blue:\s*([0-9.]+)\s*\)")
cup_re = re.compile(r"CupertinoColors\.(\w+)")
mat_re = re.compile(r"(?<![\w.])Colors\.(\w+)")


def to_hex_from_ints(a, r, g, b):
    return ((int(a) & 0xFF) << 24) | ((int(r) & 0xFF) << 16) | ((int(g) & 0xFF) << 8) | (int(b) & 0xFF)


def to_hex_from_double(a, r, g, b):
    return (int(round(float(a) * 255)) << 24) | (int(round(float(r) * 255)) << 16) | (int(round(float(g) * 255)) << 8) | int(round(float(b) * 255))


rows = []
for dirpath, _, files in os.walk(LIB):
    for fn in files:
        if not fn.endswith(".dart"):
            continue
        rel = os.path.relpath(os.path.join(dirpath, fn), ROOT)
        if rel in EXCLUDE:
            continue
        with open(os.path.join(dirpath, fn), encoding="utf-8") as f:
            for i, line in enumerate(f, 1):
                found = []
                # Cupertino
                for m in cup_re.finditer(line):
                    name = m.group(1)
                    if name in CUPERTINO:
                        found.append(f"CupertinoColors.{name} → AppColors.{CUPERTINO[name]}")
                    elif name in CUPERTINO_FLAG:
                        found.append(f"CupertinoColors.{name} → FLAG:无token")
                    else:
                        found.append(f"CupertinoColors.{name} → FLAG:未归类")
                # Color(0x
                for m in hex_re.finditer(line):
                    v = int(m.group(1), 16)
                    if v in KNOWN:
                        found.append(f"Color(0x{m.group(1)}) → AppColors.{KNOWN[v]}")
                    else:
                        found.append(f"Color(0x{m.group(1)}) → FLAG:值不匹配")
                # Color.fromARGB
                for m in argb_re.finditer(line):
                    v = to_hex_from_ints(*m.groups())
                    if v in KNOWN:
                        found.append(f"Color.fromARGB({m.group(1)},{m.group(2)},{m.group(3)},{m.group(4)}) → AppColors.{KNOWN[v]}")
                    else:
                        found.append(f"Color.fromARGB(...) → FLAG:0x{v:08X}")
                # Color.fromRGBO
                for m in rgb_o_re.finditer(line):
                    v = to_hex_from_ints(int(float(m.group(4)) * 255), m.group(1), m.group(2), m.group(3))
                    if v in KNOWN:
                        found.append(f"Color.fromRGBO(...) → AppColors.{KNOWN[v]}")
                    else:
                        found.append(f"Color.fromRGBO(...) → FLAG:0x{v:08X}")
                # Color.from
                for m in from_re.finditer(line):
                    v = to_hex_from_double(*m.groups())
                    if v in KNOWN:
                        found.append(f"Color.from(...) → AppColors.{KNOWN[v]}")
                    else:
                        found.append(f"Color.from(...) → FLAG:0x{v:08X}")
                # Material Colors.x
                for m in mat_re.finditer(line):
                    name = m.group(1)
                    if name in MATERIAL:
                        found.append(f"Colors.{name} → {MATERIAL[name]}")
                    else:
                        found.append(f"Colors.{name} → FLAG:material色")
                if found:
                    rows.append((rel, i, line.strip()[:120], " | ".join(found)))

# 输出
out = os.path.join(ROOT, "build", "step4-bare-colors-inventory.md")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w", encoding="utf-8") as f:
    f.write("# Step 4 · Tier 1 裸色清单（code-first，源自 lib/ 实测）\n\n")
    f.write(f"总命中：{len(rows)} 处（排除 app_colors.dart 自身定义）\n\n")
    f.write("| # | 文件 | 行 | 行内容(截断) | 建议映射 |\n")
    f.write("|---|------|----|--------------|----------|\n")
    for idx, (rel, ln, content, sugg) in enumerate(rows, 1):
        f.write(f"| {idx} | `{rel}` | {ln} | {content} | {sugg} |\n")

# 汇总
flagged = [r for r in rows if "FLAG" in r[3]]
print(f"TOTAL={len(rows)}  FLAGGED={len(flagged)}")
print(f"written: {out}")
# 打印 FLAG 明细
if flagged:
    print("\n=== FLAG 明细（需人工/新增 token）===")
    for rel, ln, content, sugg in flagged:
        print(f"{rel}:{ln}  {sugg}")
