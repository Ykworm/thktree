// macOS 桌面端集成测试 — Fixtures
//
// 提供：
//   - _MemStore：内存版 FlutterSecureStorage（替代 macOS Keychain）
//   - createDesktopTestApp()：标准 macOS 测试 App 工厂
//   - Context 类：ThemeCtx / NodeCtx / ChatCtx
//
// 用法：
//   final app = await createDesktopTestApp(activeProvider: 'kimi');
//   await switchToThemes(tester);
//   final theme = await createTheme(tester, '测试主题');

import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import '../../_support/llm_test_config.dart';

// ── 内存安全存储 ──

class MemStore extends FlutterSecureStorage {
  MemStore([Map<String, String> initial = const {}]) : _s = Map.from(initial);
  final Map<String, String> _s;

  @override
  Future<void> write({required String key, required String? value, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async {
    if (value != null) _s[key] = value;
  }
  @override
  Future<String?> read({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async => _s[key];
  @override
  Future<void> delete({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async { _s.remove(key); }
  @override
  Future<Map<String, String>> readAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async => Map.from(_s);
  @override
  Future<void> deleteAll({IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async { _s.clear(); }
  @override
  Future<bool> containsKey({required String key, IOSOptions? iOptions, AndroidOptions? aOptions, LinuxOptions? lOptions, MacOsOptions? mOptions, WebOptions? webOptions, WindowsOptions? wOptions}) async => _s.containsKey(key);
}

// ── Context 对象 ──

class ThemeCtx {
  ThemeCtx({required this.themeId, required this.title});
  final String themeId;
  final String title;
  final List<NodeCtx> roots = [];
}

class NodeCtx {
  NodeCtx({
    required this.nodeId,
    required this.title,
    required this.theme,
    this.parent,
    this.depth = 1,
    this.sourceType = '',
  });
  final String nodeId;
  final String title;
  final ThemeCtx theme;
  final NodeCtx? parent;
  final int depth;
  final String sourceType;
  final List<NodeCtx> children = [];
}

class ChatCtx {
  ChatCtx({required this.node});
  final NodeCtx node;
  final List<String> userMessages = [];
  String? modelId;
}

// ── macOS 测试 App 工厂 ──

Future<Widget> createDesktopTestApp({
  Locale locale = const Locale('zh'),
  String activeProvider = 'kimi',
  String activeModel = 'moonshot-v1-8k',
  List extraOverrides = const [],
}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final llmConfig = LlmTestConfig.loadFromDefine();
  final settings = llmConfig.toAppSettings();

  final providerId = settings.chatDefaultProviderId ?? 'preset_$activeProvider';
  final modelId = settings.chatDefaultModelId ?? activeModel;

  final allOverrides = <dynamic>[
    settingsStoreProvider.overrideWithValue(
      SettingsStore(secureStorage: MemStore({
        'chat_default_provider_id': providerId,
        'chat_default_model_id': modelId,
        'last_used_chat_provider_id': providerId,
        'last_used_chat_model_id': modelId,
      })),
    ),
    ...extraOverrides,
  ];

  return createTestApp(
    locale: locale,
    llmSettings: settings,
    llmConfigStore: llmConfig.toLlmConfigStore(),
    extraOverrides: allOverrides,
  );
}
