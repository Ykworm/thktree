# 实验室 Tab 背景图替换（草稿）

## 目标

把 `LabPlaceholderScreen` 的蓝色 background 和 List 占位卡片都删掉，改用 `assets/background/lab_bg_32pt.png` 作为页面背景图；保留 `l10n.labEmptyHint` 占位文案作为前景文字。

## 改动文件

### 1. `lib/ui/features/lab/lab_placeholder_screen.dart`（主改动）

- **删除** `backgroundColor: AppColors.labSurface`（蓝色 background）
- **删除** 整个 `ListView` + 30 个 `_LabBlock` 卡片
- **删除** `_LabBlock` 内部类
- **新增** `Image.asset('assets/background/lab_bg_32pt.png', fit: BoxFit.contain)` 作为 page 背景
- **保留** `l10n.labEmptyHint` 占位文案，叠在背景图上

最终结构（伪代码）：

```dart
return CupertinoPageScaffold(
  // backgroundColor 删除
  navigationBar: CupertinoNavigationBar(middle: Text(l10n.labTabLabel)),
  child: Stack(
    children: [
      // 背景图
      Positioned.fill(
        child: Image.asset(
          'assets/background/lab_bg_32pt.png',
          fit: BoxFit.contain,
        ),
      ),
      // 前景占位文案
      Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(l10n.labEmptyHint, ...),
        ),
      ),
    ],
  ),
);
```

### 2. `lib/ui/core/theme/app_colors.dart`

- **删除** `labSurface` getter（无其他引用）

### 3. `pubspec.yaml`

- **添加** `- assets/background/` 到 `flutter.assets` 列表

## 保留项

- `l10n.labEmptyHint` 保留（中英文文案不变）
- `assets/icons/lab_selected.png` / `lab_unselect.png` 不动
- 集成测试 `lab_tab_test.dart` 验证 `labEmptyHint` 文案的断言无需调整
- `codex/liquid-glass-tabbar` 分支上其他未提交改动（liquid glass tab bar / router / widgets）继续保留

## 验收

1. `flutter analyze` 无新增 error
2. 集成测试 `lab_tab_test.dart` 全部 case 通过
3. 手动验证：iOS 真机 / 模拟器上切换到实验室 tab，能看到背景图 + "实验功能筹备中" 占位文案
4. lab_bg_32pt.png 在 hot reload 中能正确加载（确认 pubspec 声明生效）

## 后续（不在本次范围）

- 实验室具体子功能（AI 摘要交互卡 / 多节点对比 / 思维碰撞原型 / AI 写节点 / AI 节点标签建议）按 P.9 roadmap 单独迭代
- 当前占位文案继续保留，等子功能落地后替换
