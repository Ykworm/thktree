# 深色模式 Plan v2

> 目标：在 APP Settings 中加一个深浅模式切换开关，效果等同于在 iOS 系统设置中切换外观。
> 策略：先统一颜色体系（Phase 1），再加深色模式支持（Phase 2）。
> 方法：Loop Engineering — 每个 Loop 有明确的输入/输出/验证步骤。
> 深色模式色彩参考：UI/UX Pro Max "Modern Dark (Cinema Mobile)" + Tailwind Slate Scale。

---

## Phase 1：统一颜色体系（前置清理）

> 消除当前 3 套调色板并存的混乱，为深色模式打下干净基础。

### Loop 1.1 — 收拢颜色定义 + 文档同步

**改动**：

1. **`app_colors.dart`** — 新增：
   - `NodePalette` class（公开）
   - `nodePalettes` 列表（5 套典雅黑金配色，从 theme_detail_screen 搬过来）
   - `paletteForNode(String nodeId)` 方法
   - `success` = `Color(0xFF34C759)`（对应 systemGreen）
   - `onSurface` = white（卡片上前景色）

2. **`theme_detail_screen.dart`** — 删除本地 `_NodePalette`/`_nodePalettes`/`_paletteForNode`，改用 `AppColors.paletteForNode()`

3. **CupertinoColors 收拢**（7 处）：
   - `CupertinoColors.label` → `AppColors.textPrimary`
   - `CupertinoColors.secondaryLabel` → `AppColors.textSecondary`
   - `CupertinoColors.tertiaryLabel` → `AppColors.textTertiary`
   - `CupertinoColors.systemBackground` → `AppColors.surface`
   - 保留：`systemRed`/`destructiveRed`/`systemBlue`/`systemGreen`/`separator`/`white`/`black`/`transparent`

4. **文档同步**：
   - `design-tokens.yaml`：themeColors 和 nodePalettes 色值对齐代码
   - `theme-list-design.md`：第 2 节/第 3 节 色值对齐代码
   - `design-system.md`：第 0.1 节/第 1.7 节 更新

**验证**：
- `flutter build` 无报错
- `rg "skyBlue|mint|lavender|coral|amber" docs/_shared/design-tokens.yaml` → 0 命中
- `rg "电蓝|翠绿|紫罗兰|热粉|琥珀" docs/` → 0 命中
- `rg "_NodePalette|_paletteForNode" lib/ui/features/` → 0 命中
- 视觉回归：主题列表/详情颜色不变

---

## Phase 2：深色模式支持

### 深色模式色彩规范（基于 UI/UX Pro Max 研究）

**设计原则**：
1. **不用纯黑 #000000** — OLED 屏幕拖影 + 视觉刺眼
2. **不用纯白 #FFFFFF 做文字** — 深色背景下对比度过高，用 #EDEDEF 或 #F1F5F9
3. **保持 Slate scale 色系统一性** — light mode 已用 Slate，dark mode 继续用同系列深色端
4. **边框用 rgba 而非固定色值** — `rgba(255,255,255,0.08)` 比 `#334155` 更有层次感
5. **层级靠透明度而非色值差异** — surface/pageBg/surfaceMuted 用不同透明度的白叠加

**深色色值表**（基于 Modern Dark + Slate Scale 融合）：

| Token | 浅色值 | 深色值 | 来源 |
|-------|--------|--------|------|
| `pageBg` | `#F8FAFC` | `#020617` | Slate 950 — 最深底色 |
| `surface` | `#FFFFFF` | `#0F172A` | Slate 900 — 卡片/弹层 |
| `surfaceMuted` | `#F1F5F9` | `#1E293B` | Slate 800 — 二级区块 |
| `textPrimary` | `#1E293B` | `#F1F5F9` | Slate 100 — 主文字 |
| `textSecondary` | `#64748B` | `#94A3B8` | Slate 400 — 辅助文字 |
| `textTertiary` | `#94A3B8` | `#64748B` | Slate 500 — placeholder |
| `border` | `#E2E8F0` | `#334155` | Slate 700 — 分隔线 |
| `accentLight` | `#EEF2FF` | `#1E1B4B` | Indigo 950 — accent 浅底 |

**不变的颜色**（浅深通用）：
- `accent` (#6366F1) — Indigo，在深色背景上依然清晰
- `accentDeep` (#4F46E5) — pressed 态
- `destructive` (#DC2626) — 危险操作
- `success` (#34C759) — 成功状态
- `champagneGold`/`warmGray`/`dustyRose`/`sageGray`/`slateBlue` — 5 套主题色
- NodePalettes — 5 套节点色（低饱和度，在深色背景上仍可读）

### Loop 2.1 — AppColors 深色支持

**输入**：Phase 1 完成后的 `app_colors.dart`

**改动**：

1. **`app_colors.dart`**：
   - 新增 `static Brightness _brightness` + `static void setBrightness(Brightness b)`
   - 以下颜色从 `static const` 改为 `static Color get`（内部根据 `_brightness` 返回不同值）：
     - `pageBg`, `surface`, `surfaceMuted`
     - `textPrimary`, `textSecondary`, `textTertiary`
     - `border`, `accentLight`
   - 不变的颜色保持 `static const`：`accent`, `accentDeep`, `destructive`, `success`, `themeColors`, `nodePalettes`

2. **修复 5 处 `const` 用法**（移除 `const` 关键字，因为这些引用了不再是 const 的 getter）：
   - `thk_text_field.dart:82` — `const TextStyle(color: AppColors.textTertiary)` → `TextStyle(color: AppColors.textTertiary)`
   - `note_select_screen.dart:146` — 同上
   - `note_detail_screen.dart:475` — 同上
   - `note_detail_screen.dart:634` — 同上
   - `note_browse_screen.dart:170` — 同上
   - 注意：`router.dart:173` 的 `const activeColor = AppColors.accent` 不需要改（accent 仍是 const）

3. **`app_theme.dart`** — 新增 `AppTheme.dark`：
   ```dart
   static CupertinoThemeData get dark => CupertinoThemeData(
     brightness: Brightness.dark,
     primaryColor: AppColors.accent,
     scaffoldBackgroundColor: AppColors.pageBg,
     barBackgroundColor: AppColors.surface,
     textTheme: CupertinoTextThemeData(
       primaryColor: AppColors.accent,
       textStyle: TextStyle(
         fontFamily: _fontFamily,
         fontFamilyFallback: _fontFamilyFallback,
         fontSize: 17,
         fontWeight: FontWeight.w400,
         letterSpacing: -0.41,
         color: AppColors.textPrimary,
       ),
     ),
   );
   ```
   注意：`AppTheme.dark` 不能是 `const`（因为 `AppColors.pageBg` 等不再是编译期常量）。

**验证**：
- `flutter build` 无报错
- 浅色模式视觉不变（截图对比）
- 手动调用 `AppColors.setBrightness(Brightness.dark)` 后页面变暗

### Loop 2.2 — Riverpod Provider + Settings Toggle + 持久化

**输入**：Loop 2.1 完成后的代码

**改动**：

1. **`settings_controller.dart`** — 新增 `BrightnessNotifier`：
   ```dart
   class BrightnessNotifier extends Notifier<Brightness> {
     @override
     Brightness build() {
       // 从 SettingsStore 读取持久化的值
       final settings = ref.read(settingsControllerProvider).value;
       if (settings?.darkMode == true) return Brightness.dark;
       return Brightness.light;
     }
     
     void toggle() {
       final newBrightness = state == Brightness.light 
         ? Brightness.dark 
         : Brightness.light;
       state = newBrightness;
       // 持久化
       ref.read(settingsStoreProvider).saveDarkMode(newBrightness == Brightness.dark);
     }
   }
   
   final brightnessProvider = NotifierProvider<BrightnessNotifier, Brightness>(
     BrightnessNotifier.new,
   );
   ```

2. **`settings_store.dart`** — 新增持久化字段：
   - `AppSettings` 新增 `bool darkMode` 字段
   - `SettingsStore` 新增 `saveDarkMode(bool)` / `load()` 中读取 `dark_mode` key
   - 默认值：`false`（浅色模式）

3. **`main.dart`** — `ThkTreeApp` 读取 provider：
   ```dart
   class ThkTreeApp extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final brightness = ref.watch(brightnessProvider);
       AppColors.setBrightness(brightness);
       return CupertinoApp.router(
         theme: brightness == Brightness.light 
           ? AppTheme.light 
           : AppTheme.dark,
         // ... 其余不变
       );
     }
   }
   ```

4. **`settings_screen.dart`** — dev-only 切换开关：
   ```dart
   if (kDebugMode) ...[
     ThkListSection(
       header: 'Dev Tools',
       children: [
         _DarkModeToggle(),
       ],
     ),
   ],
   ```
   
   ```dart
   class _DarkModeToggle extends ConsumerWidget {
     @override
     Widget build(BuildContext context, WidgetRef ref) {
       final brightness = ref.watch(brightnessProvider);
       return ThkListTile(
         leading: Icon(brightness == Brightness.dark 
           ? CupertinoIcons.moon_fill 
           : CupertinoIcons.sun_max_fill),
         title: 'Dark Mode',
         subtitle: brightness == Brightness.dark ? 'Dark' : 'Light',
         trailing: CupertinoSwitch(
           value: brightness == Brightness.dark,
           onChanged: (_) => ref.read(brightnessProvider.notifier).toggle(),
         ),
       );
     }
   }
   ```

5. **l10n**：暂不加（dev-only 功能，硬编码英文即可）

**验证**：
- `flutter build` 无报错
- Settings 页出现 "Dark Mode" 开关（debug 模式）
- 切换开关后整个 APP 变暗/变亮
- 重启 APP 后深色模式保持（持久化生效）
- Release 模式下开关不显示

### Loop 2.3 — 深色模式视觉微调

**输入**：Loop 2.2 完成后，运行 APP 切到深色模式

**检查清单**：
- [ ] 主题列表页：背景、文字、书脊线、分隔线
- [ ] 主题详情页：节点圆圈、标题、副标题、拖拽指示线
- [ ] 笔记列表/详情/编辑器
- [ ] 聊天页：消息气泡、输入框
- [ ] 搜索页
- [ ] 设置页
- [ ] 对话框/弹层
- [ ] Swipe 手势颜色

**可能需要额外调整的**：
- `_NodePalette` 的标题色在深色背景上的对比度
- 消息气泡背景色
- 拖拽气泡背景色和阴影
- ShareCardWidget 背景
- CupertinoColors.systemBlue 在深色模式下的表现

**验证**：
- 每个屏幕截图对比深浅模式
- WCAG AA 对比度检查（文字 vs 背景 ≥ 4.5:1）

---

## Loop 状态追踪

| Loop | 状态 | 备注 |
|------|------|------|
| 1.1 统一颜色体系 | ✅ done | |
| 2.1 AppColors 深色支持 | ✅ done |
| 2.2 Provider + Toggle + 持久化 | ✅ done |
| 2.3 视觉微调 | pending | 依赖 2.2 |

---

## 待办（未来）

- [ ] 跟随系统深色模式（读 iOS 系统 Brightness，自动切换）
- [ ] 深色模式 l10n 文案
- [ ] 深色模式自动化测试
- [ ] 深色模式下的图标/图片适配
- [ ] 开放给所有用户（去掉 kDebugMode 限制）

---

## Assumptions

- 深色模式持久化到 SettingsStore（FlutterSecureStorage）
- 第一步只做手动切换，不做"跟随系统"
- themeColors（5 套主题色）暂不调整深色变体
- nodePalettes（5 套节点色）暂不调整，Loop 2.3 中如果对比度不够再改
- 保持 Cupertino-first，不做 Material Theme
- 不用纯黑 #000000 做背景（OLED 最佳实践）
- 不用纯白 #FFFFFF 做深色模式文字（减少刺眼）
