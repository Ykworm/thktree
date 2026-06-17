# 左滑删除按钮宽度无限增加导致布局溢出

**日期**：2026-06-06  
**模块**：notes / 笔记列表  
**标签**：Flutter, UI, 布局溢出, Dismissible, Swipeable

## 现象

笔记列表页左滑删除时，控制台报错：

```
RenderFlex overflowed by 114 pixels on the right.
```

或

```
A RenderFlex overflowed by XXX pixels on the right.
```

左滑后删除按钮区域宽度不断增大，最终超出屏幕边界。

## 根因分析

`Dismissible` 的 `background` 或 `secondaryBackground` 中使用了 `Row` 包裹 `Container`，且 `Container` 的宽度设置为 `double.infinity` 或依赖父约束无限扩展。当 `Dismissible` 计算滑动距离时，背景 widget 的宽度随滑动比例线性增长，没有上限。

错误模式：

```dart
// ❌ 错误：宽度无上限
Dismissible(
  background: Container(
    color: Colors.red,
    child: Row(
      children: [
        Container(width: double.infinity),  // 无限扩展！
        Icon(Icons.delete),
      ],
    ),
  ),
)
```

## 解决方案

### 方案 1：固定背景宽度（推荐）

```dart
// ✅ 正确：背景用 Stack + Positioned 固定宽度
Dismissible(
  key: Key(note.id),
  direction: DismissDirection.endToStart,
  background: Container(color: Colors.red),  // 纯色背景，无 child
  secondaryBackground: Container(
    color: Colors.red,
    alignment: Alignment.centerRight,
    padding: EdgeInsets.only(right: 20),
    child: Icon(Icons.delete, color: Colors.white),
  ),
  onDismissed: (_) => _deleteNote(note.id),
  child: ThkListTile(...),
)
```

### 方案 2：使用 SwipeableRow（自定义组件）

项目中封装了 `SwipeableRow`，内部正确处理了宽度约束：

```dart
SwipeableRow(
  onDelete: () => _deleteNote(note.id),
  child: ThkListTile(...),
)
```

### 方案 3：限制 Container 宽度

```dart
// ✅ 正确：显式限制宽度
Container(
  width: 80,  // 固定宽度
  color: Colors.red,
  child: Center(child: Icon(Icons.delete)),
)
```

## 关键代码

项目中的正确实现（`note_detail_screen.dart` 列表项）：

```dart
Dismissible(
  key: ValueKey(note.noteId),
  direction: DismissDirection.endToStart,
  background: Container(
    alignment: Alignment.centerRight,
    padding: const EdgeInsets.only(right: 20),
    color: CupertinoColors.systemRed,
    child: const Icon(
      CupertinoIcons.delete,
      color: CupertinoColors.white,
    ),
  ),
  onDismissed: (_) async {
    await _deleteNote(note.noteId);
  },
  child: ThkListTile(...),
)
```

## 相关文件

- `lib/ui/features/notes/note_detail_screen.dart` — 笔记列表左滑删除
- `lib/ui/core/widgets/swipeable_row.dart` — 封装组件（如有）

## 参考链接

- [Flutter 文档 - Dismissible](https://api.flutter.dev/flutter/widgets/Dismissible-class.html)
- [TECH-DEBT.md](../TECH-DEBT.md)

## 复盘

- **为什么一开始没发现**：布局溢出在屏幕宽度较小或字体较大的设备上更容易触发。开发时用的模拟器屏幕较宽，可能不触发。此外，滑动速度不同，宽度增长程度也不同，快速滑动时更容易溢出。
- **以后如何避免**：
  1. 任何 `Dismissible` 的 `background` / `secondaryBackground` 禁止使用 `double.infinity` 宽度
  2. 优先使用固定宽度的 `Container` + `Alignment` 布局，而非 `Row` + `Expanded`
  3. 在多种屏幕尺寸（iPhone SE / Pro Max）上测试滑动操作
- **扩展**：此问题模式适用于所有使用 `Dismissible`、`Slidable` 或自定义滑动删除组件的场景。
