import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';

/// Notion 风格的笔记编辑器，标题和内容一体编辑。
class NoteEditorScreen extends ConsumerStatefulWidget {
  const NoteEditorScreen({
    super.key,
    required this.themeId,
    required this.themeTitle,
    required this.themePath,
    required this.notesDir,
    this.noteId,
    this.createMode = false,
  });

  final String themeId;
  final String themeTitle;
  final String themePath;
  final String notesDir;
  final String? noteId;
  final bool createMode;

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

    if (widget.createMode) {
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
    _saveNow();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  Future<void> _saveNow() async {
    if (!_dirty || _noteId == null) return;
    _dirty = false;

    try {
      final title = _titleController.text.trim();
      final body = _bodyController.text;

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      navigationBar: ThkNavBar.inline(
        title: widget.themeTitle,
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            _saveNow();
            Navigator.of(context).pop();
          },
          child: Icon(AppIcons.check),
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
                    // 标题输入（Notion 风格：大号字体，无边框）
                    CupertinoTextField(
                      controller: _titleController,
                      placeholder: l10n.noTitle,
                      placeholderStyle: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.placeholderText,
                      ),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.label,
                      ),
                      decoration: const BoxDecoration(
                        color: CupertinoColors.white,
                        border: null,
                      ),
                      maxLines: null,
                      onChanged: (_) => _scheduleSave(),
                    ),
                    const SizedBox(height: 16),
                    // 内容编辑区
                    CupertinoTextField(
                      controller: _bodyController,
                      placeholder: l10n.startWriting,
                      placeholderStyle: const TextStyle(
                        fontSize: 17,
                        color: CupertinoColors.placeholderText,
                      ),
                      style: const TextStyle(
                        fontSize: 17,
                        height: 1.6,
                        color: CupertinoColors.label,
                      ),
                      decoration: const BoxDecoration(
                        color: CupertinoColors.white,
                        border: null,
                      ),
                      maxLines: null,
                      minLines: 10,
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
