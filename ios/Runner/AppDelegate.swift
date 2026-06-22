import Flutter
import UIKit
import AlibabaCloudRUM

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 初始化阿里云 RUM SDK
    AlibabaCloudRUM.setEndpoint("https://proj-xtrace-2a7ec69c3cebe87219568fbae0118715-ap-southeast-1.ap-southeast-1.log.aliyuncs.com")
    AlibabaCloudRUM.setWorkspace("default-cms-1620411008178669-ap-southeast-1")
    AlibabaCloudRUM.start("fydyjghwbx@5d461352920b557635c9f")

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
