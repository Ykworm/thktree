import Flutter
import UIKit

/// iOS 原生后台任务桥接，基于 `UIApplication.beginBackgroundTask`。
///
/// Channel 协议：
///   - MethodChannel "thktree/background_task"
///     - "begin"    args: null -> String?  // 返回 task identifier 字符串；失败返回 nil
///     - "end"      args: null -> Bool     // 释放后台任务；未 begin 时返回 false
///     - "isActive" args: null -> Bool     // 当前是否有 active 后台任务
///
/// 多次 "begin" 安全：内部会先释放旧的 task，避免 identifier 泄漏。
public class BackgroundTaskHandler: NSObject, FlutterPlugin {
  private static let methodChannelName = "thktree/background_task"

  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = BackgroundTaskHandler()
    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "begin":
      result(beginBackgroundTask())
    case "end":
      result(endBackgroundTask())
    case "isActive":
      result(backgroundTask != .invalid)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Background task lifecycle

  /// 申请后台任务。多次调用安全：先释放旧的。
  /// - Returns: task identifier 字符串；OS 拒绝分配时返回 nil。
  private func beginBackgroundTask() -> String? {
    // 多次 begin：先释放旧的，避免 identifier 泄漏
    if backgroundTask != .invalid {
      endBackgroundTask()
    }

    let identifier = UIApplication.shared.beginBackgroundTask(
      withName: "thktree_llm_stream"
    ) { [weak self] in
      // OS 即将终止时的 expiration handler：自动释放
      self?.endBackgroundTask()
    }
    if identifier == .invalid {
      return nil
    }
    backgroundTask = identifier
    return "\(identifier.rawValue)"
  }

  /// 释放后台任务。多次调用安全。
  /// - Returns: 是否确实释放了一个 active task。
  @discardableResult
  private func endBackgroundTask() -> Bool {
    if backgroundTask == .invalid {
      return false
    }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
    return true
  }
}
