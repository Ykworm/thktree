import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/services/llm_provider.dart' show LlmProvider;
import 'package:thk_tree/data/services/title_suggestion_service.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/widgets/widgets.dart';
import 'package:thk_tree/ui/features/chat/widgets/model_selector_panel.dart';
import 'package:thk_tree/ui/features/chat/chat_screen_launch_params.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';

/// Title suggestion 屏的入参。
class TitleSuggestionRequest {
  TitleSuggestionRequest({
    required this.sourceLabel,
    required this.sourceContent,
    this.currentProviderId,
    this.currentModelId,
  });

  /// 显示在 banner 上的 source 标签：'选中文本' / '对话总结' / '对话' / '笔记'。
  final String sourceLabel;

  /// 用于生成候选标题的原始内容（选中文本 / LLM 总结 / 笔记正文）。
  final String sourceContent;

  /// 首选 provider id；为 null 时回退到全局设置。
  final String? currentProviderId;

  /// 首选 model id；为 null 时回退到全局设置。
  final String? currentModelId;
}

/// 分支创建的两种模式（mode）。
///
/// 用户在 sheet 中二选一，sheet 提交后此值传入 [showBranchFlow]。
///
/// - [BranchMode.summarize]：调 LLM 总结 source content（耗时长但首条消息是摘要）。
/// - [BranchMode.raw]：直接用 source content 原始文本作为首条 user 消息（无需调 LLM）。
enum BranchMode {
  summarize,
  raw,
}

/// 全屏 Cupertino 页面：让用户从 LLM 候选 / 手动输入选择新分支的 title。
class TitleSuggestionScreen extends ConsumerStatefulWidget {
  const TitleSuggestionScreen({super.key, required this.request});

  final TitleSuggestionRequest request;

  @override
  ConsumerState<TitleSuggestionScreen> createState() =>
      _TitleSuggestionScreenState();
}

class _TitleSuggestionScreenState extends ConsumerState<TitleSuggestionScreen> {
  late final TextEditingController _titleCtrl;
  final FocusNode _focusNode = FocusNode();

  bool _generating = false;
  List<String> _candidates = const <String>[];
  String? _error;
  ({String providerId, String modelId})? _currentModel;
  CancelToken? _cancelToken;
  bool _userEditedTitle = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _titleCtrl.addListener(_onTitleChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resolveAndGenerate();
    });
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onTitleChanged);
    _titleCtrl.dispose();
    _focusNode.dispose();
    _cancelToken?.cancel('disposed');
    super.dispose();
  }

  void _onTitleChanged() {
    if (_titleCtrl.text.isNotEmpty) {
      _userEditedTitle = true;
    }
    if (mounted) {
      // 触发 rebuild 以更新「确定」按钮的 enabled 状态
      setState(() {});
    }
  }

  // ---------- 解析 provider / model ----------

  Future<void> _resolveAndGenerate() async {
    if (mounted) {
      setState(() {
        _generating = true;
        _error = null;
      });
    }
    try {
      final providers = await ref.read(llmProvidersProvider.future);
      final resolved = await _resolveModel(providers);
      if (!mounted) return;
      if (resolved == null) {
        setState(() {
          _generating = false;
          _error = 'No available model';
        });
        return;
      }
      final (provider, modelId, apiKey) = resolved;
      _currentModel = (providerId: provider.id, modelId: modelId);
      await _runGenerate(
        provider: provider,
        modelId: modelId,
        apiKey: apiKey,
        direction: null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.toString();
      });
    }
  }

  Future<(LlmProviderConfig, String, String)?> _resolveModel(
    List<LlmProviderConfig> providers,
  ) async {
    String? providerId = widget.request.currentProviderId;
    String? modelId = widget.request.currentModelId;

    if (providerId == null || modelId == null) {
      final settings = ref.read(settingsControllerProvider).value;
      if (settings != null) {
        providerId ??= _mapLegacyProviderToPresetId(settings.llmProvider);
        modelId ??= settings.model;
      }
    }

    LlmProviderConfig? provider;
    if (providerId != null) {
      for (final p in providers) {
        if (p.id == providerId) {
          provider = p;
          break;
        }
      }
    }

    final configStore = ref.read(llmConfigStoreProvider);
    if (provider == null) {
      for (final p in providers) {
        final apiKey = await configStore.readApiKey(p.id);
        if (apiKey.isNotEmpty) {
          provider = p;
          providerId = p.id;
          break;
        }
      }
    }

    if (provider == null) return null;

    String? effectiveModelId = modelId;
    if (effectiveModelId == null ||
        !provider.models.any((m) => m.id == effectiveModelId)) {
      effectiveModelId = provider.selectedModelId;
      if (effectiveModelId == null && provider.models.isNotEmpty) {
        effectiveModelId = provider.models.first.id;
      }
    }
    if (effectiveModelId == null) return null;

    final apiKey = await configStore.readApiKey(provider.id);
    if (apiKey.isEmpty) return null;

    return (provider, effectiveModelId, apiKey);
  }

  String _mapLegacyProviderToPresetId(LlmProvider provider) {
    return switch (provider) {
      LlmProvider.claude => 'preset_anthropic',
      LlmProvider.deepseek => 'preset_deepseek',
      LlmProvider.openai => 'preset_openai',
      LlmProvider.gemini => 'preset_gemini',
      LlmProvider.minimax => 'preset_minimax',
      LlmProvider.kimi => 'preset_kimi',
    };
  }

  // ---------- LLM 调用 ----------

  Future<void> _runGenerate({
    required LlmProviderConfig provider,
    required String modelId,
    required String apiKey,
    String? direction,
  }) async {
    _cancelToken?.cancel('superseded');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    if (mounted) {
      setState(() {
        _generating = true;
        _error = null;
      });
    }
    try {
      final candidates = await TitleSuggestionService.generateTitles(
        content: widget.request.sourceContent,
        direction: direction,
        provider: provider,
        modelId: modelId,
        apiKey: apiKey,
        cancelToken: cancelToken,
      );
      if (cancelToken.isCancelled || !mounted) return;
      setState(() {
        _candidates = candidates;
      });
      if (!_userEditedTitle && candidates.isNotEmpty) {
        _titleCtrl.text = candidates.first;
        _titleCtrl.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _titleCtrl.text.length,
        );
      }
    } catch (e) {
      if (cancelToken.isCancelled || !mounted) return;
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _generating = false;
        });
      }
    }
  }

  // ---------- 用户交互 ----------

  void _onCandidateTap(String title) {
    _titleCtrl.text = title;
    _titleCtrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: title.length,
    );
    _userEditedTitle = true;
    setState(() {});
    _focusNode.requestFocus();
  }

  Future<void> _onRegenerate() async {
    if (_generating) return;
    final cm = _currentModel;
    if (cm == null) {
      await _resolveAndGenerate();
      return;
    }
    final providers = await ref.read(llmProvidersProvider.future);
    LlmProviderConfig? provider;
    for (final p in providers) {
      if (p.id == cm.providerId) {
        provider = p;
        break;
      }
    }
    if (provider == null) return;
    final configStore = ref.read(llmConfigStoreProvider);
    final apiKey = await configStore.readApiKey(provider.id);
    if (apiKey.isEmpty) return;
    await _runGenerate(
      provider: provider,
      modelId: cm.modelId,
      apiKey: apiKey,
      direction: null,
    );
  }

  void _onSwitchModel() {
    if (_generating) return;
    final cm = _currentModel;
    final currentProviderId = cm?.providerId ?? widget.request.currentProviderId;
    final currentModelId = cm?.modelId ?? widget.request.currentModelId;

    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.5,
        color: CupertinoTheme.of(ctx).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: ModelSelectorPanel(
            currentProviderId: currentProviderId,
            currentModelId: currentModelId,
            onModelSelected: (providerId, modelId) async {
              Navigator.of(ctx).pop();
              final providers = await ref.read(llmProvidersProvider.future);
              LlmProviderConfig? provider;
              for (final p in providers) {
                if (p.id == providerId) {
                  provider = p;
                  break;
                }
              }
              if (provider == null) return;
              final configStore = ref.read(llmConfigStoreProvider);
              final apiKey = await configStore.readApiKey(provider.id);
              if (apiKey.isEmpty) return;
              _currentModel = (providerId: providerId, modelId: modelId);
              await _runGenerate(
                provider: provider,
                modelId: modelId,
                apiKey: apiKey,
                direction: null,
              );
            },
            onClose: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }

  void _onConfirm() {
    final value = _titleCtrl.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titleValid = _titleCtrl.text.trim().isNotEmpty;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: ThkNavBar.inline(
        title: '',
        middle: Text(l10n.chooseTitle),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: titleValid ? _onConfirm : null,
          child: Text(
            l10n.titleConfirm,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: titleValid
                  ? CupertinoColors.systemBlue.resolveFrom(context)
                  : CupertinoColors.systemGrey,
            ),
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                l10n.titleSourceBanner(widget.request.sourceLabel),
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
            // Title 输入框（顶部，autofocus；候选生成后可被填入/重选）
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ThkTextField(
                controller: _titleCtrl,
                focusNode: _focusNode,
                placeholder: l10n.titleHint,
                maxLength: 30,
                autofocus: true,
              ),
            ),
            // 候选列表区（iOS 下拉刷新重新生成）
            Expanded(
              child: _buildCandidateScrollView(l10n),
            ),
            // 错误条
            if (_error != null) _buildErrorBar(l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateScrollView(AppLocalizations l10n) {
    // 三种状态（loading / empty / candidates）统一包在 CustomScrollView 里，
    // 顶部接 CupertinoSliverRefreshControl 实现 iOS 原生下拉刷新。
    // 关键点：AlwaysScrollableScrollPhysics 让空状态也能下拉；
    // SliverFillRemaining(hasScrollBody: false) 让居中内容不被异常拉伸。
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: _onRegenerate,
        ),
        if (_generating && _candidates.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CupertinoActivityIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    l10n.titleGenerating,
                    style: TextStyle(
                      color: CupertinoColors.secondaryLabel
                          .resolveFrom(context),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_candidates.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  l10n.titleCandidatesEmpty,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel
                        .resolveFrom(context),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final title = _candidates[index];
                  return ThkListTile(
                    title: title,
                    trailing: const SizedBox.shrink(),
                    onTap: () => _onCandidateTap(title),
                  );
                },
                childCount: _candidates.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorBar(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      color: CupertinoColors.systemRed.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_triangle,
            size: 16,
            color: CupertinoColors.systemRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${l10n.titleAutoGenFailed}: $_error',
              style: const TextStyle(
                color: CupertinoColors.systemRed,
                fontSize: 12,
              ),
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: _onSwitchModel,
            child: Text(
              l10n.titleModelSwitch,
              style: TextStyle(
                color: CupertinoColors.systemBlue.resolveFrom(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 顶层函数：被 chat_screen / theme_detail_screen 复用
// ============================================================

/// 弹出 TitleSuggestionScreen，返回用户最终选择的 title。
/// 用户取消或返回时返回 null。
Future<String?> showTitleSuggestion(
  BuildContext context, {
  required String sourceLabel,
  required String sourceContent,
  String? currentProviderId,
  String? currentModelId,
}) {
  return Navigator.of(context, rootNavigator: true).push<String>(
    CupertinoPageRoute<String>(
      builder: (_) => TitleSuggestionScreen(
        request: TitleSuggestionRequest(
          sourceLabel: sourceLabel,
          sourceContent: sourceContent,
          currentProviderId: currentProviderId,
          currentModelId: currentModelId,
        ),
      ),
      fullscreenDialog: true,
    ),
  );
}

/// 弹 sheet 让用户选 [BranchMode]。
///
/// 用户在 form-style sheet 中 tap 一个 mode 后才能点"继续"
/// （[AppLocalizations.branchModeContinue] 初始 disabled）。用户 cancel / dismiss
/// 时返回 null。
///
/// 被 chat_screen / note_detail / theme_detail 复用。
Future<BranchMode?> showBranchModeSheet(BuildContext context) {
  BranchMode? selected;
  return showCupertinoModalPopup<BranchMode>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          final l10n = AppLocalizations.of(ctx)!;
          // 显式给 sheet 套不透明背景 + 顶圆角，
          // 避免 showCupertinoModalPopup 默认半透明 surface 透出下层对话。
          // 背景色跟随 CupertinoApp 主题（light/dark 自适应）。
          return Container(
            decoration: BoxDecoration(
              color: CupertinoTheme.of(ctx).scaffoldBackgroundColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      l10n.branchModeSheetTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _BranchModeOption(
                    label: l10n.branchModeSummarize,
                    selected: selected == BranchMode.summarize,
                    onTap: () => setState(
                      () => selected = BranchMode.summarize,
                    ),
                  ),
                  _BranchModeOption(
                    label: l10n.branchModeRaw,
                    selected: selected == BranchMode.raw,
                    onTap: () => setState(
                      () => selected = BranchMode.raw,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: CupertinoButton(
                            color: CupertinoColors.systemGrey5,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(
                              l10n.cancel,
                              style: TextStyle(
                                color: CupertinoColors.label.resolveFrom(ctx),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CupertinoButton.filled(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            onPressed: selected == null
                                ? null
                                : () => Navigator.of(ctx).pop(selected),
                            child: Text(l10n.branchModeContinue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Sheet 中的 mode 选项（单选样式）。
class _BranchModeOption extends StatelessWidget {
  const _BranchModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: selected
                  ? CupertinoColors.systemBlue
                  : CupertinoColors.systemGrey3,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分支创建的统一入口（被 chat_screen 右上角按钮 / theme_detail_screen 节点按钮 /
/// 选中文字菜单项 / 笔记创建对话 共同调用）。
///
/// 流程：
/// 1. 决定 source content + label：
///    - [selectedText] 非空：source = selectedText，label = "选中文本"，忽略 [mode]。
///    - 否则按 [mode] 决定：
///      - [BranchMode.summarize]：调 LLM 总结 [parentTranscript]；成功 → summary + "对话总结"；
///        失败 → 用户 cancel → 退到 [parentTranscript] + "对话"；其他错误 → 报 alert 退到 fallback。
///      - [BranchMode.raw]：直接用 [parentTranscript] 原始 transcript + "对话"。
///    - 若传了 [sourceLabelOverride]，用其覆盖默认 label（用于"笔记创建对话"场景）。
/// 2. 弹 [showTitleSuggestion] 让用户选 / 输入 title。
/// 3. 直接创建 child chat node（parent=parentNodeId），把 sourceContent 写为
///    首条 user 消息，再写 provider/model 元数据，最后
///    push `/themes/{themeId}/nodes/{childNodeId}` (autoTriggerReply=true)。
///
/// [parentNodeId] 可空：null = 把新 node 创建为 theme root（与 [nodeStore.createChatNode]
/// 行为一致）。被 note→chat 创建流程使用（note 选了 theme root 时 parentId 为 null）。
///
/// 任意步骤用户取消 / 出错都返回 null。
Future<String?> showBranchFlow({
  required BuildContext context,
  required BranchMode mode,
  required String? selectedText,
  required String parentTranscript,
  required String? providerId,
  required String? modelId,
  required String themeId,
  required String? parentNodeId,
  String? sourceLabelOverride,
}) async {
  final l10n = AppLocalizations.of(context)!;

  // 1. 决定 source content + label
  String sourceContent;
  String sourceLabel;

  if (selectedText != null && selectedText.isNotEmpty) {
    sourceContent = selectedText;
    sourceLabel = sourceLabelOverride ?? l10n.titleSourceSelection;
    debugPrint('[showBranchFlow] using selectedText: ${sourceContent.length} chars');
  } else if (mode == BranchMode.raw) {
    // raw 模式：不调 LLM，直接用原始 transcript。
    sourceContent = parentTranscript;
    sourceLabel = sourceLabelOverride ?? l10n.titleSourceConversation;
  } else {
    // summarize 模式：先解析 provider / model 再调 LLM 总结。
    if (!context.mounted) return null;
    final container = ProviderScope.containerOf(context, listen: false);
    final providers = await container.read(llmProvidersProvider.future);
    final resolved = await _resolveModelForSummary(
      container,
      providers,
      currentProviderId: providerId,
      currentModelId: modelId,
    );
    if (!context.mounted) return null;
    if (resolved == null) {
      ThkAlert.show(context: context, message: l10n.pleaseFetchModels);
      return null;
    }
    final (prov, mId, apiKey) = resolved;

    // 调 LLM 总结（带 lifecycle 监听 + 错误重试 + 弹 retry/cancel sheet）
    final summary = await _summarizeWithLifecycleAndRetry(
      context: context,
      provider: prov,
      modelId: mId,
      apiKey: apiKey,
      transcript: parentTranscript,
    );

    if (!context.mounted) return null;
    if (summary != null && summary.isNotEmpty) {
      sourceContent = summary;
      sourceLabel =
          sourceLabelOverride ?? l10n.titleSourceConversationSummary;
    } else {
      // 总结失败 / 用户取消：fallback 到原始 transcript。
      sourceContent = parentTranscript;
      sourceLabel = sourceLabelOverride ?? l10n.titleSourceConversation;
    }
  }

  // 2. title suggestion
  if (!context.mounted) return null;
  final title = await showTitleSuggestion(
    context,
    sourceLabel: sourceLabel,
    sourceContent: sourceContent,
    currentProviderId: providerId,
    currentModelId: modelId,
  );
  if (title == null) return null;

  // 3. create child chat node + write initial message + push chat_screen
  if (!context.mounted) return null;
  try {
    final container = ProviderScope.containerOf(context, listen: false);
    final nodeStore = await container.read(nodeStoreProvider.future);
    final sessionStore = await container.read(sessionStoreProvider.future);
    final themeRow = await nodeStore.getThemeRow(themeId: themeId);
    final themePath = themeRow['themePath']! as String;
    final childNode = await nodeStore.createChatNode(
      themeId: themeId,
      themePath: themePath,
      parentId: parentNodeId,
      title: title,
    );
    await sessionStore.appendUserMessage(
      nodeId: childNode.nodeId,
      content: sourceContent,
    );
    if (providerId != null && modelId != null) {
      await sessionStore.updateSessionModel(
        nodeId: childNode.nodeId,
        providerId: providerId,
        modelId: modelId,
      );
    }
    if (!context.mounted) return null;
    // 创建后立即 reload 主题树，让用户从新分支返回时无需手动 refresh。
    // showBranchFlow 直接调了 nodeStore / sessionStore，没有走 controller，
    // 所以 themeDetailControllerProvider 不会自动刷新 — 必须显式通知。
    // 走 controller 路径：controller.refresh() 会重新 _load() 并把
    // state 设为最新 AsyncData。fire-and-forget：避免阻塞主流程
    // （创建 + push），即便 reload 失败也不影响主流程。路由栈中被新
    // chat_screen 覆盖的 themeDetailScreen 视觉上看不到中间的
    // AsyncLoading；任何入口（chat / note / theme）创建都受益。
    unawaited(
      container
          .read(themeDetailControllerProvider(themeId).notifier)
          .refresh()
          .catchError((_) {}),
    );
    context.push(
      '/themes/$themeId/nodes/${childNode.nodeId}',
      extra: ChatScreenLaunchParams(
        title: title,
        autoTriggerReply: true,
      ),
    );
    return title;
  } catch (e) {
    if (!context.mounted) return null;
    ThkAlert.show(
      context: context,
      message: l10n.branchFailed(e.toString()),
    );
    return null;
  }
}

// ============================================================
// 内部辅助函数
// ============================================================

/// 跑一个异步 action，期间显示 Cupertino loading dialog（不可关闭）。
///
/// 返回 `({T? result, Object? error})`：
/// - action 正常完成 → `result = action()` 返回值，`error = null`。
/// - action 抛错 → `result = null`，`error = 抛出的对象`（供调用方分类）。
///   完成后自动 pop dialog。
Future<({T? result, Object? error})> _runWithLoadingAndError<T>({
  required BuildContext context,
  required String message,
  required Future<T> Function() action,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: CupertinoAlertDialog(
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CupertinoActivityIndicator(),
                const SizedBox(height: 12),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {}).catchError((_) {}),
  );
  try {
    final result = await action();
    return (result: result, error: null);
  } catch (e) {
    return (result: null, error: e);
  } finally {
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}

/// 调 LLM 总结 [transcript]，包装以下能力：
/// 1. lifecycle 监听：app 进入 paused/inactive/hidden → 取消当前请求，让 streaming 提早结束。
/// 2. 错误分类：识别 [DioException]（网络/超时）以便决定是否重试。
/// 3. 重试策略：第一次失败 → 静默重试 1 次；仍失败 → 弹 [RetryCancelSheet] 让用户选
///    retry / cancel；retry 后再失败 → 返回 null（调用方 fallback 到原始 transcript）。
/// 4. 用户选 cancel → 返回 null（调用方 fallback）。
Future<String?> _summarizeWithLifecycleAndRetry({
  required BuildContext context,
  required LlmProviderConfig provider,
  required String modelId,
  required String apiKey,
  required String transcript,
}) async {
  final l10n = AppLocalizations.of(context)!;

  Future<({String? result, Object? error})> attempt() async {
    final cancelToken = CancelToken();
    final listener = AppLifecycleListener(
      onPause: () {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('lifecycle-paused');
        }
      },
      onInactive: () {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('lifecycle-paused');
        }
      },
      onHide: () {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('lifecycle-paused');
        }
      },
    );
    try {
      return await _runWithLoadingAndError<String>(
        context: context,
        message: l10n.summarizing,
        action: () => TitleSuggestionService.summarizeContent(
          transcript: transcript,
          provider: provider,
          modelId: modelId,
          apiKey: apiKey,
          cancelToken: cancelToken,
        ),
      );
    } finally {
      listener.dispose();
    }
  }

  // 1st 尝试
  final attempt1 = await attempt();
  var result = attempt1.result;
  var error = attempt1.error;
  if (result != null && result.isNotEmpty) return result;

  // 静默重试 1 次（常见于 lifecycle 刚取消 → 重新发包）
  final attempt2 = await attempt();
  result = attempt2.result;
  error = attempt2.error;
  if (result != null && result.isNotEmpty) return result;

  // 两次都失败：如果是网络错误则弹 retry/cancel sheet；否则直接 fallback。
  if (!context.mounted) return null;
  if (!_isNetworkError(error)) {
    // 非网络错误（API 鉴权 / 业务错 / 未知错）→ 告诉用户
    ThkAlert.show(
      context: context,
      message: l10n.summarizeFailedFallback,
    );
    return null;
  }

  final choice = await _showRetryCancelSheet(context);
  if (choice != _RetryChoice.retry) return null;
  if (!context.mounted) return null;

  // 手动 retry 最后一次
  final attempt3 = await attempt();
  result = attempt3.result;
  error = attempt3.error;
  if (result != null && result.isNotEmpty) return result;
  if (!context.mounted) return null;
  ThkAlert.show(
    context: context,
    message: l10n.summarizeFailedFallback,
  );
  return null;
}

/// 判断 [error] 是否为可重试的网络 / 超时错误。
bool _isNetworkError(Object? error) {
  if (error is! DioException) return false;
  return switch (error.type) {
    DioExceptionType.connectionError ||
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.badResponse =>
      true,
    DioExceptionType.cancel ||
    DioExceptionType.badCertificate ||
    DioExceptionType.unknown =>
      false,
  };
}

/// CupertinoActionSheet 选项：retry 重试 / cancel 取消重试。
enum _RetryChoice { retry, cancel }

/// 弹出 Cupertino action sheet 让用户选 retry / cancel。
/// 返回 null 表示用户点击了取消按钮或点空白处 dismiss。
Future<_RetryChoice?> _showRetryCancelSheet(BuildContext context) {
  return showCupertinoModalPopup<_RetryChoice>(
    context: context,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      return CupertinoActionSheet(
        title: Text(l10n.networkInterrupted),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(ctx).pop(_RetryChoice.retry),
            child: Text(l10n.branchRetry),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(ctx).pop(_RetryChoice.cancel),
            child: Text(l10n.branchCancelRetry),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.cancel),
        ),
      );
    },
  );
}

/// 解析 (provider, modelId, apiKey) 用于 LLM 总结。
///
/// 优先级：currentProviderId / currentModelId → settings fallback → 第一个有 key 的 provider。
Future<(LlmProviderConfig, String, String)?> _resolveModelForSummary(
  ProviderContainer container,
  List<LlmProviderConfig> providers, {
  String? currentProviderId,
  String? currentModelId,
}) async {
  String? providerId = currentProviderId;
  String? modelId = currentModelId;

  if (providerId == null || modelId == null) {
    final settings = container.read(settingsControllerProvider).value;
    if (settings != null) {
      providerId ??= _mapLegacyProviderToPresetIdStatic(settings.llmProvider);
      modelId ??= settings.model;
    }
  }

  LlmProviderConfig? provider;
  if (providerId != null) {
    for (final p in providers) {
      if (p.id == providerId) {
        provider = p;
        break;
      }
    }
  }

  final configStore = container.read(llmConfigStoreProvider);
  if (provider == null) {
    for (final p in providers) {
      final apiKey = await configStore.readApiKey(p.id);
      if (apiKey.isNotEmpty) {
        provider = p;
        providerId = p.id;
        break;
      }
    }
  }

  if (provider == null) return null;

  String? effectiveModelId = modelId;
  if (effectiveModelId == null ||
      !provider.models.any((m) => m.id == effectiveModelId)) {
    effectiveModelId = provider.selectedModelId;
    if (effectiveModelId == null && provider.models.isNotEmpty) {
      effectiveModelId = provider.models.first.id;
    }
  }
  if (effectiveModelId == null) return null;

  final apiKey = await configStore.readApiKey(provider.id);
  if (apiKey.isEmpty) return null;

  return (provider, effectiveModelId, apiKey);
}

String _mapLegacyProviderToPresetIdStatic(LlmProvider provider) {
  return switch (provider) {
    LlmProvider.claude => 'preset_anthropic',
    LlmProvider.deepseek => 'preset_deepseek',
    LlmProvider.openai => 'preset_openai',
    LlmProvider.gemini => 'preset_gemini',
    LlmProvider.minimax => 'preset_minimax',
    LlmProvider.kimi => 'preset_kimi',
  };
}
