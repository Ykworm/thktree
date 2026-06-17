import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:thk_tree/data/services/tts_service.dart';

/// iOS 原生 TTS 实现，通过 MethodChannel / EventChannel 桥接 TtsPlugin。
///
/// Channel 协议见 ios/Runner/TtsPlugin.swift。
class AppleTtsService implements TtsService {
  AppleTtsService({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  })  : _methodChannel = methodChannel ?? const MethodChannel('thktree/tts'),
        _eventChannel = eventChannel ?? const EventChannel('thktree/tts/events') {
    _stateSub = _eventChannel
        .receiveBroadcastStream()
        .listen(_onStateEvent, onError: (e, st) {
      debugPrint('[AppleTtsService] event channel error: $e');
    });
  }

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  final StreamController<bool> _stateController =
      StreamController<bool>.broadcast();
  late final StreamSubscription<dynamic> _stateSub;

  bool _isSpeaking = false;
  String? _currentVoiceId;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  String? get currentVoiceId => _currentVoiceId;

  @override
  Stream<bool> get isSpeakingStream => _stateController.stream;

  void _onStateEvent(dynamic event) {
    if (event is bool) {
      _isSpeaking = event;
      _stateController.add(event);
    }
  }

  @override
  Future<bool> speak(String text, {String? voiceId, double? rate}) async {
    if (text.isEmpty) {
      throw const TtsException('invalid_args', 'text is empty');
    }
    final clampedRate = rate?.clamp(0.0, 1.0).toDouble();
    try {
      final result = await _methodChannel.invokeMethod<bool>('speak', {
        'text': text,
        'voiceId': voiceId ?? _currentVoiceId,
        'rate': clampedRate,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw TtsException(
        e.code,
        e.message ?? 'speak failed',
        e,
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod<void>('stop');
    } on PlatformException catch (e) {
      debugPrint('[AppleTtsService] stop failed: ${e.message}');
    }
  }

  @override
  Future<List<TtsVoice>> get availableVoices async {
    try {
      final raw = await _methodChannel.invokeMethod<List<dynamic>>('getVoices');
      if (raw == null) return const [];
      return raw
          .whereType<Map<dynamic, dynamic>>()
          .map((m) => TtsVoice(
                id: m['id'] as String? ?? '',
                name: m['name'] as String? ?? '',
                language: m['language'] as String? ?? '',
                quality: m['quality'] as String?,
              ))
          .where((v) => v.id.isNotEmpty)
          .toList();
    } on PlatformException catch (e) {
      debugPrint('[AppleTtsService] getVoices failed: ${e.message}');
      return const [];
    }
  }

  @override
  Future<void> setVoice(String? voiceId) async {
    _currentVoiceId = voiceId;
  }

  @override
  void dispose() {
    _stateSub.cancel();
    _stateController.close();
  }
}
