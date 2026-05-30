import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ulid/ulid.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/models/llm_model_config.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/model_fetcher.dart';
import 'package:thk_tree/ui/core/app_services.dart';

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
  String? _apiKeyError;

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
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? l10n.addCustomProvider : l10n.editProvider),
          actions: [
            if (!_isNew && _isCustom)
              IconButton(
                tooltip: l10n.deleteProvider,
                icon: const Icon(Icons.delete_outline),
                onPressed: _deleteProvider,
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _isLoadingApiKey
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 自定义提供商：名称输入框
                        if (_isCustom) ...[
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: l10n.providerName,
                              hintText: l10n.customProviderHint,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // 预置提供商：显示默认 URL（只读）+ 复制按钮
                        if (!_isCustom) ...[
                          _DefaultUrlRow(
                            defaultBaseUrl: widget.provider!.defaultBaseUrl,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Base URL 输入框
                        TextField(
                          controller: _baseUrlController,
                          decoration: InputDecoration(
                            labelText: l10n.providerBaseUrl,
                            hintText: l10n.baseUrlHint,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // API Key 输入框
                        TextField(
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: l10n.providerApiKey,
                            hintText: l10n.apiKeyHint,
                            border: const OutlineInputBorder(),
                            errorText: _apiKeyError,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 获取模型列表按钮
                        FilledButton.icon(
                          onPressed:
                              _isFetchingModels ? null : _fetchModels,
                          icon: _isFetchingModels
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary,
                                  ),
                                )
                              : const Icon(Icons.download),
                          label: Text(
                            _isFetchingModels
                                ? l10n.fetchingModels
                                : l10n.fetchModels,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 模型列表
                        if (_fetchedModels.isNotEmpty) ...[
                          Text(
                            l10n.selectModel,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ..._fetchedModels.map((model) {
                            final selected =
                                _selectedModelIds.contains(model.id);
                            return CheckboxListTile(
                              value: selected,
                              title: Text(model.name),
                              subtitle: Text(model.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedModelIds.add(model.id);
                                  } else {
                                    _selectedModelIds.remove(model.id);
                                  }
                                });
                              },
                            );
                          }),
                        ],

                        // 自定义提供商：保存按钮
                        if (_isCustom) ...[
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _saveProvider,
                            child: Text(l10n.saveProvider),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ─── 获取模型列表 ──────────────────────────────────────────────────

  Future<void> _fetchModels() async {
    final l10n = AppLocalizations.of(context)!;
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (baseUrl.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.apiKeyInvalid)),
      );
      return;
    }

    setState(() {
      _isFetchingModels = true;
      _apiKeyError = null;
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
      setState(() {
        _fetchedModels = models;
        // 保留之前已选中的模型（如果仍存在）
        _selectedModelIds = _selectedModelIds
            .where((id) => models.any((m) => m.id == id))
            .toSet();
        _isFetchingModels = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fetchModelsSuccess(models.length))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFetchingModels = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.fetchModelsFailed(e.toString()))),
      );
    }
  }

  // ─── 保存提供商 ──────────────────────────────────────────────────

  Future<void> _saveProvider() async {
    final l10n = AppLocalizations.of(context)!;
    final name = _nameController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    if (name.isEmpty || baseUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.apiKeyInvalid)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.saveFailed(e.toString()))),
      );
    }
  }

  // ─── 预置提供商自动保存 ──────────────────────────────────────────

  Future<void> _autoSave() async {
    if (_isNew || _isCustom) return;

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
    } catch (e) {
      debugPrint('[_autoSave] 保存失败: $e');
    }
  }

  void _onPopInvoked(bool didPop, dynamic result) async {
    if (didPop) return;
    // 页面退出时自动保存预置提供商
    if (!_isNew && !_isCustom) {
      await _autoSave();
    }
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  // ─── 删除提供商 ──────────────────────────────────────────────────

  Future<void> _deleteProvider() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteProvider),
        content: Text(l10n.deleteProviderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final store = ref.read(llmConfigStoreProvider);
    await store.deleteProvider(widget.provider!.id);
    ref.invalidate(llmProvidersProvider);

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }
}

/// 默认 URL 行：显示文本 + 复制按钮
class _DefaultUrlRow extends StatelessWidget {
  const _DefaultUrlRow({required this.defaultBaseUrl});

  final String defaultBaseUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: l10n.providerDefaultUrl,
              border: const OutlineInputBorder(),
            ),
            child: SelectableText(
              defaultBaseUrl,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n.copyDefaultUrl,
          icon: const Icon(Icons.copy),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: defaultBaseUrl));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.copiedToClipboard)),
            );
          },
        ),
      ],
    );
  }
}
