import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:thk_tree/data/services/tts_service.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/features/settings/settings_controller.dart';

/// TTS 模块的不可变状态。
///
/// 字段语义：
/// - [playingMessageId] 当前正在播放的消息 ID（null = 无人在播）
/// - [isSpeaking] 是否在播放（来自 service.isSpeaking 流）
/// - [currentVoiceId] 当前选中的 voice（持久化字段，由 AppSettings 同步）
class TtsState {
  const TtsState({
    this.playingMessageId,
    this.isSpeaking = false,
    this.currentVoiceId,
  });

  final String? playingMessageId;
  final bool isSpeaking;
  final String? currentVoiceId;

  TtsState copyWith({
    String? playingMessageId,
    bool? isSpeaking,
    String? currentVoiceId,
    bool clearPlayingMessageId = false,
  }) {
    return TtsState(
      playingMessageId:
          clearPlayingMessageId ? null : (playingMessageId ?? this.playingMessageId),
      isSpeaking: isSpeaking ?? this.isSpeaking,
      currentVoiceId: currentVoiceId ?? this.currentVoiceId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TtsState
        && other.playingMessageId == playingMessageId
        && other.isSpeaking == isSpeaking
        && other.currentVoiceId == currentVoiceId;
  }

  @override
  int get hashCode => Object.hash(playingMessageId, isSpeaking, currentVoiceId);
}

/// Riverpod Notifier，管理 TTS 播放互斥、状态同步、voice 持久化。
///
/// TODO(roadmap-v2): 跟随朗读模式
///   spec: docs/modules/settings/specs/2026-06-05-语音播放功能-design.md#11-v2
///   hook: TtsService.willSpeakRangeStream（新接口）
class TtsController extends Notifier<TtsState> {
  TtsService? _service;
  StreamSubscription<bool>? _speakSub;

  @override
  TtsState build() {
    _service = ref.read(ttsServiceProvider);

    // 同步初始 voice（从 AppSettings 加载）
    final settingsAsync = ref.read(settingsControllerProvider);
    final settings = settingsAsync.value;
    final initialVoice = settings?.ttsVoiceId ?? _service?.currentVoiceId;

    // 订阅服务端的 isSpeaking 流 → 推送给 UI
    final svc = _service;
    if (svc != null) {
      _speakSub = svc.isSpeakingStream.listen((speaking) {
        if (!speaking) {
          // 播放结束 / 取消，重置 playingMessageId
state = state.copyWith(
            isSpeaking: false,
            clearPlayingMessageId: true,
          );
        } else {
          state = state.copyWith(isSpeaking: true);
        }
      });
      ref.onDispose(() {
        _speakSub?.cancel();
        _speakSub = null;
        svc.dispose();
      });
    } else {
      ref.onDispose(() {
        _speakSub?.cancel();
        _speakSub = null;
      });
    }

    return TtsState(currentVoiceId: initialVoice);
  }

  /// 播放指定消息。互斥规则：先停后播。
  Future<void> play(String messageId, String text, {double rate = 0.5}) async {
    final svc = _service;
    if (svc == null) return;
    if (text.isEmpty) return;

    try {
      await svc.stop();
      final ok = await svc.speak(
        text,
        voiceId: state.currentVoiceId,
        rate: rate,
      );
      if (ok) {
        state = state.copyWith(
          playingMessageId: messageId,
          isSpeaking: true,
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 停止当前播放。
  Future<void> stop() async {
    final svc = _service;
    if (svc == null) return;
    await svc.stop();
    state = state.copyWith(
      isSpeaking: false,
      clearPlayingMessageId: true,
    );
  }

  /// 切换 voice，持久化到 SettingsStore。
  Future<void> setVoice(String? voiceId) async {
    final svc = _service;
    if (svc != null) {
      await svc.setVoice(voiceId);
    }
    state = state.copyWith(currentVoiceId: voiceId);

    // 持久化
    final store = ref.read(settingsStoreProvider);
    await store.saveTtsVoiceId(voiceId);
  }
}

final ttsControllerProvider =
    NotifierProvider<TtsController, TtsState>(TtsController.new);
