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
/// 引用计数：Dart 侧多路并发流时，仅首个 begin 申请 OS task，末个 end 释放。
public class BackgroundTaskHandler: NSObject, FlutterPlugin {
  private static let methodChannelName = "thktree/background_task"

  private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
  private var activeCount = 0

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
      result(activeCount > 0 || backgroundTask != .invalid)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - Background task lifecycle

  /// 申请后台任务。引用计数 > 1 时复用已有 identifier。
  /// - Returns: task identifier 字符串；OS 拒绝分配时返回 nil。
  private func beginBackgroundTask() -> String? {
    activeCount += 1
    if backgroundTask != .invalid {
      return "\(backgroundTask.rawValue)"
    }

    let identifier = UIApplication.shared.beginBackgroundTask(
      withName: "thktree_llm_stream"
    ) { [weak self] in
      self?.forceEndBackgroundTask()
    }
    if identifier == .invalid {
      activeCount = max(0, activeCount - 1)
      return nil
    }
    backgroundTask = identifier
    return "\(identifier.rawValue)"
  }

  /// 释放后台任务。引用计数归零时才 end OS task。
  /// - Returns: 是否处理了 end 请求。
  @discardableResult
  private func endBackgroundTask() -> Bool {
    if activeCount <= 0 {
      return false
    }
    activeCount -= 1
    if activeCount > 0 {
      return true
    }
    return forceEndBackgroundTask()
  }

  @discardableResult
  private func forceEndBackgroundTask() -> Bool {
    if backgroundTask == .invalid {
      return false
    }
    UIApplication.shared.endBackgroundTask(backgroundTask)
    backgroundTask = .invalid
    activeCount = 0
    return true
  }
}
