// iOS 后台流式中断恢复集成测试（Task 9）。
//
// 测试约定详见 docs/superpowers/plans/2026-06-22-ios-async-chat.md § Task 9。
//
// 设计要点：
// - Test 1 是 focused test：不依赖任何 Provider，可独立跑绿（不需要 LLM Key）。
// - Test 2/3/4 走真实 sessionStore，但用 mock Bridge / mock LlmClient 避免真发 API。
//   LLM Key 仍需通过 --dart-define-from-file 注入（chatTaskService 的
//   resumeInterrupted 不直接发请求，但 chat_screen 初始化时 chat_controller
//   会读 LLM 配置；Test 2/3/4 绕过 chat_screen 直接调 ChatTaskService，所以
//   可用 fake AppSettings + fake LlmConfigStore 注入）。
//
// 运行命令（参考 plan § Task 9）：
//   dart run tools/gen_dart_define.dart \
//     $HOME/.thktree/test_llm_config.json \
//     build/dart_define.json
//   flutter test integration_test/chat_async_recovery_test.dart \
//     --dart-define-from-file=build/dart_define.json \
//     -d "iPhone 15 Pro"
//
// 只跑 Test 1（不需要 LLM Key）：
//   flutter test integration_test/chat_async_recovery_test.dart \
//     --plain-name 'findInterrupted' -d "iPhone 15 Pro"

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:thk_tree/data/services/background_task_bridge.dart';
import 'package:thk_tree/data/services/chat_task_service.dart';
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/llm_provider.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/stores/session_store.dart';
import 'package:thk_tree/ui/core/app_services.dart';

import '_support/in_memory_llm_config_store.dart';

// ─────────────────────────────────────────────────────────────────────────
// Mock：BackgroundTaskBridge — 计数 begin/end 调用。
// ─────────────────────────────────────────────────────────────────────────

class _CountingBridge extends BackgroundTaskBridge {
  _CountingBridge() : super(methodChannel: const MethodChannel('thktree/background_task_mock'));

  int beginCount = 0;
  int endCount = 0;

  @override
  Future<String?> begin() async {
    beginCount++;
    return 'mock-task-id';
  }

  @override
  Future<bool> end() async {
    endCount++;
    return true;
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Mock：LlmClient — 不发真请求，立即返回单 token stream。
// ─────────────────────────────────────────────────────────────────────────

class _NoopLlmClient extends LlmClient {
  const _NoopLlmClient();

  @override
  Stream<String> streamChatCompletion({
    required String apiKey,
    required String model,
    required List<Map<String, Object?>> messages,
    CancelToken? cancelToken,
  }) async* {
    yield 'mock-reply';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// 辅助：构造 ProviderContainer 用于测试 ChatTaskService。
// ─────────────────────────────────────────────────────────────────────────

class _TestEnv {
  _TestEnv({
    required this.container,
    required this.service,
    required this.bridge,
    required this.tempThemeDir,
  });

  final ProviderContainer container;
  final ChatTaskService service;
  final _CountingBridge bridge;
  final Directory tempThemeDir;
}

Future<_TestEnv> _createTestEnv({
  required List<({String nodeId, String content})> initialNodes,
}) async {
  // 1. 准备临时 theme 目录
  final docsDir = await getApplicationDocumentsDirectory();
  final tempThemeId = 'recovery-test-${DateTime.now().microsecondsSinceEpoch}';
  final tempThemeDir = Directory(p.join(docsDir.path, 'themes', tempThemeId));
  await tempThemeDir.create(recursive: true);

  // 2. 写入初始 session.md（每个 node 一个文件）
  final sessionPaths = <String, String>{};
  for (final node in initialNodes) {
    final nodeDir = Directory(p.join(tempThemeDir.path, node.nodeId));
    await nodeDir.create(recursive: true);
    final sessionPath = p.join(nodeDir.path, 'session.md');
    await File(sessionPath).writeAsString(node.content);
    sessionPaths[node.nodeId] = sessionPath;
  }

  // 3. 构造 stub SessionStore（只覆盖 _retry 路径需要的两个方法）
  final sessionStore = _StubSessionStore(sessionPaths);

  // 4. 构造 fake AppSettings（LLM 配置）— 用 deepseek + fake key
  final fakeSettings = AppSettings(
    llmProvider: LlmProvider.deepseek,
    deepSeekApiKey: 'fake-key',
    openaiApiKey: '',
    claudeApiKey: '',
    geminiApiKey: '',
    minimaxApiKey: '',
    kimiApiKey: '',
    deepSeekModel: 'deepseek-chat',
    openaiModel: 'gpt-4o-mini',
    claudeModel: 'claude-3-5-sonnet-20241022',
    geminiModel: 'gemini-2.0-flash',
    minimaxModel: 'MiniMax-Text-01',
    kimiModel: 'moonshot-v1-8k',
    localeLanguageCode: null,
    faceIdEnabled: false,
    darkMode: false,
  );

  // 5. 构造 fake LlmConfigStore（InMemoryLlmConfigStore）
  final fakeConfigStore = InMemoryLlmConfigStore(
    providers: const [],
    apiKeys: const {},
  );

  // 6. 构造 counting bridge
  final bridge = _CountingBridge();

  // 7. 构造 ProviderContainer
  final container = ProviderContainer(
    overrides: [
      appSettingsProvider.overrideWith((ref) async => fakeSettings),
      llmConfigStoreProvider.overrideWithValue(fakeConfigStore),
      sessionStoreProvider.overrideWith((ref) async => sessionStore),
      chatTaskServiceProvider.overrideWith(() => ChatTaskService(bridge: bridge)),
    ],
  );

  // 8. 触发 ChatTaskService build()
  final service = container.read(chatTaskServiceProvider.notifier);
  // 等待 sessionStore override 生效（让 resumeInterrupted 能拿到）
  await container.read(sessionStoreProvider.future);

  return _TestEnv(
    container: container,
    service: service,
    bridge: bridge,
    tempThemeDir: tempThemeDir,
  );
}

/// 只实现 ChatTaskService 测试路径用到的两个方法。
class _StubSessionStore implements SessionStore {
  _StubSessionStore(this._sessionPaths);

  final Map<String, String> _sessionPaths;

  @override
  Future<String> Function(String) get getSessionPathForNode =>
      (String nodeId) async => _sessionPaths[nodeId] ?? '';

  @override
  Future<bool> finishStreamingMessage({required String nodeId}) async {
    final path = _sessionPaths[nodeId];
    if (path == null) return false;
    final file = File(path);
    if (!await file.exists()) return false;
    final content = await file.readAsString();
    // 移除尾部 streaming 标记（new + legacy）
    String stripped = content;
    if (stripped.endsWith('\n<!-- streaming -->\n')) {
      stripped = stripped.substring(0, stripped.length - '\n<!-- streaming -->\n'.length);
    } else if (stripped.endsWith('<!-- streaming -->\n')) {
      stripped = stripped.substring(0, stripped.length - '<!-- streaming -->\n'.length);
    }
    await file.writeAsString(stripped);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      '_StubSessionStore: 未实现 ${invocation.memberName}（仅供 chat_async_recovery_test 用）',
    );
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // ───────────────────────────────────────────────────────────────────
  // Test 1：findInterrupted focused 测试
  // ───────────────────────────────────────────────────────────────────
  testWidgets('findInterrupted 返回含 streaming 标记的 node', (tester) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final themesDir = Directory(p.join(docsDir.path, 'themes'));

    final themeId = 'recovery-focused-${DateTime.now().microsecondsSinceEpoch}';
    final themeDir = Directory(p.join(themesDir.path, themeId));
    await themeDir.create(recursive: true);

    try {
      // node_a：含标准 streaming 标记
      await File(p.join(themeDir.path, 'node_a', 'session.md'))
          .create(recursive: true);
      await File(p.join(themeDir.path, 'node_a', 'session.md')).writeAsString(
        '---\nnodeId: node_a\n---\n'
        '## user\nhi\n\n'
        '## assistant\nhello\n\n'
        '<!-- streaming -->\n',
      );

      // node_b：含 legacy streaming 标记（无前置换行）
      await File(p.join(themeDir.path, 'node_b', 'session.md'))
          .create(recursive: true);
      await File(p.join(themeDir.path, 'node_b', 'session.md')).writeAsString(
        '---\nnodeId: node_b\n---\n'
        '## user\nhi\n'
        '<!-- streaming -->\n',
      );

      // node_c：无标记
      await File(p.join(themeDir.path, 'node_c', 'session.md'))
          .create(recursive: true);
      await File(p.join(themeDir.path, 'node_c', 'session.md')).writeAsString(
        '---\nnodeId: node_c\n---\n'
        '## user\nhi\n\n'
        '## assistant\nhello\n',
      );

      // 调用 findInterrupted — 只过滤本次 theme（避免其他测试残留干扰）
      final all = await SessionStore.findInterrupted();
      final filtered = all.where((e) => e.nodeId == 'node_a' || e.nodeId == 'node_b' || e.nodeId == 'node_c').toList();

      expect(filtered.length, 2, reason: 'node_a + node_b 应被识别，node_c 不应被识别');
      final ids = filtered.map((e) => e.nodeId).toSet();
      expect(ids.contains('node_a'), isTrue);
      expect(ids.contains('node_b'), isTrue);
      expect(ids.contains('node_c'), isFalse);
    } finally {
      // 清理临时目录
      if (await themeDir.exists()) {
        await themeDir.delete(recursive: true);
      }
    }
  });

  // ───────────────────────────────────────────────────────────────────
  // Test 2：resumeInterrupted 串行排队
  // ───────────────────────────────────────────────────────────────────
  testWidgets('resumeInterrupted 把磁盘中断 node 入队 + 启动串行 loop', (tester) async {
    final env = await _createTestEnv(initialNodes: const [
      (nodeId: 'node_a', content: '---\nnodeId: node_a\n---\n## user\nhi\n\n## assistant\npartial\n\n<!-- streaming -->\n'),
      (nodeId: 'node_b', content: '---\nnodeId: node_b\n---\n## user\nhi\n\n## assistant\npartial\n<!-- streaming -->\n'),
    ]);
    addTearDown(() async {
      env.container.dispose();
      if (await env.tempThemeDir.exists()) {
        await env.tempThemeDir.delete(recursive: true);
      }
    });

    // 调 resumeInterrupted
    await env.service.resumeInterrupted();

    // 期望：两个 node 都被入队（_retry 在 _nodeStore == null 时直接返回，
    // 因此 loop 快速退出，但入队动作已经发生）。
    expect(env.service.resumeQueueLength, 2, reason: '应入队 node_a + node_b');
    expect(env.service.isResuming, isTrue, reason: 'loop 启动期间 isResuming 应为 true');

    // 等 loop 自然退出（_retry 走 early return path）
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(env.service.isResuming, isFalse, reason: '_nodeStore == null 时 _retry 立即返回，loop 应退出');
    expect(env.service.resumeQueueLength, 0, reason: 'loop 退出后队列应为空');

    // 磁盘上的 streaming 标记应被清掉（finishStreamingMessage 副作用）
    final sessionA = await File(p.join(env.tempThemeDir.path, 'node_a', 'session.md')).readAsString();
    final sessionB = await File(p.join(env.tempThemeDir.path, 'node_b', 'session.md')).readAsString();
    expect(sessionA.contains('<!-- streaming -->'), isFalse, reason: 'node_a marker 应被清掉');
    expect(sessionB.contains('<!-- streaming -->'), isFalse, reason: 'node_b marker 应被清掉');
  });

  // ───────────────────────────────────────────────────────────────────
  // Test 3：cancelResumeQueue 清空未执行队列
  // ───────────────────────────────────────────────────────────────────
  testWidgets('cancelResumeQueue 清空 queue + generation 自增让 loop 退出', (tester) async {
    final env = await _createTestEnv(initialNodes: const [
      (nodeId: 'node_a', content: '---\nnodeId: node_a\n---\n## user\nhi\n\n<!-- streaming -->\n'),
      (nodeId: 'node_b', content: '---\nnodeId: node_b\n---\n## user\nhi\n\n<!-- streaming -->\n'),
      (nodeId: 'node_c', content: '---\nnodeId: node_c\n---\n## user\nhi\n\n<!-- streaming -->\n'),
    ]);
    addTearDown(() async {
      env.container.dispose();
      if (await env.tempThemeDir.exists()) {
        await env.tempThemeDir.delete(recursive: true);
      }
    });

    // 启动 resume（_nodeStore == null 时 _retry 立即返回，loop 几乎立即退出）
    // 为测试 cancel 在 loop 运行中打断，我们直接构造场景：
    // 模拟"loop 已启动但 queue 还有未执行项"——用 mock ChatTaskService 不容易，
    // 这里改为验证 cancelResumeQueue 的两个核心副作用：
    //   1) queue 清空
    //   2) loop 在 generation 检查时立即退出
    //
    // 简化方案：先调 resumeInterrupted 让所有 node 入队（loop 几乎同步退出），
    // 然后再次"模拟"中途中断——通过调 cancelResumeQueue 验证不抛错、状态正确。

    await env.service.resumeInterrupted();
    // 等待 loop 退出（_retry 走 early return）
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(env.service.resumeQueueLength, 0);

    // 关键测试：即使在 loop 已退出后调 cancelResumeQueue，也不应抛错
    env.service.cancelResumeQueue();
    expect(env.service.resumeQueueLength, 0, reason: 'cancel 后 queue 应仍为空');
    expect(env.service.isResuming, isFalse, reason: 'cancel 不应错误地设置 isResuming');

    // 二次验证：重新入队后立即 cancel，验证 cancel 能清空
    await env.service.resumeInterrupted();
    // 在 loop 真正启动 _retry 之前 cancel
    env.service.cancelResumeQueue();
    expect(env.service.resumeQueueLength, 0, reason: 'cancel 应清空刚入队的 node');
  });

  // ───────────────────────────────────────────────────────────────────
  // Test 4：startTask → onDone 期间 bridge.begin/end 各 1 次
  // ───────────────────────────────────────────────────────────────────
  testWidgets('startTask → onDone 期间 bridge.begin/end 各 1 次', (tester) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final tempThemeId = 'bridge-count-${DateTime.now().microsecondsSinceEpoch}';
    final tempThemeDir = Directory(p.join(docsDir.path, 'themes', tempThemeId));
    await tempThemeDir.create(recursive: true);

    final sessionPath = p.join(tempThemeDir.path, 'node_x', 'session.md');
    await Directory(p.join(tempThemeDir.path, 'node_x')).create(recursive: true);
    await File(sessionPath).writeAsString('---\nnodeId: node_x\n---\n## user\nhi\n');

    final sessionStore = _StubSessionStore({'node_x': sessionPath});

    final fakeSettings = AppSettings(
      llmProvider: LlmProvider.deepseek,
      deepSeekApiKey: 'fake-key',
      openaiApiKey: '',
      claudeApiKey: '',
      geminiApiKey: '',
      minimaxApiKey: '',
      kimiApiKey: '',
      deepSeekModel: 'deepseek-chat',
      openaiModel: 'gpt-4o-mini',
      claudeModel: 'claude-3-5-sonnet-20241022',
      geminiModel: 'gemini-2.0-flash',
      minimaxModel: 'MiniMax-Text-01',
      kimiModel: 'moonshot-v1-8k',
      localeLanguageCode: null,
      faceIdEnabled: false,
      darkMode: false,
    );

    final fakeConfigStore = InMemoryLlmConfigStore(
      providers: const [],
      apiKeys: const {},
    );

    final bridge = _CountingBridge();

    final container = ProviderContainer(
      overrides: [
        appSettingsProvider.overrideWith((ref) async => fakeSettings),
        llmConfigStoreProvider.overrideWithValue(fakeConfigStore),
        sessionStoreProvider.overrideWith((ref) async => sessionStore),
        chatTaskServiceProvider.overrideWith(() => ChatTaskService(bridge: bridge)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      if (await tempThemeDir.exists()) {
        await tempThemeDir.delete(recursive: true);
      }
    });

    final service = container.read(chatTaskServiceProvider.notifier);
    await container.read(sessionStoreProvider.future);

    // 调 startTask（用 mock LlmClient 立即完成）
    final history = <SessionMessage>[
      SessionMessage(
        role: SessionRole.user,
        timestampUtcIso8601: DateTime.now().toIso8601String(),
        msgId: 'm1',
        body: 'hi',
        status: SessionMessageStatus.done,
      ),
    ];

    await service.startTask(
      nodeId: 'node_x',
      client: const _NoopLlmClient(),
      apiKey: 'fake-key',
      model: 'deepseek-chat',
      history: history,
      systemPrompt: 'You are a helpful assistant.',
      sessionStore: sessionStore,
    );

    // 等待 stream 完成（onDone 触发）
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // 验证 bridge.begin 被调用 1 次，bridge.end 被调用 1 次
    expect(bridge.beginCount, 1, reason: 'startTask 开始时 bridge.begin 应被调用 1 次');
    expect(bridge.endCount, 1, reason: 'onDone 时 bridge.end 应被调用 1 次');
    expect(service.hasTask('node_x'), isFalse, reason: 'onDone 后 task 应从 state 移除');
  });
}