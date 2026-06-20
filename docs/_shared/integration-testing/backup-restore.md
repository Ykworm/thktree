# 集成测试 · 备份与恢复

> **创建**：2026-06-18
> **最近更新**：2026-06-18
> **维护者**：AI + 用户审阅
> **状态**：⏸️ 测试空壳（4 个 testWidgets 全部 TODO），本 spec 描述"如何补"的路线图
> **相关 spec**：[README.md](./README.md) · [theme-chat-e2e.md](./theme-chat-e2e.md) · [fixtures.md](./fixtures.md) · [helpers.md](./helpers.md)

---

## 1. 目标

验证 **数据导出（zip 备份）→ 清空 → 数据导入（zip 恢复）** 的完整往返链路，覆盖三种业务场景：

1. **Round-trip 一致性**：备份文件结构、manifest 字段、theme 树都能精确还原
2. **冲突处理**：恢复时检测本地已有数据，弹冲突对话框，支持"覆盖 / 合并 / 取消"三选一
3. **格式契约**：备份 zip 必须包含 `thktree-export/thktree-manifest.json` + `thktree-export/themes/...`

> **关键背景**：与 LLM 链路测试不同，本 spec **完全不依赖 LLM**——纯本地 IO 测试。

---

## 2. 测试现状

`integration_test/backup_restore_test.dart`（68 行）有 4 个 testWidgets，**全部只有 TODO 注释，没有任何实质实现**：

| # | testWidgets | 状态 | 阻塞点 |
|---|-------------|------|--------|
| 1 | `完整备份和恢复往返测试` | ❌ TODO 空壳 | UI 触发 + Share 平台通道无法操作 |
| 2 | `备份文件格式验证` | ❌ TODO 空壳 | 需触发 backup 后访问产物文件 |
| 3 | `恢复冲突处理测试` | ❌ TODO 空壳 | FilePicker 平台通道无法操作 |
| 4 | `恢复覆盖模式测试` | ❌ TODO 空壳 | FilePicker 平台通道无法操作 |

```dart
// 当前 68 行的结构（line 1-68）
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:thk_tree/main_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('备份与恢复流程测试', () {
    testWidgets('完整备份和恢复往返测试', (tester) async {
      final app = await createTestApp();
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      // TODO: 创建测试主题和节点，用于备份验证
      // TODO: 导航到设置页面，触发备份功能
      // TODO: 验证备份文件生成成功
      // ...
    });
    // ... 其余 3 个结构相同
  });
}
```

---

## 3. 底层实现剖析（理解测试为何空壳）

### 3.1 ExportService — 数据导出

**位置**：`lib/data/services/export_service.dart`（105 行）

```dart
class ExportService {
  ExportService({required this.rootDir});

  Future<File> exportFull({required String appVersion}) async {
    // 1. 扫描 ${rootDir.path}/themes 下所有 theme 目录
    // 2. 解析 theme.meta.json 拿到 title
    // 3. 构造 ExportManifest:
    //    {
    //      "schema": "thktree-manifest/v1",
    //      "appVersion": "1.0.0",
    //      "exportedAt": "2026-06-18T...",
    //      "scope": "full",
    //      "themes": [{ themeId, title, nodeCount, noteCount }, ...]
    //    }
    // 4. 用 package:archive 打包 zip，路径：
    //    thktree-export/thktree-manifest.json
    //    thktree-export/themes/<themeId>/...
    // 5. 写入: ${rootDir.path}/thktree-export-${ms}.zip
  }
}
```

**ExportManifest** 完整 schema（`lib/data/models/export_manifest.dart`）：

```json
{
  "schema": "thktree-manifest/v1",
  "appVersion": "1.0.0",
  "exportedAt": "2026-06-18T12:34:56.789Z",
  "scope": "full",
  "themes": [
    {
      "themeId": "thm_01J8ABC...",
      "title": "Swift 学习",
      "nodeCount": 5,
      "noteCount": 12
    }
  ]
}
```

**关键约束**：
- `themes` 目录必须存在（不存在抛 `StateError`）
- manifest schema 写死 `v1`，未来 breaking change 必须升级到 `v2`
- zip 文件名带 `millisecondsSinceEpoch` 后缀，**每次都不同**（所以测试不能 hardcode 文件名）

### 3.2 ImportService — 数据恢复

**位置**：`lib/data/services/import_service.dart`（133 行）

```dart
enum ImportMode { overwrite, merge }
enum ImportResultStatus { success, conflict, error }

class ImportResult {
  ImportResult({
    required this.status,
    this.message,
    this.importedThemes = 0,
  });
  final ImportResultStatus status;
  final String? message;
  final int importedThemes;
}

class ImportService {
  ImportService({required this.rootDir});

  bool hasExistingData() { /* themes 目录非空 = true */ }

  Future<ImportResult> importFull({
    required File zipFile,
    required ImportMode mode,
  }) async {
    // 1. 解压 zip
    // 2. 找 manifest（缺失返回 error + "Invalid export file: manifest not found"）
    // 3. mode == overwrite → 递归删除 themes 目录
    // 4. 遍历 thktree-export/themes/* 写回本地
    //    - mode == merge 且文件已存在 → 数字后缀（name 01.ext）
    //    - mode == overwrite → 直接覆盖
    // 5. 累计 theme.meta.json 个数 → importedThemes
  }
}
```

**关键约束**：
- manifest 缺失 → 返回 `error` 状态，不会写任何文件
- merge 模式**仅在文件级别去重**，themeId 不变（依赖 SQLite 索引重建）
- overwrite 模式**暴力清空 themes 目录**，无确认机制

### 3.3 UI 入口（settings_screen.dart）

**`_BackupEntry`**（line 659-740）—— 点击后流程：

```
1. 取 pathsAsync.value（AppPaths 提供）
2. 弹进度对话框（fire-and-forget：unawaited + .then.catchError 吞异常）
3. exportService.exportFull(appVersion: '1.0.0')
   ⚠️ TODO: 从 package_info 获取（line 700 注释）
4. 关闭进度对话框（navigator.canPop() 检查避免 _debugLocked）
5. Share.shareXFiles([XFile(zipFile.path)])
   ⚠️ 这一步会跳出 app 进入 iOS 系统分享面板！
```

**`_RestoreEntry`**（line 743-900）—— 点击后流程：

```
1. FilePicker.platform.pickFiles(type: custom, allowedExtensions: ['zip'])
   ⚠️ 这一步会跳出 app 进入 iOS 系统文件选择器！
2. importService.hasExistingData() → 弹冲突对话框（仅当 true）
   3 选 1: overwrite / merge / cancel
3. 弹进度对话框
4. importService.importFull(zipFile, mode)
5. 根据 ImportResult.status 弹成功/失败对话框
   - success → ref.invalidate(appPathsProvider + themeListControllerProvider)
   - error   → 显示 message
```

### 3.4 缺失的 ValueKey 清单 ⚠️

`lib/ui/features/settings/settings_screen.dart` 当前**完全没有 ValueKey**：

| 需要的 Key | 当前是否存在 | 影响 |
|-----------|------------|------|
| `backup_tile` | ❌ | UI 触发备份完全靠 `find.text('备份数据')` |
| `restore_tile` | ❌ | UI 触发恢复完全靠 `find.text('恢复数据')` |
| `tab_settings` | ❌ | `_switchToTab(tester, '设置')` 只能靠 tab 栏 Text |
| `restore_conflict_dialog` | ❌ | 冲突对话框定位靠 `find.text('数据冲突')` |
| `restore_overwrite_button` | ❌ | 选覆盖只能 `find.text('覆盖')` |
| `restore_merge_button` | ❌ | 选合并只能 `find.text('合并')` |

**这一节是 4 个测试全空壳的根本原因**——没有 ValueKey 就没法用 `find.byKey` 精确定位，所有现有 helper（`safeTap`、`enterTextAndWait`）都用 `find.byKey` 优先。

---

## 4. 编写前置依赖（必做项清单）

在动手补 4 个 testWidgets 之前，**必须**先完成以下事项（**不是文档任务**，是代码改动）：

### 4.1 给 settings 页面加 ValueKey

```dart
// lib/ui/features/settings/settings_screen.dart line 667-739 (_BackupEntry)
return ThkListTile(
  key: const ValueKey('backup_tile'),  // 新增
  title: l10n.backupData,
  leading: const Icon(AppIcons.share),
  onTap: () async { ... },
);

// line 751-900 (_RestoreEntry)
return ThkListTile(
  key: const ValueKey('restore_tile'),  // 新增
  title: l10n.restoreData,
  leading: const Icon(AppIcons.download),
  onTap: () async { ... },
);
```

并对冲突对话框按钮加 Key：

```dart
// line 786-799
CupertinoDialogAction(
  key: const ValueKey('restore_overwrite_button'),
  child: Text(l10n.restoreOverwrite),
  ...
),
CupertinoDialogAction(
  key: const ValueKey('restore_merge_button'),
  child: Text(l10n.restoreMerge),
  ...
),
```

### 4.2 提升 platform 通道为可注入

**Share.shareXFiles** 和 **FilePicker.platform.pickFiles** 都是 platform channel 调用，集成测试默认走的是真实 channel，会跳出 app。两种解法：

**方案 A（推荐）**：把 `_BackupEntry` 的导出流程拆出独立 helper（`triggerBackup()`），测试直接调 helper 跳过 Share

```dart
// 新增 lib/ui/features/settings/settings_actions.dart
Future<File> triggerBackupExport(AppPaths paths) async {
  final service = ExportService(rootDir: paths.rootDir);
  return service.exportFull(appVersion: '1.0.0');
}
```

**方案 B**：在测试中用 `IntegrationTestWidgetsFlutterBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler` mock `share_plus` 和 `file_picker` 的 channel（侵入性大，不推荐）

**方案 C**（**本 spec 推荐**）：测试**不经过 UI**，直接在测试代码里构造 ExportService / ImportService，验证 round-trip 数据流

### 4.3 在 `_support/` 加 helper

参考 `theme_chat_e2e_test.dart` 的 `_createTheme` / `_createNode` 私有 helper（line 171-207）提取到 `_support/`：

```dart
// 新增 integration_test/_support/backup_helpers.dart
Future<String> createBackupZip({
  required ProviderContainer container,
  required String appVersion,
}) async {
  final paths = container.read(appPathsProvider).requireValue;
  final service = ExportService(rootDir: paths.rootDir);
  final file = await service.exportFull(appVersion: appVersion);
  return file.path;  // 测完用 File(path).delete() 清掉
}

Future<ImportResult> restoreBackupZip({
  required ProviderContainer container,
  required String zipPath,
  required ImportMode mode,
}) async {
  final paths = container.read(appPathsProvider).requireValue;
  final service = ImportService(rootDir: paths.rootDir);
  return service.importFull(zipFile: File(zipPath), mode: mode);
}
```

> **不在本次文档任务范围**：决策 3（`_createTheme` / `_createNode` 提升到 `_support/`）用户已选 "本次只写文档不动代码"，4.1-4.3 都是**路线图**，实施时新建独立 task。

---

## 5. 编写路线（4 个 testWidgets 完整代码）

> **前提**：已完成 § 4 的 ValueKey + helper 准备工作。

### 5.1 完整备份和恢复往返测试

```dart
testWidgets('完整备份和恢复往返测试', (tester) async {
  // 1. 启动 app + 创建测试数据
  final app = await createTestApp();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  
  // 复用 theme_chat_e2e 的 helper（已提升到 _support/ 后）
  await _createTheme(tester, 'Backup Test Theme');
  await waitForText(tester, 'Backup Test Theme');
  await _createNode(tester, 'Test Node');
  
  // 2. ⚠️ 不走 UI 触发 Share，直接调 ExportService
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ThkTreeApp)),
  );
  final zipPath = await createBackupZip(container: container, appVersion: '1.0.0');
  
  // 3. 验证产物
  expect(File(zipPath).existsSync(), isTrue);
  expect(File(zipPath).lengthSync(), greaterThan(0));
  
  // 4. 清空数据（模拟"灾难场景"）
  final paths = container.read(appPathsProvider).requireValue;
  if (paths.themesDir.existsSync()) {
    paths.themesDir.deleteSync(recursive: true);
  }
  expect(importService.hasExistingData(), isFalse);
  
  // 5. 恢复
  final result = await restoreBackupZip(
    container: container,
    zipPath: zipPath,
    mode: ImportMode.overwrite,
  );
  
  // 6. 验证恢复结果
  expect(result.status, ImportResultStatus.success);
  expect(result.importedThemes, 1);
  expect(paths.themesDir.existsSync(), isTrue);
  
  // 7. UI 验证：切回主题列表能看到恢复的主题
  await _switchToTab(tester, '主题');
  await tester.pumpAndSettle();
  await waitForText(tester, 'Backup Test Theme');
  
  // 8. 清理
  File(zipPath).deleteSync();
});
```

### 5.2 备份文件格式验证

```dart
testWidgets('备份文件格式验证', (tester) async {
  final app = await createTestApp();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  
  await _createTheme(tester, 'Format Test');
  await _createNode(tester, 'Node A');
  
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ThkTreeApp)),
  );
  final zipPath = await createBackupZip(container: container, appVersion: '1.0.0');
  
  // 解压验证 schema
  final bytes = File(zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  
  // 1. 必有 manifest
  final manifestFile = archive.findFile('thktree-export/thktree-manifest.json');
  expect(manifestFile, isNotNull, reason: 'manifest 必须存在');
  
  // 2. manifest schema 正确
  final manifestJson = jsonDecode(utf8.decode(manifestFile.content as List<int>));
  expect(manifestJson['schema'], 'thktree-manifest/v1');
  expect(manifestJson['appVersion'], '1.0.0');
  expect(manifestJson['scope'], 'full');
  expect((manifestJson['themes'] as List).length, 1);
  expect(manifestJson['themes'][0]['title'], 'Format Test');
  
  // 3. 必有 themes 目录 + theme.meta.json
  final hasMetaFile = archive.files.any((f) =>
      f.name.startsWith('thktree-export/themes/') && f.name.endsWith('theme.meta.json'));
  expect(hasMetaFile, isTrue);
  
  File(zipPath).deleteSync();
});
```

### 5.3 恢复冲突处理测试（合并模式）

```dart
testWidgets('恢复冲突处理测试', (tester) async {
  final app = await createTestApp();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ThkTreeApp)),
  );
  
  // 1. 创建初始数据 + 备份
  await _createTheme(tester, 'Theme Original');
  final zipPath = await createBackupZip(container: container, appVersion: '1.0.0');
  
  // 2. 创建新数据（与备份不同）
  await _createTheme(tester, 'Theme Local New');
  
  // 3. ⚠️ 必须走 UI 才能测冲突对话框（FilePicker 用 mock channel 跳过）
  // 简化版：直接验证 ImportService.merge 行为
  final paths = container.read(appPathsProvider).requireValue;
  final importService = ImportService(rootDir: paths.rootDir);
  
  final result = await importService.importFull(
    zipFile: File(zipPath),
    mode: ImportMode.merge,
  );
  
  // 4. 合并模式：本地数据保留 + 备份数据导入
  expect(result.status, ImportResultStatus.success);
  expect(result.importedThemes, greaterThanOrEqualTo(1));
  
  // 5. 验证两个主题都在（主题列表 UI）
  await _switchToTab(tester, '主题');
  await tester.pumpAndSettle();
  expect(find.text('Theme Original'), findsOneWidget);
  expect(find.text('Theme Local New'), findsOneWidget);
  
  File(zipPath).deleteSync();
});
```

### 5.4 恢复覆盖模式测试

```dart
testWidgets('恢复覆盖模式测试', (tester) async {
  final app = await createTestApp();
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
  
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ThkTreeApp)),
  );
  
  // 1. 创建初始数据 + 备份
  await _createTheme(tester, 'Theme To Keep');
  final zipPath = await createBackupZip(container: container, appVersion: '1.0.0');
  
  // 2. 创建新数据（待被覆盖）
  await _createTheme(tester, 'Theme To Discard');
  expect(find.text('Theme To Discard'), findsOneWidget);
  
  // 3. 覆盖恢复
  final paths = container.read(appPathsProvider).requireValue;
  final importService = ImportService(rootDir: paths.rootDir);
  final result = await importService.importFull(
    zipFile: File(zipPath),
    mode: ImportMode.overwrite,
  );
  
  // 4. 验证覆盖结果
  expect(result.status, ImportResultStatus.success);
  
  // 5. UI 验证：旧主题保留，新主题消失
  await _switchToTab(tester, '主题');
  await tester.pumpAndSettle();
  expect(find.text('Theme To Keep'), findsOneWidget);
  expect(find.text('Theme To Discard'), findsNothing);
  
  File(zipPath).deleteSync();
});
```

---

## 6. 依赖的 helpers 与 fixtures

| 依赖 | 来源 | 用途 |
|------|------|------|
| `createTestApp()` | `lib/main_test.dart` | 启动测试 app |
| `_createTheme` / `_createNode` | theme_chat_e2e_test.dart（**需提升到 _support/**） | 创建测试数据 |
| `_switchToTab(tester, '设置')` | theme_chat_e2e_test.dart（**需提升到 _support/**） | 跳转到 settings tab |
| `ExportService` / `ImportService` | `lib/data/services/` | 直接调服务（不走 UI 触发） |
| `appPathsProvider` | `lib/ui/core/app_paths.dart` | 拿测试沙盒目录路径 |
| `ValueKey('backup_tile'/'restore_tile')` | **⚠️ 待补** | UI 触发备份/恢复 |

---

## 7. 阻塞点汇总

按依赖顺序：

1. **🔴 settings ValueKey 缺失**（§ 4.1）—— 不补则 UI 测试完全无法触发备份/恢复入口
2. **🔴 Share/FilePicker 平台通道**（§ 4.2）—— iOS 系统面板集成测试点不到，必须绕过
3. **🟡 `_createTheme` / `_createNode` 未提升到 `_support/`**（§ 4.3）—— 复用性差，4 个测试都得复制粘贴
4. **🟡 `appPathsProvider` 是否能直接读** —— `AppPaths.themesDir` getter 需确认是否存在（README.md § 5.2 中描述）
5. **🟢 package_info 未集成** —— `appVersion: '1.0.0'` 是 hardcode，不影响测试，但建议跟进

---

## 8. 风险与边界

### 不在本文档范围

- ❌ **不实现**任何 backup_restore_test.dart 的 TODO（本次只写文档）
- ❌ **不补** settings ValueKey（属于代码改动，不在文档任务）
- ❌ **不重构** `_support/` 或 `test_helpers.dart`（用户决策 3：本次只写文档）

### 已知风险

- **Share.shareXFiles 跳 app**：iOS 系统分享面板弹出后 Flutter app 进入 inactive，集成测试 driver 无法点击面板按钮——必须绕开
- **FilePicker 平台通道**：同理，iOS 文件选择器无法在测试中操作
- **磁盘慢**：模拟器 IO 比真机慢，zip 写盘可能需要 `pumpAndSettleWithTimeout(seconds: 30)`
- **冲突对话框时序**：弹对话框后 waitForWidget 必须有 timeout（默认 10s 可能不够）
- **副作用难清理**：备份 zip 写在 sandbox 临时目录，跑完测试要手动 `File(zipPath).deleteSync()`，否则下次跑可能残留

### 与 LLM 测试的对比

| 维度 | backup-restore | theme-chat-e2e |
|------|---------------|----------------|
| 是否需要 LLM | ❌ | ✅ 真实 API |
| 平台通道 | Share / FilePicker（**难处理**） | 无 |
| 阻塞项 | ValueKey 缺失 + 平台通道 | ValueKey 已有 |
| 测试时长 | < 10s（纯本地 IO） | 60-120s（LLM 推理） |
| 稳定性 | 高（无网络） | 中（API 不稳定） |

---

## 9. 执行命令

```bash
# 单跑 backup_restore_test（当前会因 TODO 空壳通过但无实质覆盖）
flutter test integration_test/backup_restore_test.dart -d "<iOS Simulator>"

# 带 driver 跑（用于回传截图到 host）
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/backup_restore_test.dart \
  -d "<iOS Simulator>"

# 完整集成测试套件
flutter test integration_test/ -d "<iOS Simulator>"
```

> **当前结果**：4 个 testWidgets 全部立即通过（只是没断言），不是"测试通过"的真实信号。

---

## 10. 完成状态 Checklist

### 文档编写（本 spec）

- [x] 目标与背景
- [x] 测试现状（4 个 TODO 空壳）
- [x] 底层实现剖析（ExportService / ImportService / UI 入口）
- [x] ValueKey 缺失清单
- [x] 编写前置依赖（4.1-4.3）
- [x] 4 个 testWidgets 完整代码
- [x] 阻塞点汇总
- [x] 风险与边界
- [x] 执行命令

### 代码层面（**不在本文档任务**）

- [ ] 给 `_BackupEntry` / `_RestoreEntry` 加 `backup_tile` / `restore_tile` ValueKey
- [ ] 给冲突对话框按钮加 `restore_overwrite_button` / `restore_merge_button` ValueKey
- [ ] 把 `_createTheme` / `_createNode` / `_switchToTab` 提升到 `integration_test/_support/`
- [ ] 新增 `integration_test/_support/backup_helpers.dart`（`createBackupZip` / `restoreBackupZip`）
- [ ] 实现 § 5.1-5.4 四个 testWidgets 实际代码
- [ ] 跑通 + 截图验证

---

## 11. 相关文档

- [README.md](./README.md) — 集成测试总论（架构、目录约定、运行调试）
- [fixtures.md](./fixtures.md) — fixtures 详解（InMemoryLlmConfigStore，本 spec 不需要 LLM，但 fixtures 体系相关）
- [helpers.md](./helpers.md) — test_helpers.dart 工具（`waitForText` / `_createTheme` 思路参考）
- [theme-chat-e2e.md](./theme-chat-e2e.md) — 完整跑通的范式（4 个私有 helper 都可借鉴）
- [docs/_tmp/导出导入方案.md](../../../_tmp/导出导入方案.md) — backup 业务方案 brainstorming 记录
- `lib/data/services/export_service.dart` — ExportService 实现（105 行）
- `lib/data/services/import_service.dart` — ImportService 实现（133 行）
- `lib/data/models/export_manifest.dart` — manifest schema 定义（96 行）
- `lib/ui/features/settings/settings_screen.dart:659-900` — `_BackupEntry` / `_RestoreEntry` UI 入口