import 'dart:async';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/data/services/pin_storage.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/generate_title_screen.dart';

/// Notion 风格的笔记编辑器，标题和内容一体编辑。
///
/// 三种打开方式：
/// - `createMode`：新建（进入即落盘空笔记，供「+」流程）；
/// - `deferCreate`：延迟创建（预填 [initialTitle]/[initialBody]，✓ 才落盘，
///   返回则丢弃，供「消息存为笔记」流程）；
/// - 默认：编辑已存在的 [noteId]。
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.themeId,
    required this.themeTitle,
    required this.themePath,
    required this.notesDir,
    this.noteId,
    this.createMode = false,
    this.deferCreate = false,
    this.initialTitle,
    this.initialBody,
  });

  final String themeId;
  final String themeTitle;
  final String themePath;
  final String notesDir;
  final String? noteId;
  final bool createMode;

  /// 延迟创建：进入时不落盘，✓ 时才建笔记（见类注释）。
  final bool deferCreate;
  final String? initialTitle;
  final String? initialBody;

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final NoteStore _store;
  String? _noteId;
  Timer? _saveTimer;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _bodyController = TextEditingController();
    _store = NoteStore(notesDir: Directory(widget.notesDir));
    _noteId = widget.noteId;

    if (widget.deferCreate) {
      // 延迟创建：只预填内容，不落盘；✓ 时才建笔记（见 _onConfirm）
      _titleController.text = widget.initialTitle ?? '';
      _bodyController.text = widget.initialBody ?? '';
      _dirty = true;
    } else if (widget.createMode) {
      _createNote();
    } else {
      _loadNote();
    }
  }

  Future<void> _createNote() async {
    try {
      final meta = await _store.createNote(
        themeId: widget.themeId,
        title: '',
      );
      if (!mounted) return;
      setState(() {
        _noteId = meta.noteId;
      });
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: e.toString(),
        defaultAction: 'OK',
      );
    }
  }

  Future<void> _loadNote() async {
    if (_noteId == null) return;
    try {
      final metas = await _store.listNoteMetas();
      final meta = metas.where((m) => m.noteId == _noteId).firstOrNull;
      if (meta != null && mounted) {
        _titleController.text = meta.title;
      }

      final body = await _store.readBody(_noteId!);
      if (mounted) {
        _bodyController.text = body;
      }
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: e.toString(),
        defaultAction: 'OK',
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  /// 从正文提取前 N 个字符作为默认标题，去掉 Markdown 标记。
  String _extractDefaultTitle(String body, {int maxChars = 8}) {
    // 去掉常见的 Markdown 标记
    var cleaned = body
        .replaceAll(RegExp(r'#{1,6}\s*'), '') // 标题标记
        .replaceAll(RegExp(r'\*\*|\*|__|_|`'), '') // 粗体、斜体、代码
        .replaceAll(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), r'$1') // 链接、图片
        .replaceAll(RegExp(r'^\s*[-*+]\s*', multiLine: true), '') // 列表标记
        .replaceAll(RegExp(r'^\s*\d+[.\)、]\s*', multiLine: true), '') // 有序列表
        .replaceAll(RegExp(r'\s+'), ' ') // 合并空白
        .trim();
    if (cleaned.length <= maxChars) return cleaned;
    return cleaned.substring(0, maxChars);
  }

  Future<void> _saveNow() async {
    if (!_dirty || _noteId == null) return;
    _dirty = false;

    try {
      var title = _titleController.text.trim();
      final body = _bodyController.text;

      // 标题为空时，自动取正文前 8 个字符（去掉 Markdown 标记）
      if (title.isEmpty && body.trim().isNotEmpty) {
        title = _extractDefaultTitle(body);
        _titleController.text = title;
      }

      // 更新标题
      await _store.renameNote(noteId: _noteId!, newTitle: title);

      // 更新内容
      if (body.isNotEmpty) {
        await _store.writeBody(_noteId!, body);
      }

      // 更新笔记列表版本
      ref.read(noteListVersionProvider.notifier).bump();

      // 更新搜索索引（fire-and-forget）
      _updateSearchIndex();
    } catch (e) {
      // 保存失败，标记为脏，下次重试
      _dirty = true;
    }
  }

  /// 跳转到 GenerateTitleScreen，用 AI 生成候选标题。
  Future<void> _generateTitle() async {
    if (_noteId == null) return;

    final newTitle = await Navigator.of(context).push<String>(
      CupertinoPageRoute(
        builder: (_) => GenerateTitleScreen(
          noteId: _noteId!,
          notesDir: widget.notesDir,
          currentTitle: _titleController.text.trim(),
          body: _bodyController.text,
        ),
      ),
    );

    if (newTitle != null && mounted) {
      setState(() {
        _titleController.text = newTitle;
      });
      _scheduleSave();
    }
  }

  void _updateSearchIndex() {
    unawaited(() async {
      try {
        final searchIndex = await ref.read(searchServiceProvider.future);
        final metas = await _store.listNoteMetas();
        final meta = metas.where((m) => m.noteId == _noteId).firstOrNull;
        if (meta == null) return;

        await searchIndex.upsertNote(
          noteId: meta.noteId,
          themeId: meta.themeId,
          themeTitle: widget.themeTitle,
          noteTitle: meta.title,
          body: _bodyController.text,
        );
      } catch (e) {
        // 静默失败
      }
    }());
  }

  /// Pin / 取消 Pin 整篇笔记（上限 5 条，满员拦截不淘汰旧条目）。
  Future<void> _pinNote() async {
    // 延迟创建模式：Pin 蕴含保存（note 不存在就没法 pin），
    // Pin 后不退出页面
    if (_noteId == null && widget.deferCreate) {
      try {
        final meta =
            await _store.createNote(themeId: widget.themeId, title: '');
        if (!mounted) return;
        setState(() => _noteId = meta.noteId);
        _dirty = true;
      } catch (e) {
        if (!mounted) return;
        ThkAlert.show(
          context: context,
          message: e.toString(),
          defaultAction: 'OK',
        );
        return;
      }
    }
    if (_noteId == null) return;

    final l10n = AppLocalizations.of(context)!;

    try {
      final pinStorage = await ref.read(pinStorageProvider.future);
      // 已 Pin → 再点取消（不需要动笔记内容）
      if (await pinStorage.isPinned(kind: PinKind.note, noteId: _noteId)) {
        await pinStorage.removeByAnchor(kind: PinKind.note, noteId: _noteId);
        ref.read(pinListVersionProvider.notifier).bump();
        if (!mounted) return;
        ThkToast.show(
          context,
          l10n.unpinnedToast,
          icon: AppIcons.pinSlash,
          iconColor: AppColors.textTertiary,
        );
        return;
      }
      // 满员拦截：不淘汰旧条目，提示先移除
      if (await pinStorage.isFullFor(kind: PinKind.note, noteId: _noteId)) {
        if (!mounted) return;
        ThkToast.show(
          context,
          l10n.pinLimitToast,
          icon: AppIcons.exclamationCircle,
          iconColor: AppColors.destructive,
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: e.toString(),
        defaultAction: 'OK',
      );
      return;
    }

    // 有未落盘的改动先保存，保证 Pin 的摘要与磁盘一致
    if (_dirty) await _saveNow();

    // 摘要：优先标题，否则正文；合并空白后取前 100 字符
    final source = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : _bodyController.text;
    final excerpt = source.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (excerpt.isEmpty) return;

    try {
      final pinStorage = await ref.read(pinStorageProvider.future);
      await pinStorage.add(
        kind: PinKind.note,
        themeId: widget.themeId,
        noteId: _noteId,
        excerpt: excerpt.length <= 100 ? excerpt : excerpt.substring(0, 100),
      );
      ref.read(pinListVersionProvider.notifier).bump();
      if (!mounted) return;
      ThkToast.show(
        context,
        l10n.pinnedToast,
        icon: AppIcons.checkCircle,
      );
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        message: e.toString(),
        defaultAction: 'OK',
      );
    }
  }

  /// ✓ 确认：标题/正文都为空时拦截；延迟创建模式下此时才真正落盘；
  /// 保存后退出。
  Future<void> _onConfirm() async {
    final l10n = AppLocalizations.of(context)!;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    // 标题和正文都为空时拦截
    if (title.isEmpty && body.isEmpty) {
      ThkAlert.show(
        context: context,
        message: l10n.titleCannotBeEmpty,
        defaultAction: l10n.ok,
      );
      return;
    }

    // 延迟创建：✓ 才建笔记（直接返回退出则什么都不落盘）
    if (_noteId == null && widget.deferCreate) {
      try {
        final meta =
            await _store.createNote(themeId: widget.themeId, title: '');
        if (!mounted) return;
        _noteId = meta.noteId;
        _dirty = true;
      } catch (e) {
        if (!mounted) return;
        ThkAlert.show(
          context: context,
          message: e.toString(),
          defaultAction: 'OK',
        );
        return;
      }
    }

    await _saveNow();
    if (!mounted) return;
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // 延迟创建模式下 Pin 也可用：点击即保存并 Pin（见 _pinNote）
    final pinEnabled = _noteId != null || widget.deferCreate;
    // 已 Pin 状态：换 slash 图标 + 绿色，再点即取消
    final pinned = ref
            .watch(pinAnchorKeysProvider)
            .value
            ?.contains('n:$_noteId') ??
        false;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: ThkNavBar.inline(
        title: widget.themeTitle,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              key: const ValueKey('pin_note_button'),
              padding: EdgeInsets.zero,
              onPressed: pinEnabled ? _pinNote : null,
              child: Icon(
                pinned ? AppIcons.pinSlash : AppIcons.pin,
                size: 20,
                color: pinned
                    ? AppColors.success
                    : (pinEnabled
                        ? AppColors.accent
                        : AppColors.textTertiary),
              ),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _onConfirm,
              child: Icon(AppIcons.check),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题输入（Notion 风格：大号字体，无边框）+ AI 生成按钮
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: CupertinoTextField(
                            key: const ValueKey('note_title_input'),
                            controller: _titleController,
                            placeholder: l10n.noTitle,
                            placeholderStyle: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              border: null,
                            ),
                            maxLines: null,
                            enableInteractiveSelection: true,
                            onChanged: (_) => _scheduleSave(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CupertinoButton(
                          padding: const EdgeInsets.all(8),
                          onPressed: _noteId == null ? null : _generateTitle,
                          child: Icon(
                            AppIcons.sparkles,
                            color: _noteId == null
                                ? AppColors.textTertiary
                                : AppColors.accent,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 内容编辑区
                    CupertinoTextField(
                      key: const ValueKey('note_body_input'),
                      controller: _bodyController,
                      placeholder: l10n.startWriting,
                      placeholderStyle: TextStyle(
                        fontSize: 17,
                        color: AppColors.textTertiary,
                      ),
                      style: TextStyle(
                        fontSize: 17,
                        height: 1.6,
                        color: AppColors.textPrimary,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: null,
                      ),
                      maxLines: null,
                      minLines: 10,
                      enableInteractiveSelection: true,
                      onChanged: (_) => _scheduleSave(),
                    ),
                  ],
                ),
              ),
            ),
            // Markdown 工具栏
            MarkdownToolbar(controller: _bodyController),
          ],
        ),
      ),
    );
  }
}
