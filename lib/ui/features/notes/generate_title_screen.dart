import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/title_suggestion_service.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/shared/llm_setup_check.dart'
    show resolveModelForTitleCore;
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/features/settings/default_model_picker_screen.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// 笔记标题生成页面。
///
/// 路径：NoteDetailScreen 更多菜单 → 生成标题 → 本页面。
/// 进入后自动调 LLM 生成备选标题列表，用户点选或输入自定义标题后确认/取消。
class GenerateTitleScreen extends ConsumerStatefulWidget {
  const GenerateTitleScreen({
    super.key,
    required this.noteId,
    required this.notesDir,
    required this.currentTitle,
    required this.body,
  });

  final String noteId;
  final String notesDir;
  final String currentTitle;
  final String body;

  @override
  ConsumerState<GenerateTitleScreen> createState() =>
      _GenerateTitleScreenState();
}

class _GenerateTitleScreenState extends ConsumerState<GenerateTitleScreen> {
  bool _loading = true;
  String? _error;
  List<String> _candidates = [];
  String? _selectedTitle;
  late final TextEditingController _customController;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController();
    _generate();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final settings = ref.read(settingsControllerProvider).value;
    final providers =
        ref.read(llmProvidersProvider).value ?? const <LlmProviderConfig>[];
    final configStore = ref.read(llmConfigStoreProvider);

    final resolved = await resolveModelForTitleCore(
      settings: settings,
      providers: providers,
      configStore: configStore,
      currentProviderId: settings?.chatDefaultProviderId,
      currentModelId: settings?.chatDefaultModelId,
    );

    if (resolved == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'noModel';
      });
      return;
    }
    final (provider, modelId, apiKey) = resolved;

    try {
      final candidates = await TitleSuggestionService.generateTitles(
        content: '${widget.currentTitle}\n\n${widget.body}',
        provider: provider,
        modelId: modelId,
        apiKey: apiKey,
        contextWindow: 32000,
      );
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _selectedTitle = candidates.isNotEmpty ? candidates.first : null;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'apiError:$e';
        _loading = false;
      });
    }
  }

  String? get _effectiveTitle {
    final custom = _customController.text.trim();
    if (custom.isNotEmpty) return custom;
    return _selectedTitle;
  }

  Future<void> _confirm() async {
    final title = _effectiveTitle;
    if (title == null || title.isEmpty) return;

    final store = NoteStore(notesDir: Directory(widget.notesDir));
    await store.renameNote(noteId: widget.noteId, newTitle: title);
    if (!mounted) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: ThkNavBar.inline(
        title: l10n.generateTitle,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Icon(AppIcons.close),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _effectiveTitle != null ? _confirm : null,
          child: Icon(
            AppIcons.check,
            color: _effectiveTitle != null
                ? AppColors.accent
                : AppColors.textTertiary,
          ),
        ),
      ),
      child: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.sparkles, size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                _error == 'noModel'
                    ? l10n.pleaseConfigureTitleModel
                    : (_error?.startsWith('apiError:') ?? false)
                        ? (_error!.substring(9))
                        : 'Failed to generate titles',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (_error == 'noModel')
                CupertinoButton.filled(
                  onPressed: () async {
                    final settings = ref.read(settingsControllerProvider).value;
                    final result = await Navigator.of(context).push<bool>(
                      CupertinoPageRoute(
                        builder: (_) => DefaultModelPickerScreen(
                          title: l10n.titleModelTitle,
                          currentProviderId: settings?.titleModelProviderId,
                          currentModelId: settings?.titleModelModelId,
                          onSelected: (providerId, modelId) async {
                            await ref
                                .read(settingsControllerProvider.notifier)
                                .saveTitleModel(
                                  providerId: providerId,
                                  modelId: modelId,
                                );
                          },
                        ),
                      ),
                    );
                    // 从模型选择页返回后，如果用户已配置，重新尝试生成
                    if (result == true && mounted) {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _generate();
                    }
                  },
                  child: Text(l10n.titleModelTitle),
                )
              else
                CupertinoButton.filled(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _generate();
                  },
                  child: Text(l10n.retry),
                ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          // 自定义标题输入
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: CupertinoTextField(
              controller: _customController,
              placeholder: l10n.titleHint,
              placeholderStyle: TextStyle(
                fontSize: 17,
                color: AppColors.textTertiary,
              ),
              style: TextStyle(
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // 备选标题列表
          if (_candidates.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.generatingTitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _candidates.length,
                itemBuilder: (context, index) {
                  final candidate = _candidates[index];
                  final isSelected = _selectedTitle == candidate &&
                      _customController.text.trim().isEmpty;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTitle = candidate;
                        _customController.clear();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentLight
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        candidate,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected
                              ? AppColors.accent
                              : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            const Spacer(),
            Text(
              l10n.noMessagesYet,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const Spacer(),
          ],
        ],
      ),
    );
  }
}
