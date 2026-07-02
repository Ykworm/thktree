import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:thk_tree/data/services/keyword_global_storage.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// Settings — 关键词 score prompt 编辑页（Task 11）。
///
/// UI 设计（§ 5.4）：
/// - 顶部说明
/// - 只读区（输入数据示例 + 输出格式）
/// - 可编辑区（score 计算逻辑）
/// - 「恢复默认」+ 「保存」按钮
class KeywordScorePromptScreen extends ConsumerStatefulWidget {
  const KeywordScorePromptScreen({super.key});

  @override
  ConsumerState<KeywordScorePromptScreen> createState() =>
      _KeywordScorePromptScreenState();
}

class _KeywordScorePromptScreenState
    extends ConsumerState<KeywordScorePromptScreen> {
  late TextEditingController _controller;
  bool _isLoading = true;
  bool _isDefault = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadPrompt();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPrompt() async {
    try {
      final globalStorage =
          ref.read(keywordGlobalStorageProvider).requireValue;
      final file = await globalStorage.loadOrInit();
      _controller.text = file.scorePrompt ?? KeywordGlobalFile.defaultScorePrompt;
      _isDefault = file.scorePromptIsDefault;
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(brightnessProvider);
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.pageBg,
      navigationBar: CupertinoNavigationBar(
        previousPageTitle: l10n.settingsTabLabel,
        middle: Text(l10n.keywordScorePromptTitle),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isLoading ? null : _save,
          child: Text(
            l10n.save,
            style: TextStyle(
              fontSize: 17,
              color: _isLoading ? AppColors.textTertiary : null,
            ),
          ),
        ),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildContent(l10n),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 100),
        children: [
          // 说明
          Text(
            l10n.keywordScorePromptDescription,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // 只读区：输入数据示例
          _ReadOnlySection(
            title: l10n.keywordScorePromptInputExample,
            content: _inputExample,
          ),
          const SizedBox(height: 16),

          // 可编辑区
          Text(
            l10n.keywordScorePromptEditableSection,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoTextField(
            controller: _controller,
            maxLines: 10,
            minLines: 6,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.border,
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.all(12),
          ),
          const SizedBox(height: 16),

          // 只读区：输出格式
          _ReadOnlySection(
            title: l10n.keywordScorePromptOutputFormat,
            content: _outputFormat,
          ),
          const SizedBox(height: 24),

          // 恢复默认按钮
          if (!_isDefault)
            Center(
              child: CupertinoButton(
                onPressed: _resetToDefault,
                child: Text(
                  l10n.keywordScorePromptResetDefault,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _resetToDefault() {
    setState(() {
      _controller.text = KeywordGlobalFile.defaultScorePrompt;
      _isDefault = true;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;

    try {
      final globalStorage =
          ref.read(keywordGlobalStorageProvider).requireValue;
      await globalStorage.updateAsync((current) {
        current.scorePrompt = _controller.text;
        current.scorePromptIsDefault =
            _controller.text == KeywordGlobalFile.defaultScorePrompt;
        return current;
      });

      if (mounted) {
        // 显示成功提示
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(l10n.keywordScorePromptSaveSuccess),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(l10n.keywordScorePromptSaveFailed),
            content: Text(e.toString()),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  static const _inputExample = '''[
  {
    "keyword": "学习方法",
    "cross_theme_count": 3,
    "cross_leaf_count": 5,
    "depth_avg": 2.4,
    "stale_ratio": 0.4
  }
]''';

  static const _outputFormat = '''[
  {
    "keyword": "学习方法",
    "score": 0.87
  }
]''';
}

/// 只读展示区块。
class _ReadOnlySection extends StatelessWidget {
  const _ReadOnlySection({
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.border,
              width: 0.5,
            ),
          ),
          child: Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
