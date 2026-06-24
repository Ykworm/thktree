import 'dart:developer' as dev;

import 'package:flutter/cupertino.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ulid/ulid.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/models/llm_error.dart';
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
  LlmError? _fetchError;

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

    // 初始化已获取的模型列表
    if (!_isNew) {
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

                    // 错误态（替换原 toast）
                    if (_fetchError != null)
                      LlmErrorCard(
                        key: const ValueKey('llm_error_card_compact'),
                        compact: true,
                        error: _fetchError!,
                        onRetry: () {
                          setState(() => _fetchError = null);
                          _fetchModels();
                        },
                        onCancel: () {
                          // 取消：清除错误态（保留页面，用户可继续编辑其他字段）
                          setState(() => _fetchError = null);
                        },
                      )
                    else
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
                          return _ExpandableModelTile(
                            model: model,
                            onContextWindowChanged: (newValue) {
                              setState(() {
                                final index = _fetchedModels.indexWhere(
                                  (m) => m.id == model.id,
                                );
                                if (index != -1) {
                                  _fetchedModels[index] = model.copyWith(
                                    contextWindow: newValue,
                                  );
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
      // 出现上下文未知的模型时不再弹窗，默认填上 1M（在 LlmModelConfig.fromJson 中处理）。
      setState(() {
        _fetchedModels = models;
        _isFetchingModels = false;
      });
    } catch (e, st) {
      if (!mounted) return;
      setState(() {
        _isFetchingModels = false;
        _fetchError = LlmError.fromException(
          e,
          st,
          logger: ref.read(appLoggerProvider).asData?.value,
          hint: 'LlmProviderDetail.fetchModels',
        );
      });
    }
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
    // 获取到的模型全部保存，不再按勾选过滤。
    final selectedModels = _fetchedModels;

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

    final provider = widget.provider;
    if (provider == null) {
      dev.log('[_autoSave] widget.provider == null, skip', name: 'LlmProviderDetailScreen');
      return false;
    }

    try {
      final store = ref.read(llmConfigStoreProvider);
      final baseUrl = _baseUrlController.text.trim();
      final apiKey = _apiKeyController.text.trim();
      // 获取到的模型全部保存，不再按勾选过滤。
      final selectedModels = _fetchedModels;

      dev.log('[_autoSave] start', name: 'LlmProviderDetailScreen');
      dev.log('  provider.id=${provider.id} type=${provider.type} name=${provider.name}', name: 'LlmProviderDetailScreen');
      dev.log('  baseUrl in="$baseUrl" kept=${baseUrl.isEmpty ? provider.baseUrl : baseUrl}', name: 'LlmProviderDetailScreen');
      dev.log('  apiKey.length=${apiKey.length} (empty=${apiKey.isEmpty})', name: 'LlmProviderDetailScreen');
      dev.log('  _fetchedModels.count=${_fetchedModels.length}', name: 'LlmProviderDetailScreen');
      dev.log('  selectedModels.count=${selectedModels.length}', name: 'LlmProviderDetailScreen');
      for (final m in selectedModels) {
        dev.log('    - model id=${m.id} name=${m.name} contextWindow=${m.contextWindow}', name: 'LlmProviderDetailScreen');
      }

      final updated = provider.copyWith(
        baseUrl: baseUrl.isEmpty ? provider.baseUrl : baseUrl,
        models: selectedModels,
      );
      dev.log('[_autoSave] before store.updateProvider', name: 'LlmProviderDetailScreen');
      await store.updateProvider(updated);
      dev.log('[_autoSave] after store.updateProvider (success)', name: 'LlmProviderDetailScreen');

      if (apiKey.isNotEmpty) {
        dev.log('[_autoSave] before store.saveApiKey', name: 'LlmProviderDetailScreen');
        await store.saveApiKey(updated.id, apiKey);
        dev.log('[_autoSave] after store.saveApiKey (success)', name: 'LlmProviderDetailScreen');
      }

      dev.log('[_autoSave] before ref.invalidate(llmProvidersProvider)', name: 'LlmProviderDetailScreen');
      ref.invalidate(llmProvidersProvider);
      dev.log('[_autoSave] DONE', name: 'LlmProviderDetailScreen');
      return true;
    } catch (e, st) {
      // 详细日志：暴露 catch 进入的根因（之前被 e.toString() 默默吞掉）
      dev.log('[_autoSave] FAILED', name: 'LlmProviderDetailScreen');
      dev.log('  error: $e', name: 'LlmProviderDetailScreen');
      dev.log('  error.runtimeType: ${e.runtimeType}', name: 'LlmProviderDetailScreen');
      dev.log('  stack: $st', name: 'LlmProviderDetailScreen');
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

// ─── 可展开模型行 ──────────────────────────────────────────────

/// 展示单个模型行：点击行可展开，展开后提供 Context Size 选择器。
///
/// Context Size 仍为可选填项。值为 0 表示未设置（与 LlmModelConfig 约定一致）。
class _ExpandableModelTile extends StatefulWidget {
  const _ExpandableModelTile({
    required this.model,
    required this.onContextWindowChanged,
  });

  final LlmModelConfig model;
  final ValueChanged<int> onContextWindowChanged;

  @override
  State<_ExpandableModelTile> createState() => _ExpandableModelTileState();
}

class _ExpandableModelTileState extends State<_ExpandableModelTile> {
  bool _isExpanded = false;

  // Context Size 可选项（从大到小）。
  static const List<(int, String)> _contextSizeOptions = [
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentValue = widget.model.contextWindow;
    final hasValue = currentValue > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 主行：点击展开
        CupertinoListTile(
          title: Text(widget.model.name),
          subtitle: Text(widget.model.id),
          additionalInfo: Text(
            hasValue ? _formatContextSize(currentValue) : l10n.contextSizeNotSet,
            style: TextStyle(
              color: hasValue ? AppColors.textSecondary : AppColors.accent,
            ),
          ),
          trailing: AnimatedRotation(
            turns: _isExpanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: CupertinoColors.systemGrey,
            ),
          ),
          onTap: () => setState(() => _isExpanded = !_isExpanded),
        ),
        // 展开区
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      l10n.contextSize,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        minimumSize: Size.zero,
                        onPressed: () => _showContextSizePicker(l10n),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            hasValue
                                ? _formatContextSize(currentValue)
                                : l10n.contextSizeNotSet,
                            style: TextStyle(
                              color: hasValue
                                  ? AppColors.textPrimary
                                  : AppColors.accent,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.contextSizeDescription,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          crossFadeState:
              _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        // 分隔线
        Container(
          height: 1,
          color: AppColors.border,
          margin: const EdgeInsets.only(left: 16),
        ),
      ],
    );
  }

  String _formatContextSize(int value) {
    for (final option in _contextSizeOptions) {
      if (option.$1 == value) return option.$2;
    }
    // 不在预设选项中时按 K 展示原始值
    if (value >= 1000 && value % 1000 == 0) return '${value ~/ 1000}K';
    return '$value';
  }

  void _showContextSizePicker(AppLocalizations l10n) {
    final currentIndex = _contextSizeOptions.indexWhere(
      (o) => o.$1 == widget.model.contextWindow,
    );

    int pendingIndex = currentIndex >= 0 ? currentIndex : 0;
    int? confirmedIndex;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) {
        return Container(
          height: 280,
          color: CupertinoTheme.of(ctx).scaffoldBackgroundColor,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // 工具栏
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(l10n.cancel),
                      ),
                      const Spacer(),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        onPressed: () {
                          confirmedIndex = pendingIndex;
                          Navigator.of(ctx).pop();
                        },
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                ),
                // Picker
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 44,
                    scrollController: FixedExtentScrollController(
                      initialItem: pendingIndex,
                    ),
                    onSelectedItemChanged: (index) {
                      pendingIndex = index;
                    },
                    children: _contextSizeOptions.map((option) {
                      return Center(
                        child: Text(
                          '${option.$2} tokens',
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (confirmedIndex != null) {
        widget.onContextWindowChanged(_contextSizeOptions[confirmedIndex!].$1);
      }
    });
  }
}
