# flutter_secure_storage iOS 真机保存失败

**日期**：2026-06-15  
**模块**：settings / 安全存储  
**标签**：iOS, Keychain, 真机, flutter_secure_storage, 权限

## 现象

模拟器上 `flutter_secure_storage` 读写正常，但 iOS 真机（物理设备）上：

- 写入 API Key 后读取返回 `null`
- 无报错，但数据似乎未持久化
- 重启 App 后配置丢失

## 根因分析

iOS Keychain 的访问性（Accessibility）默认值为 `kSecAttrAccessibleWhenUnlocked`，在真机上受更严格的权限控制。如果 App 在后台或被锁屏时访问，会失败。此外，Keychain Sharing entitlement 未配置也会导致真机上的隔离问题。

## 解决方案

### 1. 显式指定 iOS 选项

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _storage = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
    accountName: 'flutter_secure_storage_service',
  ),
);
```

### 2. 配置 Keychain Sharing Entitlement

`ios/Runner/Runner.entitlements`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.example.thktree</string>
    </array>
</dict>
</plist>
```

Xcode 中：
1. 选中 Runner target → Signing & Capabilities
2. 点击 "+ Capability" → 添加 "Keychain Sharing"

### 3. 保存时加错误处理

```dart
Future<void> saveApiKey(String key) async {
  try {
    await _storage.write(key: 'api_key', value: key);
  } on PlatformException catch (e) {
    // 真机常见错误：-34018 (errSecMissingEntitlement)
    debugPrint('Keychain write failed: ${e.code} ${e.message}');
    rethrow;
  }
}
```

## 关键代码

`lib/data/services/settings_store.dart` 中的存储初始化：

```dart
class SettingsStore {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  // ...
}
```

## 相关文件

- `lib/data/services/settings_store.dart`
- `ios/Runner/Runner.entitlements`
- `ios/Runner.xcodeproj/project.pbxproj`

## 参考链接

- [flutter_secure_storage 官方文档 - iOS 配置](https://pub.dev/packages/flutter_secure_storage#ios)
- Apple Developer: [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [TECH-DEBT.md](../TECH-DEBT.md) — 相关技术债条目

## 复盘

- **为什么一开始没发现**：模拟器的 Keychain 行为与真机不同，模拟器不检查 entitlement，权限也更宽松。只在模拟器测试会遗漏真机问题。
- **以后如何避免**：任何涉及 Keychain、 biometric、推送等 iOS 系统级功能，必须在真机上验证至少一次。
- **扩展**：此问题模式适用于所有使用 `flutter_secure_storage`、`local_auth`（Face ID）、`firebase_messaging` 等需要 entitlement 的插件。
