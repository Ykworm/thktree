# Flutter Page Layout Rules

本文件用于约束 ThkTree 中新建或重构 Flutter 页面时的页面骨架选择，避免重复出现“列表或空态无法填满 body”的布局问题。

## 适用场景

当任务涉及以下任一情况时，先读本文件，再写页面：

- 新建 page / screen
- 调整页面骨架或滚动结构
- 列表、Grid、空态、加载态没有填满剩余区域
- `Large Title` 页面
- `CustomScrollView`、`Sliver`、`ListView`
- `Column` 内包含滚动组件

## 核心判断

先判断页面属于哪一类，再选布局骨架：

1. 主列表页
2. 单主内容页
3. section 流式内容页

### 1. 主列表页

适用场景：

- 页面主体是消息、主题、节点、搜索结果等列表
- 页面空态、加载态、错误态需要填满剩余视口
- 页面需要 `Large Title`

优先骨架：

```dart
CupertinoPageScaffold(
  child: CustomScrollView(
    slivers: [
      ThkNavBar.large(...),
      // search/filter/header
      SliverToBoxAdapter(child: ...),
      // list
      SliverList(...),
      // or empty/loading/error
      SliverFillRemaining(child: ...),
    ],
  ),
)
```

规则：

- 使用 `CustomScrollView + slivers`
- 列表优先用 `SliverList` / `SliverGrid`
- 空态、加载态、错误态优先用 `SliverFillRemaining`
- 不要把整页 `ListView` 作为一个 child 塞进 `ThkLargeTitlePage.children`

项目参考：

- `ThemeListScreen`
- `NoteBrowseScreen`

### 2. 单主内容页

适用场景：

- 页面只有一个主内容区
- 导航栏固定为 inline title
- 主体是一个列表、编辑区、详情区或单个滚动区域
- 页面希望保留顶部留白，同时让主内容面板填满剩余 body

优先骨架：

```dart
CupertinoPageScaffold(
  navigationBar: ThkNavBar.inline(...),
  child: SafeArea(
    child: ListView(...),
  ),
)
```

如果主体不是 `ListView`，但仍需要“头部固定 + 下方滚动区填满剩余高度”，用：

```dart
CupertinoPageScaffold(
  navigationBar: ThkNavBar.inline(...),
  child: SafeArea(
    child: Column(
      children: [
        const SomeHeader(),
        Expanded(
          child: ListView(...),
        ),
      ],
    ),
  ),
)
```

规则：

- 页面主滚动区可以直接作为 `CupertinoPageScaffold.child`
- 若用了 `Column`，滚动区必须包 `Expanded` 或 `Flexible`
- 该模式适合“只有一个主内容容器”的页面

如果页面属于"设置子页 / 选择子页 / 简单入口页"，并且你希望：

- 导航栏仍然是 `inline title`
- 第一个 item 不要贴着 nav bar
- 主体看起来像一整块接管剩余 body 的白色 pane

优先骨架：

```dart
CupertinoPageScaffold(
  navigationBar: ThkNavBar.inline(...),
  child: SafeArea(
    child: ThkFillCardPageBody(
      child: ListView.separated(
        padding: EdgeInsets.zero,
        ...
      ),
    ),
  ),
)
```

规则补充：

- `ThkFillCardPageBody` 适合 inline title 的设置子页、option picker、二级入口页
- 它解决的是"顶部留白 + pane 填满 body"的视觉问题，不等于 `large title`
- 如果页面语义是 `option list`，未选中项不要显示 chevron，只保留选中态勾选
- 如果没有可信品牌资产，不要为列表项硬塞占位 icon

项目参考：

- `ThemeDetailScreen`
- `SearchScreen`
- `LlmSettingsScreen`
- `DefaultModelConfigScreen`
- `DefaultModelPickerScreen`

### 3. Section 流式内容页

适用场景：

- 页面由多个 section 顺序堆叠而成
- 每个 section 高度由内容决定
- 页面更像设置页、说明页、信息卡片页

优先骨架：

```dart
ThkLargeTitlePage(
  title: ...,
  children: [
    SectionA(),
    SectionB(),
    SectionC(),
  ],
)
```

规则：

- `ThkLargeTitlePage` 适合 section 流式内容页
- 它内部是 `CustomScrollView + SliverList`
- `children` 中的每个 widget 都按自身内容高度布局
- 因此不适合作为“整页主列表容器”模板

项目参考：

- `SettingsScreen`

## 禁止事项

- 禁止把整页 `ListView` / `GridView` 直接当作 `ThkLargeTitlePage.children` 的一个 child
- 禁止在 `Column` 里直接放滚动组件而不包 `Expanded` / `Flexible`
- 禁止在 sliver 页面里优先写“普通 `ListView` 套 sliver child”这种双重滚动结构，除非有明确理由

## 快速判断表

- 需要 `Large Title`，而且主体是主列表：用 sliver 模式
- 页面只有一个主要滚动区域：用 `CupertinoPageScaffold + ListView`
- 页面是 inline title 的设置子页，想保留顶部留白并让 pane 填满 body：用 `ThkFillCardPageBody + ListView`
- 页面有固定头部和一个下方列表：用 `Column + Expanded`
- 页面只是多个 section 依次排列：用 `ThkLargeTitlePage`

## 现有页面为什么能工作

### `ThemeListScreen`

- 使用 `CustomScrollView + ThkNavBar.large + SliverList`
- 加载态、错误态使用 `SliverFillRemaining`
- 这是主列表页的推荐参考

### `ThemeDetailScreen`

- 使用 `CupertinoPageScaffold + inline navigationBar`
- 主体直接是 `ListView.separated`
- 没有把列表塞进按内容收缩的父容器里

### `SettingsScreen`

- 使用 `ThkLargeTitlePage`
- 内部是 `SliverList`
- 适合 section 流，不适合整页主列表

## 新建页面检查清单

写页面前先问自己：

1. 这是主列表页、单主内容页，还是 section 流式内容页？
2. 页面是否需要 `Large Title`？
3. 页面空态、加载态、错误态是否需要填满剩余视口？
4. 是否在 `Column` 中放入了滚动组件？如果是，是否已包 `Expanded` / `Flexible`？
5. 是否把整页滚动组件错误地塞进了 `ThkLargeTitlePage.children`？

只要第 3、4、5 任一答案不明确，先回到本文件重新选择骨架。
