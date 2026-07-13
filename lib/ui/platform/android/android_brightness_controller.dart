// Android 系统深色模式联动（handoff §1.3 / §2.7）。
//
// ThkTree 的 AppColors 通过 setBrightness 切换；在 Android 上必须把系统全局
// 深色开关接进来：监听 PlatformDispatcher.instance.platformBrightness，变化时
// 调 AppColors.setBrightness，否则 App 不跟系统切换。
//
// 核心同步逻辑抽成纯函数 + 注入式亮度来源，便于单测（无需真实 PlatformDispatcher）。

import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:thk_tree/ui/core/theme/app_colors.dart';

/// 纯函数：把系统亮度同步进 AppColors 单一真源。
void syncBrightnessToSystem(Brightness systemBrightness) {
  AppColors.setBrightness(systemBrightness);
}

/// 系统亮度联动控制器。
///
/// 默认监听 [PlatformDispatcher.instance]；测试时通过 [getBrightness] 注入来源，
/// 直接驱动 [syncNow] / [didChangePlatformBrightness]，无需真实绑定。
class AndroidBrightnessController with WidgetsBindingObserver {
  AndroidBrightnessController({
    Brightness Function()? getBrightness,
  }) : _getBrightness =
            getBrightness ?? (() => PlatformDispatcher.instance.platformBrightness);

  final Brightness Function() _getBrightness;

  /// 注册为 WidgetsBinding 观察者（真实运行环境调用）。
  void attach() => WidgetsBinding.instance.addObserver(this);

  /// 注销观察者。
  void detach() => WidgetsBinding.instance.removeObserver(this);

  /// 立即按当前系统亮度同步一次（initState 调用）。
  void syncNow() => syncBrightnessToSystem(_getBrightness());

  @override
  void didChangePlatformBrightness() => syncNow();
}
