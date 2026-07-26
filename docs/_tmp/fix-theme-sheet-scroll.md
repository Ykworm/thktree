# fix-theme-sheet-scroll

## 问题描述

新建笔记时弹出的主题选择 sheet 里的 List 无法滚动。

## 问题定位

文件：`lib/ui/features/notes/node_location_picker.dart`

### _ThemePickerContent (line 536-595)

```dart
return Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    // ... header (line 543-556)
    else
      Flexible(
        child: CupertinoListSection.insetGrouped(
          children: [
            for (final theme in _themes ?? [])
              CupertinoListTile(...)
          ],
        ),
      ),
  ],
);
```

**问题**：`CupertinoListSection.insetGrouped` 本身不支持滚动，当主题数量多时内容溢出。

### _NodeLocationPickerContent

- `_buildThemeList` (line 265-330)：同样使用 `Flexible` + `CupertinoListSection`，无滚动
- `_buildNodeTree` (line 332-381)：同样问题

## 修复方案

将 `CupertinoListSection.insetGrouped` 包裹在 `SingleChildScrollView` 中：

```dart
Flexible(
  child: SingleChildScrollView(
    child: CupertinoListSection.insetGrouped(
      // ...
    ),
  ),
)
```

## 涉及位置

1. `_ThemePickerContent.build()` - line 582-592
2. `_NodeLocationPickerContentState._buildThemeList()` - line 297-327
3. `_NodeLocationPickerContentState._buildNodeTree()` - line 367-378

## 验证

- 创建足够多的主题使列表超出 sheet 高度
- 验证列表可以正常滚动
- 验证选中主题功能正常