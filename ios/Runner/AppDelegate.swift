import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // 注册 TtsPlugin（AVSpeechSynthesizer 桥接）
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TtsPlugin") {
      TtsPlugin.register(with: registrar)
    }
    // 注册 BackgroundTaskHandler（UIApplication.beginBackgroundTask 桥接）
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "BackgroundTaskHandler") {
      BackgroundTaskHandler.register(with: registrar)
    }
  }
}
