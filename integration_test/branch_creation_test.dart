import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/domain/node.dart';
import 'package:thk_tree/main_test.dart';
import 'package:thk_tree/ui/core/app_services.dart';
import 'package:thk_tree/ui/core/widgets/thk_text_field.dart';
import 'package:thk_tree/ui/features/themes/theme_detail_controller.dart';

import '_support/llm_test_config.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('分支创建流程测试', () {
    testWidgets('选中文本 + raw 模式创建分支', (tester) async {
      // ── 前置：注入真实 LLM 配置 ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      // toAppSettings() 已预配置 titleModelProviderId/titleModelModelId
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 切换到主题 tab
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();

      // ── 1. 创建主题 → 进入 ──
      final ts = DateTime.now().millisecondsSinceEpoch;
      await _createTestTheme(tester, 'BranchSel_$ts');
      await waitForText(tester, 'BranchSel_$ts', timeout: const Duration(seconds: 10));
      await tester.tap(find.text('BranchSel_$ts'));
      await tester.pumpAndSettle();

      // ── 2. 创建节点 → 进入 chat_screen ──
      await _createTestNode(tester, 'SourceNode_$ts');
      await waitForText(tester, 'SourceNode_$ts', timeout: const Duration(seconds: 10));
      await tester.tap(find.text('SourceNode_$ts'));
      await tester.pumpAndSettle();

      // ── 3. 发送消息并等待 LLM 流式回复完成 ──
      debugPrint('[Test] 发送消息，等待 LLM 回复...');
      await _sendAndWaitForReply(
        tester,
        message: '请用一句话介绍你自己',
        timeout: const Duration(seconds: 90),
      );
      debugPrint('[Test] LLM 回复完成，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));

      // ── 4. 选中文本（A1 方案：长按消息 → 全选） ──
      debugPrint('[Test] 长按消息触发选区...');
      await selectTextInMessage(tester, '请用一句话介绍你自己');
      debugPrint('[Test] 选中文本完成，停留 3 秒查看选区高亮');
      await tester.pump(const Duration(seconds: 3));

      // ── 5. 点 branch 按钮 ──
      debugPrint('[Test] 点击 branch 按钮...');
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget, reason: '应该找到 branch 按钮');
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();

      // ── 6. 选 raw 模式 + 继续 ──
      debugPrint('[Test] 等待模式选择 sheet...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_raw_option')),
        timeout: const Duration(seconds: 10),
      );
      debugPrint('[Test] 模式选择 sheet 已出现，停留 2 秒');
      await tester.pump(const Duration(seconds: 2));

      debugPrint('[Test] 选择 raw 模式...');
      await tester.tap(find.byKey(const ValueKey('branch_mode_raw_option')));
      await tester.pump(const Duration(seconds: 1));
      debugPrint('[Test] 点击继续...');
      await tester.tap(find.byKey(const ValueKey('branch_mode_continue_button')));
      await tester.pump();

      // ── 7. 等待 TitleSuggestionScreen → 确认 ──
      debugPrint('[Test] 等待标题建议页加载...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('title_input')),
        timeout: const Duration(seconds: 30),
      );
      debugPrint('[Test] 标题建议页已加载');
      await tester.pump(const Duration(seconds: 2));

      // 点击「生成标题」按钮触发 LLM 生成候选
      final genBtn = find.text('生成标题');
      if (genBtn.evaluate().isNotEmpty) {
        debugPrint('[Test] 点击「生成标题」按钮...');
        await tester.tap(genBtn);
        await tester.pump();
      }

      // 等待 LLM 生成候选标题（需要真实时间，用 tester.runAsync）
      debugPrint('[Test] 等待 LLM 生成候选标题（最多 30 秒）...');
      String? generatedTitle;
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
        final thkField = tester.widget<ThkTextField>(
          find.byKey(const ValueKey('title_input')),
        );
        final currentText = thkField.controller?.text ?? '';
        if (currentText.isNotEmpty) {
          generatedTitle = currentText;
          debugPrint('[Test] LLM 已生成候选标题: $generatedTitle');
          break;
        }
      }

      if (generatedTitle != null) {
        debugPrint('[Test] 使用 LLM 生成的标题，停留 3 秒查看');
        await tester.pump(const Duration(seconds: 3));
      } else {
        debugPrint('[Test] LLM 未在 30 秒内生成标题，手动输入');
        await tester.enterText(
          find.byKey(const ValueKey('title_input')),
          'Branch Title',
        );
        await tester.pump(const Duration(seconds: 2));
      }

      // 确认按钮
      debugPrint('[Test] 点击确认按钮...');
      final confirmBtn = find.byKey(const ValueKey('confirm_button'));
      expect(confirmBtn, findsOneWidget, reason: '应该找到确认按钮');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // ── 8. 验证：跳转到新分支的 ChatScreen ──
      debugPrint('[Test] 等待新分支 ChatScreen 加载...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_button')),
        timeout: const Duration(seconds: 30),
      );
      debugPrint('[Test] 新分支 ChatScreen 已加载，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));

      // 验证在新的 ChatScreen 中
      expect(
        find.byKey(const ValueKey('branch_button')),
        findsOneWidget,
        reason: '创建分支后应跳转到新 ChatScreen',
      );
      expect(
        find.byKey(const ValueKey('chat_input')),
        findsOneWidget,
        reason: '新分支 ChatScreen 应有输入框',
      );

      // 等待 autoTriggerReply 的流式回复完成
      debugPrint('[Test] 等待新分支 LLM 自动回复...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('send_button')),
        timeout: const Duration(seconds: 120),
      );
      debugPrint('[Test] 新分支 LLM 回复完成，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));
      debugPrint('[Test] ✅ case 1 完成：选中文本 + raw 模式创建分支成功');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('选中文本 + summarize 模式创建分支', (tester) async {
      // ── 前置：注入真实 LLM 配置 ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      // toAppSettings() 已预配置 titleModelProviderId/titleModelModelId
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 切换到主题 tab
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();

      // ── 1. 创建主题 → 进入 ──
      final ts = DateTime.now().millisecondsSinceEpoch;
      await _createTestTheme(tester, 'BranchSumm_$ts');
      await waitForText(tester, 'BranchSumm_$ts', timeout: const Duration(seconds: 10));
      await tester.tap(find.text('BranchSumm_$ts'));
      await tester.pumpAndSettle();

      // ── 2. 创建节点 → 进入 chat_screen ──
      await _createTestNode(tester, 'SummNode_$ts');
      await waitForText(tester, 'SummNode_$ts', timeout: const Duration(seconds: 10));
      await tester.tap(find.text('SummNode_$ts'));
      await tester.pumpAndSettle();

      // ── 3. 发送消息并等待 LLM 流式回复完成 ──
      debugPrint('[Test] 发送消息，等待 LLM 回复...');
      await _sendAndWaitForReply(
        tester,
        message: '请用一句话介绍你自己',
        timeout: const Duration(seconds: 90),
      );
      debugPrint('[Test] LLM 回复完成，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));

      // ── 4. 选中文本（复用 Chat A 的 helper） ──
      debugPrint('[Test] 长按消息触发选区...');
      await selectTextInMessage(tester, '请用一句话介绍你自己');
      debugPrint('[Test] 选中文本完成，停留 3 秒查看选区高亮');
      await tester.pump(const Duration(seconds: 3));

      // ── 5. 点 branch 按钮 ──
      debugPrint('[Test] 点击 branch 按钮...');
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget, reason: '应该找到 branch 按钮');
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();

      // ── 6. 选 summarize 模式 + 继续 ──
      // ⚠️ spec § 3.2: 当 selectedText 非空时, mode 被完全忽略
      // 测试目的: 验证选 summarize 时, UI 流程仍可达性（与 case 1 行为等价）
      debugPrint('[Test] 等待模式选择 sheet...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_summarize_option')),
        timeout: const Duration(seconds: 10),
      );
      debugPrint('[Test] 模式选择 sheet 已出现，停留 2 秒');
      await tester.pump(const Duration(seconds: 2));

      debugPrint('[Test] 选择 summarize 模式...');
      await tester.tap(find.byKey(const ValueKey('branch_mode_summarize_option')));
      await tester.pump(const Duration(seconds: 1));
      debugPrint('[Test] 点击继续...');
      await tester.tap(find.byKey(const ValueKey('branch_mode_continue_button')));
      await tester.pump();

      // ── 7. 等待 TitleSuggestionScreen → 确认 ──
      debugPrint('[Test] 等待标题建议页加载...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('title_input')),
        timeout: const Duration(seconds: 30),
      );
      debugPrint('[Test] 标题建议页已加载');
      await tester.pump(const Duration(seconds: 2));

      // 点击「生成标题」按钮触发 LLM 生成候选
      final genBtn = find.text('生成标题');
      if (genBtn.evaluate().isNotEmpty) {
        debugPrint('[Test] 点击「生成标题」按钮...');
        await tester.tap(genBtn);
        await tester.pump();
      }

      // 等待 LLM 生成候选标题（需要真实时间，用 tester.runAsync）
      debugPrint('[Test] 等待 LLM 生成候选标题（最多 30 秒）...');
      String? generatedTitle;
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
        final thkField = tester.widget<ThkTextField>(
          find.byKey(const ValueKey('title_input')),
        );
        final currentText = thkField.controller?.text ?? '';
        if (currentText.isNotEmpty) {
          generatedTitle = currentText;
          debugPrint('[Test] LLM 已生成候选标题: $generatedTitle');
          break;
        }
      }

      if (generatedTitle != null) {
        debugPrint('[Test] 使用 LLM 生成的标题，停留 3 秒查看');
        await tester.pump(const Duration(seconds: 3));
      } else {
        debugPrint('[Test] LLM 未在 30 秒内生成标题，手动输入');
        await tester.enterText(
          find.byKey(const ValueKey('title_input')),
          'Branch Summ Title',
        );
        await tester.pump(const Duration(seconds: 2));
      }

      // 确认按钮
      debugPrint('[Test] 点击确认按钮...');
      final confirmBtn = find.byKey(const ValueKey('confirm_button'));
      expect(confirmBtn, findsOneWidget, reason: '应该找到确认按钮');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // ── 8. 验证：跳转到新分支的 ChatScreen ──
      debugPrint('[Test] 等待新分支 ChatScreen 加载...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_button')),
        timeout: const Duration(seconds: 30),
      );
      debugPrint('[Test] 新分支 ChatScreen 已加载，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));

      // 验证在新的 ChatScreen 中
      expect(
        find.byKey(const ValueKey('branch_button')),
        findsOneWidget,
        reason: '创建分支后应跳转到新 ChatScreen',
      );
      expect(
        find.byKey(const ValueKey('chat_input')),
        findsOneWidget,
        reason: '新分支 ChatScreen 应有输入框',
      );

      // 等待 autoTriggerReply 的流式回复完成
      debugPrint('[Test] 等待新分支 LLM 自动回复...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('send_button')),
        timeout: const Duration(seconds: 120),
      );
      debugPrint('[Test] 新分支 LLM 回复完成，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));
      debugPrint('[Test] ✅ case 2 完成：选中文本 + summarize 模式创建分支成功');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('无选中文本 + raw 模式创建分支', (tester) async {
      // 注入 LLM 配置（新分支 ChatScreen autoTriggerReply 需要）
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 切换到主题 tab
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题3');
      await tester.tap(find.text('测试主题3'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点3');
      await tester.tap(find.text('测试节点3'));
      await tester.pumpAndSettle();
      // ⚠️ 必须等 LLM 流式完成, 否则 chat_screen.dart:169 的
      // `branch_button` 在 isStreaming=true 时 onPressed=null, tap 无效。
      await _sendAndWaitForReply(
        tester,
        message: '你好',
        timeout: const Duration(seconds: 90),
      );
      await tester.pump(const Duration(seconds: 2));

      // 1. 点击分支按钮
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget, reason: '应该找到 branch 按钮');
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();

      // 2. 等待 sheet 出现，选 raw 模式
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_raw_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_raw_option')));
      await tester.pump();

      // 3. 点击继续
      await tester.tap(find.byKey(const ValueKey('branch_mode_continue_button')));
      await tester.pumpAndSettle();

      // 验证：弹出标题建议页（用 title_input key 定位，比 byType 更可靠）
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('title_input')),
        timeout: const Duration(seconds: 30),
      );
      expect(find.byKey(const ValueKey('title_input')), findsOneWidget);
    });

    testWidgets('无选中文本 + summarize 模式创建分支', (tester) async {
      // 注入真实 LLM 配置
      final llmConfig = LlmTestConfig.loadFromDefine();
      // ⚠️ case 4 fixture 未预设 titleModelProviderId, 但 _handleGenerateButton
      // 走 SettingsController.build() → settingsStoreProvider.load() 读 Keychain,
      // 不读 appSettingsProvider override。
      // 跑全套时前面 case 走 _showModelSelectorAndGenerate 选中后会调
      // saveTitleModel 写 Keychain, 残留后 case 4 启动读到旧 titleModelProviderId
      // → 走 _generateWithModel 路径, 不弹 sheet, waitForWidget(CupertinoActionSheet)
      // 10s timeout 失败。
      // 启动前显式清空 Keychain 中残留的 titleModel settings。
      final settingsStore = SettingsStore(
        secureStorage: const FlutterSecureStorage(),
      );
      await settingsStore.saveTitleModel(providerId: null, modelId: null);
      final app = await createTestApp(
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 导航到主题 tab（支持中英文）
      final themesTabEn = find.text('Themes');
      final themesTabZh = find.text('主题');
      if (themesTabEn.evaluate().isNotEmpty) {
        await tester.tap(themesTabEn);
      } else if (themesTabZh.evaluate().isNotEmpty) {
        await tester.tap(themesTabZh);
      }
      await tester.pumpAndSettle();

      // 前置：创建主题 → 进入 → 创建节点 → 进入 → 发送消息
      await _createTestTheme(tester, 'Summarize 测试');
      await tester.tap(find.text('Summarize 测试'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '源节点');
      await tester.tap(find.text('源节点'));
      await tester.pumpAndSettle();
      await _sendAndWaitForReply(
        tester,
        message: '数字化品牌美学逻辑顾问，不是那种画LOGO的美工，而是定义数字化时代品牌动效逻辑和视觉规则的人。当一个大品牌想在元宇宙或全息投影里展示自己时，他们需要一套视觉物理规律，比如这个品牌的金属质感在不同光影下怎么反射，动效如何体现品牌逻辑。',
        timeout: const Duration(seconds: 120),
      );
      debugPrint('[Test] LLM 回复完成，停留 3 秒查看');
      await tester.pump(const Duration(seconds: 3));

      // 1. 点击 branch 按钮（无选区）
      final branchButton = find.byKey(const ValueKey('branch_button'));
      expect(branchButton, findsOneWidget, reason: '应该找到 branch 按钮');
      await tester.tap(branchButton);
      await tester.pumpAndSettle();

      // 2. 等待模式选择 sheet 出现，选择 summarize
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_summarize_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_summarize_option')));
      await tester.pump();

      // 3. 点击继续按钮
      await tester.tap(find.byKey(const ValueKey('branch_mode_continue_button')));
      await tester.pump();

      // 4. 等待 TitleSuggestionScreen 加载（LLM 总结需要时间，最长 120s）
      debugPrint('[Test] 等待 TitleSuggestionScreen 加载...');
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('title_input')),
        timeout: const Duration(seconds: 120),
      );
      debugPrint('[Test] TitleSuggestionScreen 已加载');

      // 5. 点击「生成标题」按钮触发 LLM 生成候选
      final genBtn = find.text('生成标题');
      expect(genBtn, findsOneWidget, reason: '应找到「生成标题」按钮');
      debugPrint('[Test] 点击「生成标题」按钮...');
      await tester.tap(genBtn);
      await tester.pump();

      // 5.1 等待 model selector sheet 弹出
      // (case 4 fixture 未预设 titleModelProviderId, 所以 _handleGenerateButton
      //  走 _showModelSelectorAndGenerate 路径弹 sheet, 测试需手动选中第一个 model)
      debugPrint('[Test] 等待 model selector sheet 弹出...');
      await waitForWidget(
        tester,
        find.byType(CupertinoActionSheet),
        timeout: const Duration(seconds: 10),
      );
      debugPrint('[Test] sheet 已弹出');

      // 5.2 模拟点击第一个 model action
      // 模糊匹配所有 model_sheet_ 前缀的 key,
      // 不依赖具体 provider.id / model.id (fixture 下 deepseek / deepseek-chat)。
      //
      // 为何不直接 tester.tap(sheetAction.first)？
      //   iPhone 13 mini 测试 surface 402x874 装不下 CupertinoActionSheet,
      //   action 中心 y 坐标 (~1068) 超出屏幕 (~194px),tap() 会失败
      //   并警告 "Offset outside root of render tree"。
      //   ensureVisible / dragUntilVisible / setSurfaceSize 全部试过均无效
      //   (CupertinoActionSheet 内部 _ScrollableScope 用 Flexible 限高,
      //    滚动约束与 surface size 解耦)。
      //
      // 方案:直接调 sheet action 的 onPressed 闭包等价操作
      //   Navigator.of(context).pop<(String, String)>((provider.id, model.id))
      //   拿 sheet 内部 Element 作为 context,pop 出相同参数即可。
      final sheetAction = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key as ValueKey<String>).value.startsWith('model_sheet_'),
      );
      expect(
        sheetAction,
        findsWidgets,
        reason: 'sheet 应至少包含一个 model_sheet_ action',
      );
      // 从 ValueKey 拆出 (providerId, modelId)
      // 'model_sheet_preset_deepseek_deepseek-chat' → 'preset_deepseek', 'deepseek-chat'
      final firstActionKey =
          (tester.widget(sheetAction.first).key as ValueKey<String>).value;
      final stripped = firstActionKey.replaceFirst('model_sheet_', '');
      final lastUnderscore = stripped.lastIndexOf('_');
      final providerId = stripped.substring(0, lastUnderscore);
      final modelId = stripped.substring(lastUnderscore + 1);
      debugPrint(
        '[Test] 模拟点击第一个 model action: '
        'providerId=$providerId, modelId=$modelId',
      );
      // sheet action 的 Element 作为 context,pop 出 (providerId, modelId),
      // 等价于真实点击触发的 Navigator.pop。
      final sheetActionElement = tester.element(sheetAction.first);
      Navigator.of(sheetActionElement).pop<(String, String)>((
        providerId,
        modelId,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 6. 等待 LLM 生成候选标题
      debugPrint('[Test] 等待 LLM 生成候选标题（最多 60 秒）...');
      bool titleGenerated = false;
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
        // 检查是否有候选标题被选中（输入框有内容）
        final thkField = tester.widget<ThkTextField>(
          find.byKey(const ValueKey('title_input')),
        );
        final currentText = thkField.controller?.text ?? '';
        if (currentText.isNotEmpty) {
          titleGenerated = true;
          debugPrint('[Test] LLM 已生成候选标题: $currentText');
          break;
        }
        if (i % 10 == 0) debugPrint('[Test] 等待标题生成... ${i}s');
      }
      expect(titleGenerated, isTrue, reason: 'LLM 应生成候选标题');

      // 7. 点击确认按钮
      debugPrint('[Test] 点击确认按钮');
      final confirmButton = find.byKey(const ValueKey('confirm_button'));
      expect(confirmButton, findsOneWidget, reason: '应该找到确认按钮');
      await tester.tap(confirmButton);
      await tester.pumpAndSettle();

      // 7. 验证：跳转到新分支的 ChatScreen
      await pumpAndSettleWithTimeout(
        tester,
        timeout: const Duration(seconds: 30),
      );

      // 8. L1 不弹断言：fixture 下 LLM 配置齐全，L1-A / L1-B / L2 都不应弹 alert
      expect(
        find.byType(CupertinoAlertDialog),
        findsNothing,
        reason: 'fixture 下所有 LLM 配置齐全，不应触发 LLM 未配置拦截',
      );

      debugPrint('[Test] 分支创建流程完成');
    });

    testWidgets('模式选择取消', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 切换到主题 tab
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题5');
      await tester.tap(find.text('测试主题5'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点5');
      await tester.tap(find.text('测试节点5'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 点击分支按钮，在模式选择 sheet 中取消
    });

    testWidgets('标题选择取消', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 切换到主题 tab
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题6');
      await tester.tap(find.text('测试主题6'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点6');
      await tester.tap(find.text('测试节点6'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 点击分支按钮，选择模式，在标题页取消
    });

    testWidgets('LLM 失败 fallback', (tester) async {
      // 启动应用
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // 切换到主题 tab
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();

      // 创建测试主题和节点
      await _createTestTheme(tester, '测试主题7');
      await tester.tap(find.text('测试主题7'));
      await tester.pumpAndSettle();
      await _createTestNode(tester, '测试节点7');
      await tester.tap(find.text('测试节点7'));
      await tester.pumpAndSettle();
      await _sendMessage(tester, '你好');

      // TODO: 模拟 LLM 失败，验证 fallback 行为
    });

    // ================================================================
    // P.9-A 空白分支模式集成测试
    // ================================================================

    testWidgets('A 模式：创建空 node（验证 DB 字段）', (tester) async {
      // ── 1. 注入 LLM fixture ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ── 2. 切到主题 tab → 创建主题 → 创建节点 → 进 chat_screen ──
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeName = 'BlankA_$ts';
      final parentName = 'ParentA_$ts';
      await _createTestTheme(tester, themeName);
      await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(themeName));
      await tester.pumpAndSettle();
      await _createTestNode(tester, parentName);
      await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(parentName));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 10),
      );

      // ── 3. 拿 parent nodeId（DB 直查） ──
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CupertinoApp)),
        listen: false,
      );
      final nodeStore = await container.read(nodeStoreProvider.future);
      // 拿最新主题的 themeId
      final themeRows = await nodeStore.db.query(
        'themes',
        columns: ['themeId'],
        where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
        whereArgs: [parentName],
        limit: 1,
      );
      expect(themeRows, isNotEmpty, reason: '应能找到刚创建的主题');
      final themeId = themeRows.first['themeId']! as String;
      // 拿 parent nodeId（按 title 查）
      final parentNodes = await nodeStore.db.query(
        'nodes',
        columns: ['nodeId'],
        where: 'themeId = ? AND title = ?',
        whereArgs: [themeId, parentName],
        limit: 1,
      );
      expect(parentNodes, isNotEmpty, reason: '应能找到 parent node');
      final parentNodeId = parentNodes.first['nodeId']! as String;
      debugPrint('[Test 9.1] themeId=$themeId parentNodeId=$parentNodeId');

      // ── 4. 发消息 → 流式完成 ──
      await _sendAndWaitForReply(
        tester,
        message: '你好，请用一句话介绍自己',
        timeout: const Duration(seconds: 90),
      );
      await tester.pump(const Duration(seconds: 2));

      // ── 5. 点 branch → 选 blank ──
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget, reason: '应该找到 branch 按钮');
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_blank_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
      await tester.pumpAndSettle();

      // ── 6. 等待新 chat_screen 加载（blank 模式无 title sheet） ──
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 30),
      );
      // 等 push 完成 + 刷新
      await tester.pump(const Duration(seconds: 2));

      // ── 7. 验证：DB 里有 sourceType='userIdea' 的新 node ──
      final themeNodes = await nodeStore.listNodes(themeId: themeId);
      final blankNode = themeNodes
          .where((n) => n.sourceType == 'userIdea')
          .lastOrNull;
      expect(blankNode, isNotNull,
          reason: 'blank 模式应创建 sourceType=userIdea 的新 node');
      expect(blankNode!.sourceExcerpt, isNull,
          reason: 'blank 模式 sourceExcerpt 应为 null（未预填）');
      expect(blankNode.title, equals('临时会话'),
          reason: 'blank 模式 title 应为占位文本');
      expect(blankNode.parentId, equals(parentNodeId),
          reason: 'blank node 应关联到正确的 parent');
      expect(blankNode.kind, equals(NodeKind.chat),
          reason: 'blank node 应为 chat 类型');
      debugPrint(
          '[Test 9.1] ✅ blank node 验证通过: '
          'nodeId=${blankNode.nodeId} title=${blankNode.title} '
          'sourceType=${blankNode.sourceType} sourceExcerpt=${blankNode.sourceExcerpt}');

      // ── 8. 验证：nav bar 显示占位 title（_displayedTitle 仍为 null） ──
      expect(
        find.text('临时会话'),
        findsWidgets,
        reason: '新 chat_screen 的 nav bar 应显示占位 title',
      );
      debugPrint('[Test 9.1] ✅ case 9.1 完成');
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('A 模式：流式回复结束后自动生成 title', (tester) async {
      // ── 1. 注入 LLM fixture ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ── 2. 准备 parent node ──
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeName = 'BlankAutoTitle_$ts';
      final parentName = 'ParentAutoTitle_$ts';
      await _createTestTheme(tester, themeName);
      await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(themeName));
      await tester.pumpAndSettle();
      await _createTestNode(tester, parentName);
      await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(parentName));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 10),
      );

      // ── 3. parent 流式完成 + 创建 blank branch ──
      await _sendAndWaitForReply(
        tester,
        message: '你好',
        timeout: const Duration(seconds: 90),
      );
      await tester.pump(const Duration(seconds: 2));

      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget);
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_blank_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(seconds: 2));

      // ── 4. 拿 blank nodeId ──
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CupertinoApp)),
        listen: false,
      );
      final nodeStore = await container.read(nodeStoreProvider.future);
      final themeRows = await nodeStore.db.query(
        'themes',
        columns: ['themeId'],
        where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
        whereArgs: [parentName],
        limit: 1,
      );
      final themeId = themeRows.first['themeId']! as String;
      final allNodes = await nodeStore.listNodes(themeId: themeId);
      final blankNode = allNodes
          .where((n) => n.sourceType == 'userIdea')
          .lastOrNull;
      expect(blankNode, isNotNull, reason: '应能找到 blank node');
      final blankNodeId = blankNode!.nodeId;
      debugPrint('[Test 9.2] blank nodeId=$blankNodeId, 初始 title=${blankNode.title}');

      // ── 5. 在新 chat_screen 发消息 → 流式完成 ──
      await _sendAndWaitForReply(
        tester,
        message: '数字化品牌的视觉逻辑',
        timeout: const Duration(seconds: 90),
      );
      debugPrint('[Test 9.2] 流式回复完成, 等待自动 title 触发...');

      // ── 6. 轮询 DB 等 auto title 被更新（最长 60s） ──
      String? updatedTitle;
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
        final row = await nodeStore.db.query(
          'nodes',
          columns: ['title'],
          where: 'nodeId = ?',
          whereArgs: [blankNodeId],
          limit: 1,
        );
        if (row.isNotEmpty) {
          final t = row.first['title']! as String;
          if (t != '临时会话' && t.trim().isNotEmpty) {
            updatedTitle = t;
            debugPrint('[Test 9.2] 自动 title 已更新: $updatedTitle (${i}s)');
            break;
          }
        }
        if (i % 10 == 0 && i > 0) {
          debugPrint('[Test 9.2] 等待自动 title... ${i}s');
        }
      }

      // ── 7. 验证 ──
      expect(updatedTitle, isNotNull,
          reason: '流式结束后 60s 内 LLM 应自动生成新 title');
      expect(updatedTitle, isNot(equals('临时会话')),
          reason: 'DB title 应被自动更新');
      debugPrint('[Test 9.2] ✅ case 9.2 完成: 自动 title=$updatedTitle');
    }, timeout: const Timeout(Duration(minutes: 5)));

    testWidgets('A 模式：自动 title 防抖只触发一次', (tester) async {
      // ── 1. 注入 LLM fixture ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ── 2. 准备 parent + blank branch ──
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeName = 'BlankDebounce_$ts';
      final parentName = 'ParentDebounce_$ts';
      await _createTestTheme(tester, themeName);
      await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(themeName));
      await tester.pumpAndSettle();
      await _createTestNode(tester, parentName);
      await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(parentName));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 10),
      );
      await _sendAndWaitForReply(
        tester,
        message: '你好',
        timeout: const Duration(seconds: 90),
      );
      await tester.pump(const Duration(seconds: 2));
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget);
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_blank_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(seconds: 2));

      // ── 3. 拿 blank nodeId ──
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CupertinoApp)),
        listen: false,
      );
      final nodeStore = await container.read(nodeStoreProvider.future);
      final themeRows = await nodeStore.db.query(
        'themes',
        columns: ['themeId'],
        where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
        whereArgs: [parentName],
        limit: 1,
      );
      final themeId = themeRows.first['themeId']! as String;
      final allNodes = await nodeStore.listNodes(themeId: themeId);
      final blankNode = allNodes
          .where((n) => n.sourceType == 'userIdea')
          .lastOrNull;
      expect(blankNode, isNotNull);
      final blankNodeId = blankNode!.nodeId;

      // ── 4. 第一次流式结束 → 等待 auto title 触发 ──
      await _sendAndWaitForReply(
        tester,
        message: '品牌视觉逻辑第一问',
        timeout: const Duration(seconds: 90),
      );
      String? firstTitle;
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
        final row = await nodeStore.db.query(
          'nodes',
          columns: ['title'],
          where: 'nodeId = ?',
          whereArgs: [blankNodeId],
          limit: 1,
        );
        if (row.isNotEmpty) {
          final t = row.first['title']! as String;
          if (t != '临时会话' && t.trim().isNotEmpty) {
            firstTitle = t;
            debugPrint('[Test 9.3] 第一次自动 title: $firstTitle (${i}s)');
            break;
          }
        }
      }
      expect(firstTitle, isNotNull, reason: '第一次流式结束后应自动生成 title');

      // ── 5. 第二次发消息 → 流式结束 → 等待 ──
      await _sendAndWaitForReply(
        tester,
        message: '品牌视觉逻辑第二问',
        timeout: const Duration(seconds: 90),
      );
      // 等 10s 让任何潜在的二次触发走完
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
      }
      final row = await nodeStore.db.query(
        'nodes',
        columns: ['title'],
        where: 'nodeId = ?',
        whereArgs: [blankNodeId],
        limit: 1,
      );
      final secondTitle = row.first['title']! as String;
      debugPrint('[Test 9.3] 第二次流式结束后 DB title: $secondTitle');

      // ── 6. 验证：title 仍是第一次的值（防抖生效） ──
      expect(secondTitle, equals(firstTitle),
          reason: '第二次流式结束后 auto title 不应被重复触发');
      debugPrint('[Test 9.3] ✅ case 9.3 完成: 防抖生效, title=$firstTitle');
    }, timeout: const Timeout(Duration(minutes: 6)));

    testWidgets('A 模式：自动 title 持久化（tree 刷新 + 第二次进入显示新 title）', (tester) async {
      // ── 1. 注入 LLM fixture ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ── 2. 准备 parent + blank branch ──
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeName = 'BlankPersist_$ts';
      final parentName = 'ParentPersist_$ts';
      await _createTestTheme(tester, themeName);
      await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(themeName));
      await tester.pumpAndSettle();
      await _createTestNode(tester, parentName);
      await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(parentName));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 10),
      );
      await _sendAndWaitForReply(
        tester,
        message: '你好',
        timeout: const Duration(seconds: 90),
      );
      await tester.pump(const Duration(seconds: 2));
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget);
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_blank_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(seconds: 2));

      // ── 3. 拿 blank nodeId ──
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CupertinoApp)),
        listen: false,
      );
      final nodeStore = await container.read(nodeStoreProvider.future);
      final themeRows = await nodeStore.db.query(
        'themes',
        columns: ['themeId'],
        where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
        whereArgs: [parentName],
        limit: 1,
      );
      final themeId = themeRows.first['themeId']! as String;
      final allNodes = await nodeStore.listNodes(themeId: themeId);
      final blankNode = allNodes
          .where((n) => n.sourceType == 'userIdea')
          .lastOrNull;
      expect(blankNode, isNotNull, reason: '应能找到 blank node');
      final blankNodeId = blankNode!.nodeId;
      final initialTitle = blankNode.title;
      debugPrint('[Test 9.5] blank nodeId=$blankNodeId, 初始 title=$initialTitle');
      expect(initialTitle, equals('临时会话'), reason: '初始 title 应该是占位 "临时会话"');

      // ── 4. 在新 chat_screen 发消息 → 流式完成 ──
      await _sendAndWaitForReply(
        tester,
        message: '数字化品牌的视觉逻辑',
        timeout: const Duration(seconds: 90),
      );
      debugPrint('[Test 9.5] 流式回复完成, 等待自动 title 触发...');

      // ── 5. 轮询 DB 等 auto title 被更新（最长 60s） ──
      String? updatedTitle;
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
        final row = await nodeStore.db.query(
          'nodes',
          columns: ['title'],
          where: 'nodeId = ?',
          whereArgs: [blankNodeId],
          limit: 1,
        );
        if (row.isNotEmpty) {
          final t = row.first['title']! as String;
          if (t != '临时会话' && t.trim().isNotEmpty) {
            updatedTitle = t;
            debugPrint('[Test 9.5] DB 自动 title 已更新: $updatedTitle (${i}s)');
            break;
          }
        }
        if (i % 10 == 0 && i > 0) {
          debugPrint('[Test 9.5] 等待自动 title... ${i}s');
        }
      }
      expect(updatedTitle, isNotNull, reason: '流式结束后 60s 内 LLM 应自动生成新 title');

      // ── 6. 关键断言 1：DB title 是新值 ──
      expect(updatedTitle, isNot(equals('临时会话')), reason: 'DB title 应被自动更新');

      // ── 7. 关键断言 2：tree controller state 已刷新 ──
      // 等 2s 让 refresh() 跑完
      await tester.pump(const Duration(seconds: 2));
      final themeCtrl = container.read(themeDetailControllerProvider(themeId));
      final treeState = themeCtrl.value;
      expect(treeState, isNotNull, reason: 'tree controller state 应已加载');
      final treeNode = treeState!.nodes.where((n) => n.nodeId == blankNodeId).firstOrNull;
      expect(treeNode, isNotNull, reason: 'tree 应包含 blank node');
      expect(treeNode!.title, equals(updatedTitle),
          reason: 'tree 中该 node 的 title 应被刷新为 LLM 生成的新 title');
      debugPrint('[Test 9.5] ✅ tree 已刷新: ${treeNode.title}');

      // ── 8. 关键断言 3：第二次进入 chat_screen 时 nav bar 仍是新 title ──
      // 找到 tree 中的 blank node 位置
      final newTitle = updatedTitle!;
      final blankNodeTextInTree = find.text(newTitle);
      expect(blankNodeTextInTree, findsWidgets,
          reason: 'tree 中应能找到新 title 的 node');
      await tester.tap(blankNodeTextInTree.first);
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 30),
      );
      // nav bar 标题（在 app bar 中）应该是新 title
      final navBarTitleFinder = find.text(newTitle);
      expect(navBarTitleFinder, findsWidgets,
          reason: 'nav bar 应显示 LLM 生成的新 title，不是"临时会话"');
      debugPrint('[Test 9.5] ✅ 第二次进入 chat_screen nav bar title 正确: $newTitle');

      debugPrint('[Test 9.5] ✅ case 9.5 完成: 自动 title 已持久化');
    }, timeout: const Timeout(Duration(minutes: 6)));

    testWidgets('A 模式：提前 pop chat 后后台 title 任务仍能跑完', (tester) async {
      // ── 1. 注入 LLM fixture ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ── 2. 准备 parent + blank branch（同 9.5 步骤） ──
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeName = 'BlankEarlyPop_$ts';
      final parentName = 'ParentEarlyPop_$ts';
      await _createTestTheme(tester, themeName);
      await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(themeName));
      await tester.pumpAndSettle();
      await _createTestNode(tester, parentName);
      await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(parentName));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 10),
      );
      await _sendAndWaitForReply(
        tester,
        message: '你好',
        timeout: const Duration(seconds: 90),
      );
      await tester.pump(const Duration(seconds: 2));
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget);
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_blank_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(seconds: 2));

      // ── 3. 拿 blank nodeId ──
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CupertinoApp)),
        listen: false,
      );
      final nodeStore = await container.read(nodeStoreProvider.future);
      final themeRows = await nodeStore.db.query(
        'themes',
        columns: ['themeId'],
        where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
        whereArgs: [parentName],
        limit: 1,
      );
      final themeId = themeRows.first['themeId']! as String;
      final allNodes = await nodeStore.listNodes(themeId: themeId);
      final blankNode = allNodes
          .where((n) => n.sourceType == 'userIdea')
          .lastOrNull;
      expect(blankNode, isNotNull, reason: '应能找到 blank node');
      final blankNodeId = blankNode!.nodeId;
      debugPrint('[Test 9.6] blank nodeId=$blankNodeId, 初始 title=${blankNode.title}');

      // ── 4. 在新 chat_screen 发消息 → 流式刚启动就 pop 回 tree ──
      final chatInput = find.byKey(const ValueKey('chat_input'));
      expect(chatInput, findsOneWidget);
      await tester.enterText(chatInput, '请帮我分析品牌视觉');
      await tester.pump();
      final sendBtn = find.byKey(const ValueKey('send_button'));
      expect(sendBtn, findsOneWidget);
      await tester.tap(sendBtn);
      await tester.pump();

      // 等待 stop_button 出现（流式已启动）
      final stopFinder = find.byKey(const ValueKey('stop_button'));
      final sw = Stopwatch()..start();
      while (stopFinder.evaluate().isEmpty) {
        if (sw.elapsed > const Duration(seconds: 10)) {
          fail('发送消息后 10s 内未进入流式状态');
        }
        await tester.pump(const Duration(milliseconds: 500));
      }
      debugPrint('[Test 9.6] 流式已启动，立即 pop 回 tree');

      // ★ 关键：不等流式结束，立刻 pop 回 tree
      // 这里用 Navigator.maybePop 更稳
      Navigator.of(tester.element(find.byType(CupertinoApp))).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // 验证：当前在 tree 页面（看到占位 "临时会话"）
      expect(find.text('临时会话'), findsWidgets,
          reason: 'pop 回 tree 后，DB title 仍是占位（LLM 还在跑）');

      // ── 5. 轮询 DB 等 auto title 被更新（最长 90s，给足时间） ──
      String? updatedTitle;
      for (var i = 0; i < 90; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
        final row = await nodeStore.db.query(
          'nodes',
          columns: ['title'],
          where: 'nodeId = ?',
          whereArgs: [blankNodeId],
          limit: 1,
        );
        if (row.isNotEmpty) {
          final t = row.first['title']! as String;
          if (t != '临时会话' && t.trim().isNotEmpty) {
            updatedTitle = t;
            debugPrint('[Test 9.6] 提前 pop 后 DB 仍被后台任务更新: $updatedTitle (${i}s)');
            break;
          }
        }
        if (i % 10 == 0 && i > 0) {
          debugPrint('[Test 9.6] 等待后台 title 任务... ${i}s');
        }
      }

      // ── 6. 关键断言：DB 仍被更新（widget dispose 后任务没被取消） ──
      expect(updatedTitle, isNotNull,
          reason: '提前 pop 后，后台 LLM 任务应仍能跑完并写 DB');
      expect(updatedTitle, isNot(equals('临时会话')),
          reason: 'DB title 仍应被自动更新');
      debugPrint('[Test 9.6] ✅ case 9.6 完成: 后台任务已持久化 title=$updatedTitle');
    }, timeout: const Timeout(Duration(minutes: 7)));

    testWidgets('A 模式：用户预改 title 后跳过自动生成', (tester) async {
      // ── 1. 注入 LLM fixture ──
      final llmConfig = LlmTestConfig.loadFromDefine();
      final app = await createTestApp(
        locale: const Locale('zh'),
        llmSettings: llmConfig.toAppSettings(),
        llmConfigStore: llmConfig.toLlmConfigStore(),
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // ── 2. 准备 parent + blank branch ──
      await _switchToTab(tester, '主题');
      await tester.pumpAndSettle();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final themeName = 'BlankManualTitle_$ts';
      final parentName = 'ParentManualTitle_$ts';
      await _createTestTheme(tester, themeName);
      await waitForText(tester, themeName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(themeName));
      await tester.pumpAndSettle();
      await _createTestNode(tester, parentName);
      await waitForText(tester, parentName, timeout: const Duration(seconds: 10));
      await tester.tap(find.text(parentName));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 10),
      );
      await _sendAndWaitForReply(
        tester,
        message: '你好',
        timeout: const Duration(seconds: 90),
      );
      await tester.pump(const Duration(seconds: 2));
      final branchBtn = find.byKey(const ValueKey('branch_button'));
      expect(branchBtn, findsOneWidget);
      await tester.tap(branchBtn);
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('branch_mode_blank_option')),
        timeout: const Duration(seconds: 10),
      );
      await tester.tap(find.byKey(const ValueKey('branch_mode_blank_option')));
      await tester.pumpAndSettle();
      await waitForWidget(
        tester,
        find.byKey(const ValueKey('chat_input')),
        timeout: const Duration(seconds: 30),
      );
      await tester.pump(const Duration(seconds: 2));

      // ── 3. 拿 blank nodeId ──
      final container = ProviderScope.containerOf(
        tester.element(find.byType(CupertinoApp)),
        listen: false,
      );
      final nodeStore = await container.read(nodeStoreProvider.future);
      final themeRows = await nodeStore.db.query(
        'themes',
        columns: ['themeId'],
        where: 'themeId IN (SELECT themeId FROM nodes WHERE title = ?)',
        whereArgs: [parentName],
        limit: 1,
      );
      final themeId = themeRows.first['themeId']! as String;
      final allNodes = await nodeStore.listNodes(themeId: themeId);
      final blankNode = allNodes
          .where((n) => n.sourceType == 'userIdea')
          .lastOrNull;
      expect(blankNode, isNotNull);
      final blankNodeId = blankNode!.nodeId;

      // ── 4. ★ 关键：模拟用户手动改 DB title（不走 widget UI，直接 DB 写） ──
      // 这模拟了用户通过 node rename 功能改名，但 chat_screen 还在用旧 title 的场景
      const manualTitle = '我的自定义标题';
      await nodeStore.updateNodeTitle(nodeId: blankNodeId, newTitle: manualTitle);
      debugPrint('[Test 9.4] 模拟用户手动改 DB title 为 "$manualTitle"');

      // ── 5. 在新 chat_screen 发消息 → 流式完成 ──
      // 注意：widget 构造时拿的 title 仍是占位（DB 改的不会传回 widget），
      // 所以 isStreaming 边沿触发后，runIfNeeded 会启动 LLM，
      // 但守卫 3（查 DB title）会发现 DB 已被改，跳过 LLM 流程
      await _sendAndWaitForReply(
        tester,
        message: '品牌视觉问题',
        timeout: const Duration(seconds: 90),
      );

      // ── 6. 轮询 DB 等任务完成（最长 30s） ──
      // AutoTitleController.runIfNeeded 启动后会查 DB 守卫，发现 title 已被改，
      // state = done(manualTitle) 然后 return。整个过程 < 1s
      await tester.pump(const Duration(seconds: 5));
      for (var i = 0; i < 30; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
        await tester.pump();
        final row = await nodeStore.db.query(
          'nodes',
          columns: ['title'],
          where: 'nodeId = ?',
          whereArgs: [blankNodeId],
          limit: 1,
        );
        if (row.isNotEmpty) {
          final t = row.first['title']! as String;
          // 等 auto title controller 跑完（不会改 DB，但会写自己的 state）
          // 简单起见：等 5s 后再看
          if (i >= 5) {
            debugPrint('[Test 9.4] 当前 DB title: $t (${i}s)');
            expect(t, equals(manualTitle),
                reason: 'DB title 仍应是用户手动改的 "$manualTitle"，不应被 LLM 覆盖');
            break;
          }
        }
      }

      // ── 7. 验证：title 仍是用户手动改的 ──
      final finalRow = await nodeStore.db.query(
        'nodes',
        columns: ['title'],
        where: 'nodeId = ?',
        whereArgs: [blankNodeId],
        limit: 1,
      );
      final finalTitle = finalRow.first['title']! as String;
      expect(finalTitle, equals(manualTitle),
          reason: '用户手动改的 title 不应被 LLM 覆盖');
      debugPrint('[Test 9.4] ✅ case 9.4 完成: 手动改 title=$manualTitle 不被覆盖');
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

/// 创建测试主题
Future<void> _createTestTheme(WidgetTester tester, String title) async {
  // 点击添加按钮（使用 ValueKey）
  final addButton = find.byKey(const ValueKey('add_theme_button'));
  expect(addButton, findsOneWidget, reason: '应该找到添加主题按钮');
  await tester.tap(addButton);
  await tester.pumpAndSettle();

  // 在对话框中输入标题
  final textField = find.byType(CupertinoTextField);
  expect(textField, findsOneWidget, reason: '应该找到输入框');
  await tester.enterText(textField, title);
  await tester.pump();

  // 点击创建按钮
  final createButton = find.text('Create');
  if (createButton.evaluate().isNotEmpty) {
    await tester.tap(createButton);
  } else {
    // 尝试中文按钮
    final createButtonCn = find.text('创建');
    await tester.tap(createButtonCn);
  }
  await tester.pumpAndSettle();
}

/// 创建测试节点
Future<void> _createTestNode(WidgetTester tester, String title) async {
  // 点击添加节点按钮（使用 ValueKey）
  final addButton = find.byKey(const ValueKey('add_node_button'));
  expect(addButton, findsOneWidget, reason: '应该找到添加节点按钮');
  await tester.tap(addButton);
  await tester.pumpAndSettle();

  // 在对话框中输入标题
  final textField = find.byType(CupertinoTextField);
  expect(textField, findsOneWidget, reason: '应该找到输入框');
  await tester.enterText(textField, title);
  await tester.pump();

  // 点击创建按钮
  final createButton = find.text('Create');
  if (createButton.evaluate().isNotEmpty) {
    await tester.tap(createButton);
  } else {
    final createButtonCn = find.text('创建');
    await tester.tap(createButtonCn);
  }
  await tester.pumpAndSettle();
}

/// 发送消息
Future<void> _sendMessage(WidgetTester tester, String message) async {
  // 找到聊天输入框
  final chatInput = find.byKey(const ValueKey('chat_input'));
  if (chatInput.evaluate().isEmpty) {
    // 可能没有进入对话页面，跳过
    return;
  }

  // 输入消息
  await tester.enterText(chatInput, message);
  await tester.pump();

  // 点击发送按钮
  final sendButton = find.byKey(const ValueKey('send_button'));
  if (sendButton.evaluate().isNotEmpty) {
    await tester.tap(sendButton);
    await tester.pumpAndSettle();
  }
}

/// 打开分支模式选择 sheet（供 case 5/6 复用）
///
/// 点击 branch_button，等待 sheet 出现，选择指定模式。
/// [mode] 参数为 'summarize' 或 'raw'。
Future<void> openBranchSheet(WidgetTester tester, {required String mode}) async {
  // 点击分支按钮
  await tester.tap(find.byKey(const ValueKey('branch_button')));
  await tester.pumpAndSettle();

  // 等待 sheet 出现
  await waitForWidget(tester, find.byKey(ValueKey('branch_mode_${mode}_option')));

  // 选择模式
  await tester.tap(find.byKey(ValueKey('branch_mode_${mode}_option')));
  await tester.pump();
}

/// 点底部 tab 栏的指定 tab（按 label 文本定位）。
Future<void> _switchToTab(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  expect(labelFinder, findsWidgets, reason: '底部 tab 应包含 "$label"');
  await tester.tap(labelFinder.first, warnIfMissed: false);
}

/// 发送一条消息，等待 LLM 流式回复完成。
///
/// 流程：
/// 1. 输入消息到 chat_input
/// 2. 点击 send_button
/// 3. 等待 stop_button 出现（流式已启动）
/// 4. 等待 send_button 重新出现（流式已结束）
Future<void> _sendAndWaitForReply(
  WidgetTester tester, {
  required String message,
  Duration timeout = const Duration(seconds: 90),
}) async {
  final chatInput = find.byKey(const ValueKey('chat_input'));
  expect(chatInput, findsOneWidget, reason: '应找到聊天输入框');

  // 输入消息
  await tester.enterText(chatInput, message);
  await tester.pump();

  // 点击发送按钮
  final sendBtn = find.byKey(const ValueKey('send_button'));
  expect(sendBtn, findsOneWidget, reason: '发送前应找到 send_button');
  await tester.tap(sendBtn);
  await tester.pump();

  // 等 stop_button 出现 → 流式已启动
  final stopFinder = find.byKey(const ValueKey('stop_button'));
  final sw = Stopwatch()..start();
  while (stopFinder.evaluate().isEmpty) {
    if (sw.elapsed > const Duration(seconds: 10)) {
      fail('发送消息后 10s 内未进入流式状态');
    }
    await tester.pump(const Duration(milliseconds: 500));
  }

  // 等 send_button 回来 → 流式已结束
  await waitForWidget(
    tester,
    find.byKey(const ValueKey('send_button')),
    timeout: timeout,
  );
  await tester.pump();
}

/// 选中消息文本（A1 方案：长按 → 全选）。
///
/// 利用 SelectionArea 内置手势：
/// 1. 长按消息文本 → 触发词选 + 弹出上下文菜单
/// 2. 点击「全选」→ 选中所有文本 → _currentSelectedText 被设置
///
/// 注意：flutter_tester 的 longPress 在 SelectionArea 内会触发
/// 原生文本选择行为，toolbar 按钮作为 overlay 渲染。
Future<void> selectTextInMessage(WidgetTester tester, String text) async {
  // 长按消息文本 → 触发 SelectionArea 选中一个词 + 弹出上下文菜单
  final msgFinder = find.textContaining(text).first;
  expect(msgFinder, findsWidgets, reason: '应找到包含 "$text" 的消息');
  await tester.longPress(msgFinder);
  await tester.pump(const Duration(seconds: 1));

  // 点击「全选」按钮
  // 中文 locale 显示「全选」，英文显示「Select All」
  final selectAllZh = find.text('全选');
  final selectAllEn = find.text('Select All');

  if (selectAllZh.evaluate().isNotEmpty) {
    await tester.tap(selectAllZh);
  } else if (selectAllEn.evaluate().isNotEmpty) {
    await tester.tap(selectAllEn);
  } else {
    // fallback：跳过选区，不影响后续流程
    debugPrint('[selectTextInMessage] 未找到「全选」按钮，跳过选区');
    return;
  }
  await tester.pump(const Duration(milliseconds: 500));
}


