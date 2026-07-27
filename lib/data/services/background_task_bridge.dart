import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// iOS `beginBackgroundTask` / Android Foreground Service 桥接。
///
/// 协议见：
/// - ios/Runner/BackgroundTaskHandler.swift
/// - android/.../BackgroundTaskPlugin.kt
///
/// 行为约定：
/// - bridge 是 best-effort 工具，调用一律 swallow `PlatformException`
/// - 失败时通过 `debugPrint` 记录，**不**抛异常给上层
/// - [begin]/[end] 使用引用计数：多路并发流时仅首个 begin 启原生保活、末个 end 释放
class BackgroundTaskBridge {
  BackgroundTaskBridge({MethodChannel? methodChannel})
      : _methodChannel = methodChannel ?? const MethodChannel('thktree/background_task');

  final MethodChannel _methodChannel;
  int _activeCount = 0;

  /// 当前 Dart 侧引用计数（测试观测用）。
  @visibleForTesting
  int get activeCount => _activeCount;

  /// 申请后台保活。首个 active 流时调原生 begin。
  Future<String?> begin() async {
    _activeCount++;
    if (_activeCount > 1) {
      return 'refcount:$_activeCount';
    }
    try {
      final id = await _methodChannel.invokeMethod<String>('begin');
      if (id == null) {
        _activeCount--;
      }
      return id;
    } on PlatformException catch (e) {
      _activeCount--;
      debugPrint('[BackgroundTaskBridge] begin failed: ${e.message ?? e.code}');
      return null;
    }
  }

  /// 释放后台保活。末个 active 流结束时调原生 end。
  Future<bool> end() async {
    if (_activeCount <= 0) {
      return false;
    }
    _activeCount--;
    if (_activeCount > 0) {
      return true;
    }
    try {
      final ok = await _methodChannel.invokeMethod<bool>('end');
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BackgroundTaskBridge] end failed: ${e.message ?? e.code}');
      return false;
    }
  }

  /// 查询当前是否有活跃的保活（Dart 计数或原生状态）。
  Future<bool> isActive() async {
    if (_activeCount > 0) return true;
    try {
      final active = await _methodChannel.invokeMethod<bool>('isActive');
      return active ?? false;
    } on PlatformException catch (e) {
      debugPrint('[BackgroundTaskBridge] isActive failed: ${e.message ?? e.code}');
      return false;
    }
  }
}
