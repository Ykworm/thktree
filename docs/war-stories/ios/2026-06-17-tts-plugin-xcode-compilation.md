# 自定义 Swift 插件未被 Xcode 编译识别

**日期**：2026-06-17  
**模块**：settings / TTS  
**标签**：iOS, Swift, Xcode, 编译错误, 桥接

## 现象

Xcode 编译报错：

```
Cannot find 'TtsPlugin' in scope
```

`TtsPlugin.swift` 文件已创建在 `ios/Runner/` 目录下，`AppDelegate.swift` 中也写了注册代码，但编译时找不到符号。

## 根因分析

`TtsPlugin.swift` 是**手动创建的原生插件**（非 pubspec.yaml 引入的 Flutter package），Flutter 工具链不会自动将其加入 Xcode 项目的编译配置。必须显式在 `project.pbxproj` 中注册四个位置：

1. `PBXBuildFile` — 声明编译动作
2. `PBXFileReference` — 声明文件引用
3. `PBXGroup` — 将文件加入 Runner 组
4. `PBXSourcesBuildPhase` — 加入编译源文件列表

## 解决方案

### 方案 A：手动拖入 Xcode（推荐）

1. 用 Xcode 打开 `Runner.xcworkspace`
2. 将 `TtsPlugin.swift` 拖入 Runner target 的文件夹列表
3. 确保勾选 "Copy items if needed" 和 "Add to targets: Runner"

### 方案 B：修改 project.pbxproj（自动化）

```ruby
# 使用 xcodeproj gem
require 'xcodeproj'

project = Xcodeproj::Project.open('ios/Runner.xcodeproj')
target = project.targets.find { |t| t.name == 'Runner' }

file_ref = project.main_group.new_file('Runner/TtsPlugin.swift')
target.source_build_phase.add_file_reference(file_ref)

project.save
```

## 关键配置

注册代码（`AppDelegate.swift`）：

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // 手动注册自定义插件
    TtsPlugin.register(with: self.registrar(forPlugin: "TtsPlugin")!)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

## 相关文件

- `ios/Runner/TtsPlugin.swift`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner.xcodeproj/project.pbxproj`

## 参考链接

- [iOS 原生 TTS 桥接实现说明](../modules/settings/specs/2026-06-17-iOS原生TTS桥接实现.md)
- [语音播放功能 v1 上线](../CHANGELOG/2026-06-17-tts-v1.md)

## 复盘

- **为什么一开始没发现**：Flutter 的 `flutter create` 和 `pubspec.yaml` 依赖会自动处理原生代码注册，让人误以为手动创建的文件也会被自动识别。
- **以后如何避免**：任何手动创建的原生文件（Swift/Kotlin/C++），第一步就是确认是否已加入对应平台的构建系统（Xcode project / Gradle sourceSet / CMakeLists）。
- **扩展**：此问题模式适用于所有 Flutter 自定义平台插件的手写文件。
