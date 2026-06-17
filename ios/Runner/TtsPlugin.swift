import AVFoundation
import Flutter
import UIKit

/// iOS 原生 TTS 桥接，基于 AVSpeechSynthesizer。
///
/// Channel 协议：
///   - MethodChannel "thktree/tts"
///     - "speak"   args: { text: String, voiceId: String?, rate: Double? } -> Bool
///     - "stop"    args: null -> Void
///     - "getVoices" args: null -> [[String: String]]  // [{id, name, language, quality}]
///   - EventChannel "thktree/tts/events"
///     - onListen: emit Bool (true = 开始, false = 结束/取消)
public class TtsPlugin: NSObject, FlutterPlugin, AVSpeechSynthesizerDelegate {
  private static let methodChannelName = "thktree/tts"
  private static let eventChannelName = "thktree/tts/events"

  private let synthesizer = AVSpeechSynthesizer()
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = TtsPlugin()
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: registrar.messenger()
    )

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)

    instance.synthesizer.delegate = instance
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "speak":
      handleSpeak(call: call, result: result)
    case "stop":
      synthesizer.stopSpeaking(at: .immediate)
      result(nil)
    case "getVoices":
      result(voicesSnapshot())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Speak

  private func handleSpeak(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let text = args["text"] as? String, !text.isEmpty
    else {
      result(
        FlutterError(
          code: "invalid_args",
          message: "speak requires non-empty text",
          details: nil
        ))
      return
    }

    let utterance = AVSpeechUtterance(string: text)

    // 解析 voiceId（可空，使用系统默认）
    if let voiceId = args["voiceId"] as? String, !voiceId.isEmpty,
       let voice = AVSpeechSynthesisVoice(identifier: voiceId)
    {
      utterance.voice = voice
    } else {
      utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
    }

    // 解析 rate（0.0~1.0，默认 0.5 = 正常）
    if let rate = args["rate"] as? Double {
      utterance.rate = Float(rate.clamped(to: 0.0...1.0))
    } else {
      utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    }

    // 配置音频会话（不后台播放，符合 MVP scope）
    configureAudioSession()

    synthesizer.speak(utterance)
    result(true)
  }

  private func configureAudioSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(
        .playback,
        mode: .spokenAudio,
        options: [.duckOthers]
      )
      try session.setActive(true, options: [])
    } catch {
      NSLog("[TtsPlugin] AVAudioSession config failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Voice list snapshot

  private func voicesSnapshot() -> [[String: String]] {
    return AVSpeechSynthesisVoice.speechVoices().map { voice in
      let quality: String
      if #available(iOS 16.0, *) {
        quality = voice.quality == .premium
          ? "premium"
          : (voice.quality == .enhanced ? "enhanced" : "default")
      } else {
        quality = voice.quality == .enhanced ? "enhanced" : "default"
      }
      return [
        "id": voice.identifier,
        "name": voice.name,
        "language": voice.language,
        "quality": quality,
      ]
    }
  }

  // MARK: - AVSpeechSynthesizerDelegate

  public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didStart utterance: AVSpeechUtterance
  ) {
    eventSink?(true)
  }

  public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didFinish utterance: AVSpeechUtterance
  ) {
    eventSink?(false)
  }

  public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    didCancel utterance: AVSpeechUtterance
  ) {
    eventSink?(false)
  }

  // TODO(roadmap-v2): 监听 willSpeakRangeOfSpeechString 实现 auto-scroll
  //   spec: docs/modules/settings/specs/2026-06-05-语音播放功能-design.md#11-v2
  //   hook: TtsService.willSpeakRangeStream
  public func speechSynthesizer(
    _ synthesizer: AVSpeechSynthesizer,
    willSpeakRangeOfSpeechString characterRange: NSRange,
    utterance: AVSpeechUtterance
  ) {
    // v1: 暂不推送，接口预留
  }
}

// MARK: - FlutterStreamHandler

extension TtsPlugin: FlutterStreamHandler {
  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}

// MARK: - Helpers

private extension Comparable {
  func clamped(to range: ClosedRange<Self>) -> Self {
    return min(max(self, range.lowerBound), range.upperBound)
  }
}
