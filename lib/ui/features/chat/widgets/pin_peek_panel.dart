import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/services/pin_content_loader.dart';
import 'package:thk_tree/data/services/pin_storage.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/note_browse_screen.dart'
    show localizedThemeTitle;
import 'package:thk_tree/ui/features/notes/note_editor_screen.dart';
import 'package:thk_tree/ui/features/notes/note_select_screen.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';

/// 打开对照栏面板（从右侧滑入，点外侧 scrim 关闭）。
///
/// [currentThemeId] / [currentNodeId] 用于 Jump 时识别「同一 chat 就地滚动」；
/// [onJumpInPlace] 在同一 chat 时回调就地滚动，避免重复 push 当前页。
Future<void> showPinPeekPanel(
  BuildContext context, {
  String? currentThemeId,
  String? currentNodeId,
  void Function(String msgId)? onJumpInPlace,
}) {
  return Navigator.of(context).push(
    _SlideFromRightRoute(
      builder: (_) => PinPeekPanel(
        currentThemeId: currentThemeId,
        currentNodeId: currentNodeId,
        onJumpInPlace: onJumpInPlace,
      ),
    ),
  );
}

/// 从右往左滑入的半屏路由（镜像 search_screen 的 _SlideFromLeftRoute）。
class _SlideFromRightRoute extends PageRouteBuilder<void> {
  _SlideFromRightRoute({required this.builder})
      : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: AppColors.scrimMid,
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
/// 以 OverlayEntry 挂在 ChatScreen 上；自身带 [Positioned] 定位。
/// pins 为空时不显示；点击或向左拖动打开对照面板。
class PinEdgeHandle extends ConsumerStatefulWidget {
  const PinEdgeHandle({super.key, required this.onOpen});

  final VoidCallback onOpen;

  @override
  ConsumerState<PinEdgeHandle> createState() => _PinEdgeHandleState();
}

class _PinEdgeHandleState extends ConsumerState<PinEdgeHandle> {
  int _count = 0;

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

    final screenHeight = MediaQuery.of(context).size.height;
    return Positioned(
      right: 0,
      top: screenHeight / 2 - 50,
      child: GestureDetector(
        onTap: widget.onOpen,
        onHorizontalDragEnd: (details) {
          // 向左快速拖动也打开面板
          if ((details.primaryVelocity ?? 0) < -100) widget.onOpen();
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

/// 对照栏面板：右缘拉出，横向 PageView 一页一张 Pin 卡（上限 5 条）。
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
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.translucent,
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () {}, // 阻止点击面板区域关闭
          child: Container(
            width: screenWidth * 0.85,
            height: double.infinity,
            color: AppColors.pageBg,
            child: SafeArea(
              child: Column(
                children: [
                  // 标题栏
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            l10n.pinPeekTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            onPressed: () => Navigator.of(context).pop(),
                            child: Icon(
                              AppIcons.close,
                              size: 20,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 卡片 PageView
                  Expanded(
                    child: _loading
                        ? const Center(child: CupertinoActivityIndicator())
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: _pins.length,
                            onPageChanged: (i) => _currentPage = i,
                            itemBuilder: (context, index) => _PinCard(
                              key: ValueKey(_pins[index].id),
                              pin: _pins[index],
                              currentThemeId: widget.currentThemeId,
                              currentNodeId: widget.currentNodeId,
                              onJumpInPlace: widget.onJumpInPlace,
                            ),
                          ),
                  ),
                  // 页码指示（多于一张时）
                  if (!_loading && _pins.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12, top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < _pins.length; i++)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 单张 Pin 卡：来源行 + 全文可滚动预览 + Jump / To Note / Remove。
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

  /// Jump：消息 → 跳到对应 chat 并滚到该消息；笔记 → 打开笔记编辑器。
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
                          SelectableText(
                            _content?.body ?? pin.excerpt,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: AppColors.textPrimary,
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
