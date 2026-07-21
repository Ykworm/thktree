import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/services/pin_content_loader.dart';
import 'package:thk_tree/data/services/pin_storage.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/link_launcher.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle;
import 'package:thk_tree/ui/features/notes/note_editor_screen.dart';
import 'package:thk_tree/ui/features/notes/note_select_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';

/// 面板是否已打开：防止连点手柄重复 push 出多个叠层面板。
bool _pinPanelOpen = false;

/// 打开对照栏面板（居上大卡片 + 底部关闭按钮，全屏深色 scrim，点外侧关闭）。
///
/// push 到 root navigator：面板与 scrim 盖住整个屏幕（含 shell 底部 tab bar），
/// 关闭按钮才能压在 tab bar 区域上。
///
/// [currentThemeId] / [currentNodeId] 用于 Source 时识别「同一 chat 就地滚动」；
/// [onJumpInPlace] 在同一 chat 时回调就地滚动，避免重复 push 当前页。
Future<void> showPinPeekPanel(
  BuildContext context, {
  String? currentThemeId,
  String? currentNodeId,
  void Function(String msgId)? onJumpInPlace,
}) {
  if (_pinPanelOpen) return Future.value();
  _pinPanelOpen = true;
  return Navigator.of(context, rootNavigator: true)
      .push(
        _SlideFromRightRoute(
          builder: (_) => PinPeekPanel(
            currentThemeId: currentThemeId,
            currentNodeId: currentNodeId,
            onJumpInPlace: onJumpInPlace,
          ),
        ),
      )
      .whenComplete(() => _pinPanelOpen = false);
}

/// 从右往左滑入的透明路由（镜像 search_screen 的 _SlideFromLeftRoute）。
/// scrim 用较深的 50% 黑（scrimMid 太透）。
class _SlideFromRightRoute extends PageRouteBuilder<void> {
  _SlideFromRightRoute({required this.builder})
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: AppColors.scrim,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
        );

  final WidgetBuilder builder;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutCubic));
    return SlideTransition(
      position: animation.drive(slide),
      child: child,
    );
  }
}

/// 屏幕右缘的细长竖条把手（对照栏入口）。
///
/// 挂在 shell 层（[ShellPinEdgeHandle]，Themes / Notes tab 常驻）；
/// 自身带 [Positioned] 定位。pins 为空时不显示；
/// 点击或向左拖动打开对照面板，上下拖动可自由移动位置（会话内记忆）。
class PinEdgeHandle extends ConsumerStatefulWidget {
  const PinEdgeHandle({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  ConsumerState<PinEdgeHandle> createState() => _PinEdgeHandleState();
}

class _PinEdgeHandleState extends ConsumerState<PinEdgeHandle> {
  int _count = 0;

  /// 相对默认位置（屏高约 1/4 处）的纵向拖动偏移；仅会话内记忆，不落盘。
  double _dragOffsetY = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    try {
      final storage = await ref.read(pinStorageProvider.future);
      final pins = await storage.getAll();
      if (!mounted) return;
      setState(() => _count = pins.length);
    } catch (_) {
      // 读取失败保持现状，不影响聊天主流程
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pinListVersionProvider, (_, _) => unawaited(_reload()));
    if (_count == 0) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    // 默认放在上半部分的中间（屏幕约 1/4 高度处），不挡聊天正文
    final defaultTop = screenHeight / 4 - 50;
    final minTop = mq.padding.top + 4;
    final maxTop = screenHeight - mq.padding.bottom - 104;
    final top =
        (defaultTop + _dragOffsetY).clamp(minTop, maxTop).toDouble();

    return Positioned(
      right: 0,
      top: top,
      child: GestureDetector(
        onTap: widget.onOpen,
        onHorizontalDragEnd: (details) {
          // 向左快速拖动也打开面板
          if ((details.primaryVelocity ?? 0) < -100) widget.onOpen();
        },
        onVerticalDragUpdate: (details) {
          // 上下拖动自由移动把手位置
          final newTop = (top + details.delta.dy)
              .clamp(minTop, maxTop)
              .toDouble();
          setState(() => _dragOffsetY = newTop - defaultTop);
        },
        child: Container(
          width: 26,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.accentLight,
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(13),
            ),
            border: Border.all(
              color: AppColors.accent.withValues(alpha: 0.3),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.elevationShadow,
                blurRadius: 8,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.pin, size: 13, color: AppColors.accent),
              const SizedBox(height: 4),
              Text(
                '$_count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// shell 层对照栏把手：Themes / Notes tab 常驻（挂在 _MainShell /
/// AndroidNavigationShell 的 Stack 里，分支内 push 的页面盖不住）。
///
/// 打开面板时读取 ChatScreen 注册的 [pinJumpContextProvider]：
/// 面板正覆盖当前 chat 时，message pin 的 Source 才能就地滚动。
class ShellPinEdgeHandle extends ConsumerWidget {
  const ShellPinEdgeHandle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PinEdgeHandle(
      onOpen: () {
        final jump = ref.read(pinJumpContextProvider);
        unawaited(showPinPeekPanel(
          context,
          currentThemeId: jump?.themeId,
          currentNodeId: jump?.nodeId,
          onJumpInPlace: jump?.jumpInPlace,
        ));
      },
    );
  }
}

/// 对照栏面板：居上大卡片 + 底部关闭按钮，横向 PageView 一页一张 Pin 卡（上限 5 条）。
class PinPeekPanel extends ConsumerStatefulWidget {
  const PinPeekPanel({
    super.key,
    this.currentThemeId,
    this.currentNodeId,
    this.onJumpInPlace,
  });

  final String? currentThemeId;
  final String? currentNodeId;
  final void Function(String msgId)? onJumpInPlace;

  @override
  ConsumerState<PinPeekPanel> createState() => _PinPeekPanelState();
}

class _PinPeekPanelState extends ConsumerState<PinPeekPanel> {
  final _pageController = PageController();
  List<Pin> _pins = [];
  bool _loading = true;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final storage = await ref.read(pinStorageProvider.future);
      final pins = await storage.getAll();
      if (!mounted) return;
      if (pins.isEmpty) {
        // 删空后面板自动关闭
        Navigator.of(context).maybePop();
        return;
      }
      setState(() {
        _pins = pins;
        _loading = false;
      });
      // 当前页被删导致页码越界时回夹到最后一页
      if (_currentPage >= pins.length) {
        _currentPage = pins.length - 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pageController.hasClients) return;
          _pageController.jumpToPage(_currentPage);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pinListVersionProvider, (_, _) => unawaited(_reload()));
    final l10n = AppLocalizations.of(context)!;
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    // 卡片高度动态算：顶部安全区 +8 起，底边延伸到关闭按钮上方 20px，
    // 不同机型上卡片与 X 的间距都一致
    final cardTop = mediaQuery.padding.top + 8;
    final closeTop = screenSize.height - mediaQuery.padding.bottom - 18 - 44;
    final cardHeight = closeTop - cardTop - 20;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // 大卡片：靠上放置，底边接近底部的关闭按钮
          Positioned(
            top: cardTop,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // 阻止点击卡片区域关闭
                child: Container(
                  width: screenSize.width * 0.92,
                  height: cardHeight,
                  decoration: BoxDecoration(
                    color: AppColors.pageBg,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.elevationShadow,
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Column(
                      children: [
                        // 标题
                        Padding(
                          padding: const EdgeInsets.only(top: 14, bottom: 4),
                          child: Text(
                            l10n.pinPeekTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        // 页码指示（多于一张时；放标题下，避开底边关闭按钮）
                        if (!_loading && _pins.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (var i = 0; i < _pins.length; i++)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == _currentPage
                                          ? AppColors.accent
                                          : AppColors.textQuaternary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        // 卡片 PageView（左右滑动切换）
                        Expanded(
                          child: _loading
                              ? const Center(
                                  child: CupertinoActivityIndicator())
                              : PageView.builder(
                                  controller: _pageController,
                                  itemCount: _pins.length,
                                  // 必须 setState：页码圆点跟着当前页高亮
                                  onPageChanged: (i) =>
                                      setState(() => _currentPage = i),
                                  itemBuilder: (context, index) => _PinCard(
                                    key: ValueKey(_pins[index].id),
                                    pin: _pins[index],
                                    currentThemeId: widget.currentThemeId,
                                    currentNodeId: widget.currentNodeId,
                                    onJumpInPlace: widget.onJumpInPlace,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // 关闭按钮：下移到屏幕底部，压在 shell 的 tab bar 区域上，点击缩回聊天页
          Positioned(
            left: 0,
            right: 0,
            bottom: mediaQuery.padding.bottom + 18,
            child: Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    // 深色半透明圆 + 白图标：在白底 tab bar 上也不会被看成 tab 按钮
                    color: AppColors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.close,
                    size: 20,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张 Pin 卡：来源行 + 全文可滚动预览 + Source / To Note / Remove。
class _PinCard extends ConsumerStatefulWidget {
  const _PinCard({
    super.key,
    required this.pin,
    this.currentThemeId,
    this.currentNodeId,
    this.onJumpInPlace,
  });

  final Pin pin;
  final String? currentThemeId;
  final String? currentNodeId;
  final void Function(String msgId)? onJumpInPlace;

  @override
  ConsumerState<_PinCard> createState() => _PinCardState();
}

class _PinCardState extends ConsumerState<_PinCard> {
  PinContent? _content;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final loader = await ref.read(pinContentLoaderProvider.future);
      final content = await loader.load(widget.pin);
      if (!mounted) return;
      setState(() {
        _content = content;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 来源行：消息 →「主题名 · chat 标题」；笔记 → 笔记标题。
  /// 标题未加载到时退化为 excerpt。
  String _sourceLine(AppLocalizations l10n, ThemeDetailState? detail) {
    final pin = widget.pin;
    if (detail == null) return pin.excerpt;
    final themeTitle = localizedThemeTitle(l10n, detail.themeTitle);
    if (pin.kind == PinKind.note) {
      final noteTitle = _content?.noteTitle;
      if (noteTitle != null && noteTitle.isNotEmpty) return noteTitle;
      return themeTitle;
    }
    final nodeTitle = detail.nodes
        .where((n) => n.nodeId == pin.nodeId)
        .firstOrNull
        ?.title;
    return nodeTitle != null ? '$themeTitle · $nodeTitle' : themeTitle;
  }

  /// Source：消息 → 跳到来源 chat 并滚到该消息；笔记 → 打开笔记编辑器。
  Future<void> _jump(String? themeTitle) async {
    final pin = widget.pin;
    if (pin.kind == PinKind.message) {
      final themeId = pin.themeId;
      final nodeId = pin.nodeId;
      final msgId = pin.msgId;
      if (themeId == null || nodeId == null || msgId == null) return;
      Navigator.of(context).pop();
      if (nodeId == widget.currentNodeId && themeId == widget.currentThemeId) {
        // 同一 chat：就地滚动，不重复 push
        widget.onJumpInPlace?.call(msgId);
        return;
      }
      // 跨 chat：置位 pending scroll，新 ChatScreen 进入时消费（优先于锚点恢复）
      ref.read(pendingScrollMsgIdProvider.notifier).set(msgId);
      context.push('/themes/$themeId/nodes/$nodeId');
      return;
    }

    final themeId = pin.themeId;
    final noteId = pin.noteId;
    if (themeId == null || noteId == null) return;
    try {
      final paths = await ref.read(appPathsProvider.future);
      final themePath = p.join(paths.themesDir.path, themeId);
      if (!mounted) return;
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => NoteEditorScreen(
            themeId: themeId,
            themeTitle: themeTitle ?? themeId,
            themePath: themePath,
            notesDir: p.join(themePath, 'notes'),
            noteId: noteId,
          ),
        ),
      );
    } catch (_) {
      // 路径解析失败静默忽略，留在面板
    }
  }

  /// To Note：选一篇笔记把卡片全文追加进去。
  Future<void> _toNote() async {
    final pin = widget.pin;
    final text = _content?.body ?? pin.excerpt;
    if (text.trim().isEmpty) return;
    final themeId = pin.themeId ?? widget.currentThemeId;
    if (themeId == null) return;
    final l10n = AppLocalizations.of(context)!;
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => NoteSelectScreen(
          currentThemeId: themeId,
          selectedText: text,
          onNoteSelected: (ctx, noteId) {
            ThkToast.show(ctx, l10n.pinAddedToNoteToast);
          },
        ),
      ),
    );
  }

  /// Remove：删除后 bump 版本号，面板通过 listen 自动刷新（删空自动关闭）。
  Future<void> _remove() async {
    try {
      final storage = await ref.read(pinStorageProvider.future);
      await storage.remove(widget.pin.id);
      ref.read(pinListVersionProvider.notifier).bump();
    } catch (_) {
      // 删除失败静默忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pin = widget.pin;
    // 主题 / chat 标题：复用主题详情 controller，加载中或失败时退化为 excerpt
    final themeId = pin.themeId;
    final detail = themeId == null
        ? null
        : ref.watch(themeDetailControllerProvider(themeId)).value;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 来源行
          Row(
            children: [
              Icon(
                pin.kind == PinKind.note ? AppIcons.note : AppIcons.chat,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _sourceLine(l10n, detail),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 全文可滚动预览（锚点失效时显示 excerpt + 内容不存在）
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: _loading
                  ? const Center(child: CupertinoActivityIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 渲染 markdown（与笔记详情页一致），可长按选中
                          SelectionArea(
                            child: GptMarkdown(
                              _content?.body ?? pin.excerpt,
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.5,
                                color: AppColors.textPrimary,
                              ),
                              onLinkTap: (url, _) =>
                                  openMarkdownLink(context, url),
                            ),
                          ),
                          if (_content == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                l10n.pinContentMissing,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          // 动作行
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PinActionButton(
                icon: AppIcons.subdirectoryArrowRight,
                label: l10n.pinJump,
                color: AppColors.accent,
                onTap: () => unawaited(_jump(detail?.themeTitle)),
              ),
              _PinActionButton(
                icon: AppIcons.note,
                label: l10n.pinToNote,
                color: AppColors.accent,
                onTap: () => unawaited(_toNote()),
              ),
              _PinActionButton(
                icon: AppIcons.delete,
                label: l10n.pinRemove,
                color: AppColors.destructive,
                onTap: () => unawaited(_remove()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 卡片底部动作按钮（图标 + 文字）。
class _PinActionButton extends StatelessWidget {
  const _PinActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
