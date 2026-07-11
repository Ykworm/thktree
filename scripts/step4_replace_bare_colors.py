#!/usr/bin/bin/python3
"""Step 4 · Tier 1 裸色替换器（code-first）。
把 lib/ 内裸 CupertinoColors.* 与裸 Color(0x…) 替换为 AppColors token。
- 自动去掉 CupertinoColors.x.resolveFrom(context) 的 .resolveFrom（AppColors getter 已随亮度变化）
- 替换后若文件用到 AppColors 但未 import，则补 import
- app_colors.dart 自身不处理（它是真源）
"""
import os
import re

ROOT = "/Users/yuweikang/dev/ykcode/ThkTree"
LIB = os.path.join(ROOT, "lib")
EXCLUDE = os.path.join(LIB, "ui/core/theme/app_colors.dart")
IMPORT_LINE = "import 'package:thk_tree/ui/core/theme/app_colors.dart';"

# Cupertino 系统色 → AppColors token
CUP = {
    "white": "white",
    "black": "black",
    "transparent": "transparent",
    "systemRed": "destructive",
    "destructiveRed": "destructive",
    "systemBlue": "accent",
    "systemIndigo": "accent",
    "systemGreen": "success",
    "separator": "border",
    "systemGrey": "textSecondary",
    "systemBackground": "pageBg",
    "label": "textPrimary",
    "secondaryLabel": "textSecondary",
    "systemTeal": "waveTeal",
    "systemOrange": "waveOrange",
}

# 裸 Color(0x…) → AppColors token
HEX = {
    0x80000000: "scrim",
    0xF0000000: "scrimStrong",
    0x61000000: "scrimMid",
    0x0D000000: "scrimSoft",
    0x0F000000: "scrimSoft",
    0x00000000: "transparent",
    0xFF0F1035: "labBg",
    0xFF3B82F6: "labAccentBlue",
    0xFFF97316: "labAccentOrange",
    0xFFA855F7: "labAccentPurple",
}

cup_re = re.compile(r"CupertinoColors\.(\w+)(?:\s*\.\s*resolveFrom\([^)]*\))?")
hex_re = re.compile(r"Color\(0x([0-9A-Fa-f]{8})\)")

changed_files = []
for dirpath, _, files in os.walk(LIB):
    for fn in files:
        if not fn.endswith(".dart"):
            continue
        path = os.path.join(dirpath, fn)
        if path == EXCLUDE:
            continue
        with open(path, encoding="utf-8") as f:
            src = f.read()
        original = src

        def cup_sub(m):
            name = m.group(1)
            if name in CUP:
                return f"AppColors.{CUP[name]}"
            return m.group(0)  # 未映射则保留（不应发生）

        src = cup_re.sub(cup_sub, src)

        def hex_sub(m):
            v = int(m.group(1), 16)
            if v in HEX:
                return f"AppColors.{HEX[v]}"
            return m.group(0)

        src = hex_re.sub(hex_sub, src)

        if src == original:
            continue

        # 补 import（若用到 AppColors 但未 import）
        if "AppColors." in src and IMPORT_LINE not in src:
            lines = src.split("\n")
            last_import = -1
            for i, line in enumerate(lines):
                if line.strip().startswith("import "):
                    last_import = i
            if last_import >= 0:
                lines.insert(last_import + 1, IMPORT_LINE)
            else:
                lines.insert(0, IMPORT_LINE)
            src = "\n".join(lines)

        with open(path, "w", encoding="utf-8") as f:
            f.write(src)
        changed_files.append(path)

print(f"CHANGED FILES: {len(changed_files)}")
for p in changed_files:
    print(" -", os.path.relpath(p, ROOT))
