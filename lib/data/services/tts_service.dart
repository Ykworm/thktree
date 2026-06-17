/// 抽象 TTS 服务接口。
///
/// v1: speak / stop / voices / 当前 voice 选择。
///
/// TODO(roadmap-v2): 跟随朗读模式
///   spec: docs/modules/settings/specs/2026-06-05-语音播放功能-design.md#11-v2
///   hook: willSpeakRangeStream（新接口）
abstract class TtsService {
  /// 播放一段文本，可选指定 voiceId 和 rate。
  /// 返回是否成功启动（false 通常表示参数无效或未初始化）。
  Future<bool> speak(String text, {String? voiceId, double? rate});

  /// 停止当前播放。
  Future<void> stop();

  /// 当前是否在播放（同步快照，UI 优先用 [isSpeakingStream]）。
  bool get isSpeaking;

  /// 播放状态流（true = 开始, false = 结束/取消）。
  Stream<bool> get isSpeakingStream;

  /// 可用语音列表。
  Future<List<TtsVoice>> get availableVoices;

  /// 当前选中的语音 ID（持久化字段，null = 未选 / 用默认）。
  String? get currentVoiceId;

  /// 切换语音（持久化由调用方负责）。
  Future<void> setVoice(String? voiceId);

  /// 释放资源（关闭流订阅等）。
  void dispose();
}

/// 单个 TTS 语音的元数据。
class TtsVoice {
  const TtsVoice({
    required this.id,
    required this.name,
    required this.language,
    this.quality,
  });

  final String id;
  final String name;
  final String language; // e.g. "zh-CN"
  final String? quality; // "enhanced" / "premium" / "default"

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TtsVoice
        && other.id == id
        && other.name == name
        && other.language == language
        && other.quality == quality;
  }

  @override
  int get hashCode => Object.hash(id, name, language, quality);

  @override
  String toString() => 'TtsVoice($id, $name, $language, $quality)';
}

/// TTS 调用失败时抛出的异常。
class TtsException implements Exception {
  const TtsException(this.code, this.message, [this.cause]);

  final String code; // 'notInitialized' / 'speakFailed' / 'voiceNotFound' / 'unsupported'
  final String message;
  final Object? cause;

  @override
  String toString() => 'TtsException($code): $message';
}
