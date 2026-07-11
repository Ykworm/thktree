#!/usr/bin/bin/python3
"""Step 4 · Tier 2 · 模块 design-tokens.yaml 裸色收口。
把 docs/modules/*/design-tokens.yaml 中内嵌的裸 CupertinoColors.* / Color(0x…)
引用替换为 AppColors token 名（与代码真源一致）。prose 注释里的颜色词不动。
"""
import os
import re

ROOT = "/Users/yuweikang/dev/ykcode/ThkTree"
MODS = os.path.join(ROOT, "docs/modules")

CUP = {
    "white": "white", "black": "black", "transparent": "transparent",
    "systemRed": "destructive", "destructiveRed": "destructive",
    "systemBlue": "accent", "systemIndigo": "accent", "systemGreen": "success",
    "separator": "border", "systemGrey": "textSecondary",
    "label": "textPrimary", "secondaryLabel": "textSecondary",
    "systemTeal": "waveTeal", "systemOrange": "waveOrange", "systemPurple": "wavePurple",
}
HEX = {"0x80000000": "scrim", "0xFF64748B": "textSecondary"}
# 裸系统色（无 CupertinoColors 前缀，作为独立引用值）
BARE = {"systemBlue": "accent", "systemTeal": "waveTeal",
        "systemOrange": "waveOrange", "systemPurple": "wavePurple"}

cup_re = re.compile(r"CupertinoColors\.(\w+)")
hex_re = re.compile(r"Color\((0x[0-9A-Fa-f]{8})\)")
bare_re = re.compile(r'"(systemBlue|systemTeal|systemOrange|systemPurple)"')

changed = []
for dp, _, fs in os.walk(MODS):
    for fn in fs:
        if fn != "design-tokens.yaml":
            continue
        p = os.path.join(dp, fn)
        s = open(p, encoding="utf-8").read()
        orig = s
        s = cup_re.sub(lambda m: f"AppColors.{CUP.get(m.group(1), m.group(0))}", s)
        s = hex_re.sub(lambda m: f"AppColors.{HEX.get(m.group(1), m.group(0))}", s)
        s = bare_re.sub(lambda m: f'"AppColors.{BARE[m.group(1)]}"', s)
        if s != orig:
            open(p, "w", encoding="utf-8").write(s)
            changed.append(p)

print("CHANGED:", len(changed))
for c in changed:
    print(" -", os.path.relpath(c, ROOT))
