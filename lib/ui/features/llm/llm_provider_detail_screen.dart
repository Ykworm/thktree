import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ulid/ulid.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/model_fetcher.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';

/// 提供商详情/编辑页面
///
/// 传入 [provider] 则编辑现有提供商；不传则新建自定义提供商。
class LlmProviderDetailScreen extends ConsumerStatefulWidget {
  const LlmProviderDetailScreen({super.key, this.provider});

  final LlmProviderConfig? provider;

  @override
  ConsumerState<LlmProviderDetailScreen> createState() =>
      _LlmProviderDetailScreenState();
}

class _LlmProviderDetailScreenState
    extends ConsumerState<LlmProviderDetailScreen> {
  late final bool _isNew;
  late final bool _isCustom;

  late TextEditingController _nameController;
  late TextEditingController _baseUrlController;
  late TextEditingController _apiKeyController;

  bool _isLoadingApiKey = true;
  bool _isFetchingModels = false;
  List<LlmModelConfig> _fetchedModels = [];
  Set<String> _selectedModelIds = {};

  @override
  void initState() {
    super.initState();
    _isNew = widget.provider == null;
    _isCustom = widget.provider?.type == LlmProviderType.custom || _isNew;

    _nameController = TextEditingController(
      text: _isNew ? '' : widget.provider!.name,
    );
    _baseUrlController = TextEditingController(
      text: _isNew ? '' : widget.provider!.baseUrl,
    );
    _apiKeyController = TextEditingController();

    // 初始化已保存的模型勾选状态
    if (!_isNew) {
      _selectedModelIds = widget.provider!.models.map((m) => m.id).toSet();
      _fetchedModels = List.from(widget.provider!.models);
    }

    // 异步加载 API Key
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    if (_isNew) {
      setState(() => _isLoadingApiKey = false);
      return;
    }
    try {
      final store = ref.read(llmConfigStoreProvider);
      final apiKey = await store.readApiKey(widget.provider!.id);
      if (!mounted) return;
      _apiKeyController.text = apiKey;
      setState(() => _isLoadingApiKey = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingApiKey = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: CupertinoPageScaffold(
        navigationBar: ThkNavBar.inline(
          title: _isNew ? l10n.addCustomProvider : l10n.editProvider,
          trailing: !_isNew && _isCustom
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: _deleteProvider,
                  child: Icon(AppIcons.delete),
                )
              : null,
        ),
        child: SafeArea(
          child: _isLoadingApiKey
              ? const Center(child: CupertinoActivityIndicator())
              : ListView(
                  children: [
                    // API 配置区
                    ThkListSection(
                      header: l10n.providerBaseUrl,
                      children: [
                        // 自定义提供商：名称输入框
                        if (_isCustom)
                          ThkTextField(
                            placeholder: l10n.customProviderHint,
                            controller: _nameController,
                          ),
                        // 预置提供商：显示默认 URL（只读）+ 复制按钮
                        if (!_isCustom)
                          CupertinoListTile(
                            title: Text(l10n.providerDefaultUrl),
                            additionalInfo: Text(
                              widget.provider!.defaultBaseUrl,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            trailing: CupertinoButton(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: widget.provider!.defaultBaseUrl,
                                  ),
                                );
                              },
                              child: Icon(AppIcons.copy),
                            ),
                          ),
                      ],
                    ),

                    // Base URL + API Key 区
                    ThkListSection(
                      header: l10n.providerApiKey,
                      children: [
                        ThkTextField(
                          placeholder: l10n.baseUrlHint,
                          controller: _baseUrlController,
                        ),
                        ThkTextField(
                          placeholder: l10n.apiKeyHint,
                          controller: _apiKeyController,
                          obscureText: true,
                        ),
                      ],
                    ),

                    // 获取模型列表按钮
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: _isFetchingModels
                          ? const Center(child: CupertinoActivityIndicator())
                          : ThkButton.filled(
                              label: l10n.fetchModels,
                              icon: Icon(AppIcons.download),
                              onPressed: _fetchModels,
                            ),
                    ),

                    // 模型列表
                    if (_fetchedModels.isNotEmpty)
                      ThkListSection(
                        header: l10n.selectModel,
                        children: _fetchedModels.map((model) {
                          final selected =
                              _selectedModelIds.contains(model.id);
                          return CupertinoListTile(
                            title: Text(model.name),
                            subtitle: Text(model.id),
                            trailing: CupertinoCheckbox(
                              value: selected,
                              onChanged: null,
                            ),
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selectedModelIds.remove(model.id);
                                } else {
                                  _selectedModelIds.add(model.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                    // 自定义提供商：保存按钮
                    if (_isCustom)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: ThkButton.filled(
                          label: l10n.saveProvider,
                          onPressed: _saveProvider,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  // ─── 获取模型列表 ──────────────────────────────────────────────────

  Future<void> _fetchModels() async {
    // 收起软键盘
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context)!;
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      ThkAlert.show(
        context: context,
        title: l10n.apiKeyInvalid,
      );
      return;
    }

    setState(() {
      _isFetchingModels = true;
    });

    try {
      final fetcher = ModelFetcher();
      final type = _isNew ? LlmProviderType.custom : widget.provider!.type;
      final models = await fetcher.fetchModels(
        baseUrl: baseUrl,
        apiKey: apiKey,
        type: type,
      );

      if (!mounted) return;
      
      // Check if any models have unknown context window and prompt user
      final modelsWithUnknownContext = models.where((m) => m.contextWindow == 0).toList();
      if (modelsWithUnknownContext.isNotEmpty) {
        final updatedModels = await _promptForContextWindows(models, modelsWithUnknownContext);
        if (!mounted) return;
        setState(() {
          _fetchedModels = updatedModels;
          _selectedModelIds = _selectedModelIds
              .where((id) => updatedModels.any((m) => m.id == id))
              .toSet();
          _isFetchingModels = false;
        });
      } else {
        setState(() {
          _fetchedModels = models;
          _selectedModelIds = _selectedModelIds
              .where((id) => models.any((m) => m.id == id))
              .toSet();
          _isFetchingModels = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingModels = false);
      ThkAlert.show(
        context: context,
        title: l10n.fetchModelsFailed(e.toString()),
      );
    }
  }


  /// Prompt user to set context window for models with unknown context window
  Future<List<LlmModelConfig>> _promptForContextWindows(
    List<LlmModelConfig> allModels,
    List<LlmModelConfig> modelsWithUnknown,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    
    // Context window options from largest to smallest
    const contextWindowOptions = [
      (1000000, '1M'),
      (512000, '512K'),
      (256000, '256K'),
      (128000, '128K'),
      (64000, '64K'),
      (32000, '32K'),
      (16000, '16K'),
      (8000, '8K'),
      (4000, '4K'),
    ];

    // Show picker for each model with unknown context window
    for (var i = 0; i < modelsWithUnknown.length; i++) {
      final model = modelsWithUnknown[i];
      
      final selectedIndex = await showCupertinoModalPopup<int>(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          title: Text(l10n.contextWindowTitle(model.name)),
          message: Text(
            '${i + 1} / ${modelsWithUnknown.length}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            for (var j = 0; j < contextWindowOptions.length; j++)
              CupertinoActionSheetAction(
                onPressed: () => Navigator.of(ctx).pop(j),
                child: Text('${contextWindowOptions[j].$2} tokens'),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.cancel),
          ),
        ),
      );

      if (selectedIndex != null && mounted) {
        final contextWindow = contextWindowOptions[selectedIndex].$1;
        final updatedModel = model.copyWith(contextWindow: contextWindow);
        
        // Update the model in the list
        final index = allModels.indexWhere((m) => m.id == model.id);
        if (index != -1) {
          allModels = List.from(allModels);
          allModels[index] = updatedModel;
        }
      }
    }

    return allModels;
  }

  // ─── 保存提供商 ──────────────────────────────────────────────────

  Future<void> _saveProvider() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || baseUrl.isEmpty) {
      ThkAlert.show(
        context: context,
        title: l10n.apiKeyInvalid,
      );
      return;
    }

    final store = ref.read(llmConfigStoreProvider);
    final selectedModels = _fetchedModels
        .where((m) => _selectedModelIds.contains(m.id))
        .toList();

    try {
      if (_isNew) {
        // 新建自定义提供商
        final provider = LlmProviderConfig(
          id: 'custom_${Ulid().toString().toUpperCase()}',
          type: LlmProviderType.custom,
          name: name,
          baseUrl: baseUrl,
          defaultBaseUrl: '',
          isOpenAiCompatible: true,
          models: selectedModels,
        );
        await store.addProvider(provider);
        if (apiKey.isNotEmpty) {
          await store.saveApiKey(provider.id, apiKey);
        }
      } else {
        // 更新现有提供商
        final updated = widget.provider!.copyWith(
          name: name,
          baseUrl: baseUrl,
          models: selectedModels,
        );
        await store.updateProvider(updated);
        if (apiKey.isNotEmpty) {
          await store.saveApiKey(updated.id, apiKey);
        }
      }

      ref.invalidate(llmProvidersProvider);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      ThkAlert.show(
        context: context,
        title: l10n.saveFailed(e.toString()),
      );
    }
  }

  // ─── 预置提供商自动保存 ──────────────────────────────────────────

  Future<bool> _autoSave() async {
    if (_isNew || _isCustom) return false;

    try {
      final store = ref.read(llmConfigStoreProvider);
      final baseUrl = _baseUrlController.text.trim();
      final apiKey = _apiKeyController.text.trim();
      final selectedModels = _fetchedModels
          .where((m) => _selectedModelIds.contains(m.id))
          .toList();

      final updated = widget.provider!.copyWith(
        baseUrl: baseUrl.isEmpty ? widget.provider!.baseUrl : baseUrl,
        models: selectedModels,
      );
      await store.updateProvider(updated);
      if (apiKey.isNotEmpty) {
        await store.saveApiKey(updated.id, apiKey);
      }
      ref.invalidate(llmProvidersProvider);
      return true;
    } catch (e) {
      debugPrint('[_autoSave] 保存失败: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          ThkAlert.show(
            context: context,
            title: l10n.saveFailed(e.toString()),
          );
        }
      }
      return false;
    }
  }

  void _onPopInvoked(bool didPop, dynamic result) async {
    if (didPop) return;
    // 页面退出时自动保存预置提供商
    bool saved = false;
    if (!_isNew && !_isCustom) {
      saved = await _autoSave();
    }
    if (mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  // ─── 删除提供商 ──────────────────────────────────────────────────

  Future<void> _deleteProvider() async {
    final l10n = AppLocalizations.of(context)!;

    ThkAlert.show(
      context: context,
      title: l10n.deleteProvider,
      message: l10n.deleteProviderConfirm,
      destructiveAction: l10n.delete,
      onDestructive: () async {
        final store = ref.read(llmConfigStoreProvider);
        await store.deleteProvider(widget.provider!.id);
        ref.invalidate(llmProvidersProvider);

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      },
      cancelAction: l10n.cancel,
    );
  }
}
