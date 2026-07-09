import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/image_cleanup_service.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 清理无用图片：进入页面即扫描，以缩略图网格展示**全部**图片，
/// 孤儿（无引用）图片可勾选删除，在用图片灰显并锁定（防误删）。
class CleanImagesScreen extends ConsumerStatefulWidget {
  const CleanImagesScreen({super.key});

  @override
  ConsumerState<CleanImagesScreen> createState() => _CleanImagesScreenState();
}

class _CleanImagesScreenState extends ConsumerState<CleanImagesScreen> {
  List<ImageEntry> _images = const [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _deleting = false;
  Object? _error;
  ScanReport? _report;
  String? _themesPath;
  bool _expanded = false;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 必须用 .future 等待 provider resolve，否则首帧读 .value 可能为 null
      // （appPathsProvider 是 FutureProvider，本页可能是首次触发它的地方）
      final paths = await ref.read(appPathsProvider.future);
      final service = ImageCleanupService(themesDir: paths.themesDir);
      final report = await service.scanAndReport();
      if (!mounted) return;
      log('[CleanImages] scan done: themesDir=${paths.themesDir.path} '
          'sessions=${report.sessionFiles} images=${report.imageFiles} '
          'orphans=${report.orphans.length}');
      setState(() {
        _images = report.images;
        _report = report;
        _themesPath = paths.themesDir.path;
      });
    } catch (e, st) {
      log('[CleanImages] scan ERROR: $e\n$st');
      if (mounted) _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int get _orphanCount => _images.where((e) => e.isOrphan).length;
  int get _totalCount => _images.length;
  bool get _allSelected =>
      _images.isNotEmpty && _selected.length == _images.length;

  /// 扫描诊断串，便于在无 Xcode Console 的情况下直接看到扫描卡在哪一步。
  String? get _diagnostics {
    final r = _report;
    if (r == null) return null;
    final status =
        r.themesExists ? l10n.cleanImagesDirExists : l10n.cleanImagesDirMissing;
    return l10n.cleanImagesDiagnostics(
      status,
      r.sessionFiles,
      r.rawImageFiles,
      r.imagesDirsHit,
      r.imagesDirsEmpty,
      r.listFailures,
    );
  }

  void _toggle(String path) {
    setState(() {
      if (_selected.contains(path)) {
        _selected.remove(path);
      } else {
        _selected.add(path);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(_images.map((e) => e.path));
      }
    });
  }

  Future<void> _delete() async {
    if (_deleting || _selected.isEmpty) return;
    final paths = await ref.read(appPathsProvider.future);

    // 删除任意选中的图片（含"使用中"），是否允许由教育栏 + 二次确认把关
    final toDelete = _images
        .where((e) => _selected.contains(e.path))
        .map((e) => ImageEntry(
              path: e.path,
              nodeId: e.nodeId,
              sizeBytes: e.sizeBytes,
              isOrphan: e.isOrphan,
            ))
        .toList();
    if (toDelete.isEmpty) return;
    final size = toDelete.fold(0, (s, e) => s + e.sizeBytes);
    final inUseCount = toDelete.where((e) => !e.isOrphan).length;

    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(inUseCount > 0 ? l10n.cleanImagesWarnTitle : l10n.cleanImagesEntry),
        content: Text(
          inUseCount > 0
              ? '${l10n.cleanImagesConfirmDelete(toDelete.length, _formatSize(size))}\n\n'
                  '${l10n.cleanImagesConfirmInUse(inUseCount)}'
              : l10n.cleanImagesConfirmDelete(toDelete.length, _formatSize(size)),
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text(l10n.cleanImagesDeleteSelected(toDelete.length)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
          CupertinoDialogAction(
            child: Text(l10n.cancel),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      final service = ImageCleanupService(themesDir: paths.themesDir);
      final freed = await service.deleteImages(toDelete);
      if (!mounted) return;
      final deletedCount = toDelete.length;
      setState(() {
        _images = _images.where((e) => !_selected.contains(e.path)).toList();
        _selected.clear();
        _deleting = false;
      });
      final logger = await ref.read(appLoggerProvider.future);
      unawaited(logger.info(
        'image_cleanup.done',
        attrs: {'count': deletedCount, 'freedBytes': freed, 'inUse': inUseCount},
      ));
      if (context.mounted) {
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(l10n.cleanImagesEntry),
            content: Text(l10n.cleanImagesDone(deletedCount, _formatSize(freed))),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: Text(l10n.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        await showCupertinoDialog<void>(
          context: context,
          builder: (ctx) => CupertinoAlertDialog(
            title: Text(l10n.error),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                child: Text(l10n.ok),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _allSelected;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.cleanImagesEntry),
        trailing: _images.isEmpty || _loading
            ? null
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _toggleAll,
                child: Text(
                  allSelected ? l10n.cleanImagesDeselectAll : l10n.cleanImagesSelectAll,
                ),
              ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(child: _body()),
            if (!_loading && _images.isNotEmpty) _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error.toString()),
        ),
      );
    }
    if (_images.isEmpty) {
      // 真·一张图都没有（多半是路径不对或真没图）
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.cleanImagesNone, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              if (_report != null)
                Text(
                  l10n.cleanImagesScanStats(_report!.sessionFiles, _report!.imageFiles),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (_diagnostics != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _diagnostics!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              if (_themesPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _themesPath!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              CupertinoButton(
                onPressed: _loading ? null : _scan,
                child: Text(l10n.rescan),
              ),
            ],
          ),
        ),
      );
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _educationalBanner()),
        SliverToBoxAdapter(child: _banner()),
        SliverPadding(
          padding: const EdgeInsets.all(8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final e = _images[i];
                final selected = _selected.contains(e.path);
                final inUse = !e.isOrphan;
                return GestureDetector(
                  onTap: () => _toggle(e.path),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(
                        File(e.path),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: AppColors.surfaceMuted,
                          child: Center(
                            child: Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                      if (selected)
                        // 选中勾：实底 accent 圆 + 白勾，靠它作选中标识（不再加遮罩，保持图片原貌）
                        Align(
                          alignment: Alignment.topRight,
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(2),
                            child: const Icon(
                              CupertinoIcons.check_mark,
                              color: CupertinoColors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      if (!selected && inUse)
                        // 在用小标：中性深底白字（不引入 app 无对应 token 的橙色），仅提示、不阻止选择
                        Align(
                          alignment: Alignment.topLeft,
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.scrim,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              l10n.cleanImagesInUse,
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
              childCount: _images.length,
            ),
          ),
        ),
      ],
    );
  }

  /// 顶部可展开的教育提醒栏：说明删除风险、未使用 vs 使用中的区别。
  /// 配色遵循 app 设计系统：中性底（surfaceMuted）+ 已有 destructive 红做警告图标，
  /// 不引入系统黄/橙等 token 之外的色相，也不满铺大面积亮色。
  Widget _educationalBanner() {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: AppColors.surfaceMuted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(CupertinoIcons.exclamationmark_triangle,
                    color: AppColors.destructive, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.cleanImagesEduSummary,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              Text(
                l10n.cleanImagesEduUnused,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.cleanImagesEduInUse,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.cleanImagesEduPermanent,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surfaceMuted,
          child: Text(
            l10n.cleanImagesStatusLine(_orphanCount, _totalCount),
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        if (_diagnostics != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              _diagnostics!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _bottomBar() {
    final count = _selected.length;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: CupertinoColors.separator),
        ),
        color: CupertinoTheme.of(context).barBackgroundColor,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(l10n.cleanImagesSummary(count, _totalCount)),
          const Spacer(),
          CupertinoButton(
            color: AppColors.destructive,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            onPressed: count == 0 || _deleting ? null : _delete,
            child: _deleting
                ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                : Text(
                    l10n.cleanImagesDeleteSelected(count),
                    style: const TextStyle(color: CupertinoColors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
