import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/tts_service.dart';
import 'package:thk_tree/l10n/generated/app_localizations.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';
import 'package:thk_tree/ui/core/theme/app_icons.dart';
import 'package:thk_tree/ui/core/widgets/thk_list_section.dart';
import 'package:thk_tree/ui/core/widgets/thk_nav_bar.dart';
import 'package:thk_tree/ui/features/settings/tts_controller.dart';
import 'package:thk_tree/ui/features/settings/tts_tokens.dart';

/// TTS 声音选择页。
///
/// 流程：
/// 1. 拉取 [TtsService.availableVoices]
/// 2. 按语言分组：zh-CN* 优先，"其他" 兜底
/// 3. 选中后调用 [TtsController.setVoice] + 自动试听一句
class TtsSettingsScreen extends ConsumerStatefulWidget {
  const TtsSettingsScreen({super.key});

  @override
  ConsumerState<TtsSettingsScreen> createState() => _TtsSettingsScreenState();
}

class _TtsSettingsScreenState extends ConsumerState<TtsSettingsScreen> {
  late Future<List<TtsVoice>> _voicesFuture;

  @override
  void initState() {
    super.initState();
    _voicesFuture = _loadVoices();
  }

  Future<List<TtsVoice>> _loadVoices() async {
    final service = ref.read(ttsServiceProvider);
    if (service == null) return const [];
    return service.availableVoices;
  }

  Future<void> _selectAndPreview(TtsVoice voice) async {
    final ctrl = ref.read(ttsControllerProvider.notifier);
    await ctrl.setVoice(voice.id);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final sample = '你好，我是${voice.name}，${l10n.ttsTestPlay}。';
    await ctrl.play('__preview__', sample, rate: 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ThkLargeTitlePage(
      title: l10n.ttsVoiceSettings,
      children: [
        ThkListSection(
          children: [
            _EngineTile(label: l10n.ttsEngine, value: l10n.ttsAppleSystem),
          ],
        ),
        FutureBuilder<List<TtsVoice>>(
          future: _voicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return ThkListSection(
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: TtsSpacing.voiceRowPaddingX,
                      vertical: TtsSpacing.voiceRowPaddingY,
                    ),
                    child: CupertinoActivityIndicator(),
                  ),
                ],
              );
            }
            final voices = snapshot.data ?? const <TtsVoice>[];
            if (voices.isEmpty) {
              return ThkListSection(
                children: [
                  _VoiceRow(
                    title: l10n.ttsNoVoicesAvailable,
                    locale: '',
                    selected: false,
                    onTap: null,
                  ),
                ],
              );
            }
            final chinese = voices
                .where((v) => v.language.toLowerCase().startsWith('zh'))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            final others = voices
                .where((v) => !v.language.toLowerCase().startsWith('zh'))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

            final currentVoiceId = ref.watch(
                ttsControllerProvider.select((s) => s.currentVoiceId));

            return Column(
              children: [
                if (chinese.isNotEmpty)
                  ThkListSection(
                    children: [
                      for (final v in chinese)
                        _VoiceRow(
                          title: v.name,
                          locale: v.id,
                          selected: v.id == currentVoiceId,
                          onTap: () => _selectAndPreview(v),
                        ),
                    ],
                  ),
                if (others.isNotEmpty)
                  ThkListSection(
                    header: '其他',
                    children: [
                      for (final v in others)
                        _VoiceRow(
                          title: v.name,
                          locale: v.id,
                          selected: v.id == currentVoiceId,
                          onTap: () => _selectAndPreview(v),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _EngineTile extends StatelessWidget {
  const _EngineTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TtsSpacing.voiceRowPaddingX,
        vertical: TtsSpacing.voiceRowPaddingY,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 17, color: AppColors.textPrimary),
            ),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.title,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String locale;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      onTap: onTap,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          color: onTap != null ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      subtitle: locale.isEmpty
          ? null
          : Text(
              locale,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
      trailing: selected
          ? Icon(AppIcons.check, size: 20, color: AppColors.accent)
          : (onTap != null
              ? const CupertinoListTileChevron()
              : const SizedBox.shrink()),
    );
  }
}
