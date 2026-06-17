import 'dart:async';

import 'package:thk_tree/data/services/tts_service.dart';

/// Android 平台（及其他非 iOS 平台）的 TTS 桩实现。
///
/// 所有方法静默 no-op，UI 调用不会抛错，播放按钮不会发声。
/// 切换到 Apple TTS 仅需修改 `app_services.dart` 中的 provider 工厂。
class NoOpTtsService implements TtsService {
  @override
  bool get isSpeaking => false;

  @override
  String? get currentVoiceId => null;

  @override
  Stream<bool> get isSpeakingStream => const Stream.empty();

  @override
  Future<bool> speak(String text, {String? voiceId, double? rate}) async {
    // Android 桩：无声播放
    return false;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<List<TtsVoice>> get availableVoices async => const [];

  @override
  Future<void> setVoice(String? voiceId) async {}

  @override
  void dispose() {}
}
