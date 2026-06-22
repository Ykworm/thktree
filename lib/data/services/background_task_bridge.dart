import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS 原生 `UIApplication.beginBackgroundTask` 桥接。
///
/// 协议见 ios/Runner/BackgroundTaskHandler.swift。
/// 非 iOS 平台所有方法返回 `null` / `false`，调用方无需判平台即可安全使用。
///
/// 行为约定（与 `AppleTtsService` 一致）：
/// - bridge 是 best-effort 工具，调用一律 swallow `PlatformException`
/// - 失败时通过 `debugPrint` 记录，**不**抛异常给上层
/// - begin 失败返回 `null`（iOS 返回 `UIBackgroundTaskIdentifier.invalid` 时）
class BackgroundTaskBridge {
  BackgroundTaskBridge({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ?? const MethodChannel('thktree/background_task');

  final MethodChannel _methodChannel;

  /// 申请后台任务。成功返回 iOS 端分配的 task id（`UIBackgroundTaskIdentifier.rawValue`），
  /// 非 iOS 平台或失败返回 `null`。
  Future<String?> begin() async {
    if (!Platform.isIOS) return null;
    try {
      final id = await _methodChannel.invokeMethod<String>('begin');
      return id;
    } on PlatformException catch (e) {
      debugPrint('[BackgroundTaskBridge] begin failed: ${e.message ?? e.code}');
      return null;
    }
  }

  /// 结束后台任务。返回是否成功 end 了一个有效 task。
  Future<bool> end() async {
    if (!Platform.isIOS) return false;
    try {
      final ok = await _methodChannel.invokeMethod<bool>('end');
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BackgroundTaskBridge] end failed: ${e.message ?? e.code}');
      return false;
    }
  }

  /// 查询当前是否有活跃的后台 task。
  Future<bool> isActive() async {
    if (!Platform.isIOS) return false;
    try {
      final active = await _methodChannel.invokeMethod<bool>('isActive');
      return active ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BackgroundTaskBridge] isActive failed: ${e.message ?? e.code}');
      return false;
    }
  }
}
