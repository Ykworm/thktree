import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/services/llm_provider.dart' show LlmProvider;
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/title_suggestion_screen.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/theme/app_theme.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/notes/node_location_picker.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({
    super.key,
    required this.notesDir,
    required this.noteId,
  });

  final String notesDir;
  final String noteId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  bool _editing = false;
  late final TextEditingController _controller;
  late final NoteStore _store;
  String _body = '';
  bool _loading = true;
  Object? _error;
  int? _lastSeenVersion;

  @override
  void initState() {
    super.initState();
    _store = NoteStore(notesDir: Directory(widget.notesDir));
    _controller = TextEditingController();
    _lastSeenVersion = ref.read(noteListVersionProvider);
    _loadBody();
  }

  Future<void> _loadBody() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = await _store.readBody(widget.noteId);
      if (!mounted) return;
      setState(() {
        _body = body;
        _controller.text = body;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleEditing() async {
    if (_editing) {
      await _store.writeBody(widget.noteId, _controller.text);
      _body = _controller.text;
      ref.read(noteListVersionProvider.notifier).bump();
      if (!mounted) return;
    }
    setState(() {
      _editing = !_editing;
    });
  }

  /// 从笔记创建一个新对话。
  ///
  /// 流程：选位置 → 弹 sheet 选 mode（raw=原文 / summarize=LLM 总结）→ 调
  /// [showBranchFlow] 完成标题选择 + 创建 chat node + 写入首条 user 消息 + 跳转。
  /// [showBranchFlow] 接受 [parentTranscript] 作为 source content；这里传 _body（笔记正文），
  /// 并用 [sourceLabelOverride] 让 title suggestion 页 banner 显为 "笔记" 而非 "对话"。
  Future<void> _createChatFromNote() async {
    if (_body.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      ThkAlert.show(
        context: context,
        message: l10n.noMessagesYet,
        defaultAction: 'OK',
      );
      return;
    }

    // 1. 选位置
    final location = await showNodeLocationPicker(context, ref);
    if (location == null) return;
    if (!mounted) return;

    // 2. 解析 provider/model（笔记默认继承全局设置）
    String? providerId;
    String? modelId;
    final settings = ref.read(settingsControllerProvider).value;
    if (settings != null) {
      providerId = _mapLegacyProviderToPresetId(settings.llmProvider);
      modelId = settings.model;
    }

    // 3. 弹 sheet 选 mode
    final mode = await showBranchModeSheet(context);
    if (mode == null) return;
    if (!mounted) return;

    // 4. 调 showBranchFlow：source = 笔记正文（_body），label = "笔记"
    await showBranchFlow(
      context: context,
      mode: mode,
      selectedText: null,
      parentTranscript: _body,
      providerId: providerId,
      modelId: modelId,
      themeId: location.themeId,
      parentNodeId: location.parentId,
      sourceLabelOverride: AppLocalizations.of(context)!.notes,
    );
  }

  /// 将旧版 LlmProvider 枚举映射到新系统的 preset provider id。
  String _mapLegacyProviderToPresetId(LlmProvider provider) {
    switch (provider) {
      case LlmProvider.claude:
        return 'preset_anthropic';
      case LlmProvider.deepseek:
        return 'preset_deepseek';
      case LlmProvider.openai:
        return 'preset_openai';
      case LlmProvider.gemini:
        return 'preset_gemini';
      case LlmProvider.minimax:
        return 'preset_minimax';
      case LlmProvider.kimi:
        return 'preset_kimi';
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(noteListVersionProvider);
    if (_lastSeenVersion != version) {
      _lastSeenVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_editing) {
          _loadBody();
        }
      });
    }
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: ThkNavBar.inline(
        title: l10n.notes,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _createChatFromNote,
              child: Icon(AppIcons.branch),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _toggleEditing,
              child: Icon(_editing ? AppIcons.check : AppIcons.edit),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_editing) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: CupertinoTextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: BoxDecoration(
              color: CupertinoColors.systemGroupedBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CupertinoColors.separator),
            ),
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error.toString(),
          style: const TextStyle(color: CupertinoColors.systemRed),
        ),
      );
    }
    if (_body.isEmpty) {
      return Center(
        child: Text(
          l10n.noMessagesYet,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: CupertinoTextField(
        controller: TextEditingController(text: _body),
        readOnly: true,
        maxLines: null,
        style: AppTheme.body,
        decoration: const BoxDecoration(), // no border
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class ThemeNoteListScreen extends ConsumerStatefulWidget {
  const ThemeNoteListScreen({
    super.key,
    required this.themeId,
    required this.notesDir,
  });

  final String themeId;
  final String notesDir;

  @override
  ConsumerState<ThemeNoteListScreen> createState() =>
      _ThemeNoteListScreenState();
}

class _ThemeNoteListScreenState extends ConsumerState<ThemeNoteListScreen> {
  late final NoteStore _store;
  List<NoteMeta>? _metas;
  bool _loading = true;
  Object? _error;
  int? _lastSeenVersion;

  @override
  void initState() {
    super.initState();
    _store = NoteStore(notesDir: Directory(widget.notesDir));
    _lastSeenVersion = ref.read(noteListVersionProvider);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final metas = await _store.listNoteMetas();
      if (!mounted) return;
      setState(() {
        _metas = metas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(noteListVersionProvider);
    if (_lastSeenVersion != version) {
      _lastSeenVersion = version;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _load();
        }
      });
    }
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      navigationBar: ThkNavBar.inline(
        title: l10n.notes,
      ),
      child: SafeArea(
        top: false,
        child: _buildBody(l10n),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          '${l10n.noNotesYet}: $_error',
          style: const TextStyle(color: CupertinoColors.systemRed),
        ),
      );
    }
    final metas = _metas ?? [];
    if (metas.isEmpty) {
      return Center(
        child: Text(
          l10n.noNotesYet,
          style: const TextStyle(color: CupertinoColors.secondaryLabel),
        ),
      );
    }
    return ListView(
      children: [
        ThkListSection(
          children: metas
              .map((meta) => ThkListTile(
                    title: meta.title,
                    subtitle: '${meta.noteId} \u00b7 ${meta.updatedAt}',
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (_) => NoteDetailScreen(
                            notesDir: widget.notesDir,
                            noteId: meta.noteId,
                          ),
                        ),
                      );
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }
}
