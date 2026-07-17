import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/ui/core/app_logger.dart';
import 'package:thk_tree/ui/core/app_paths.dart';
import 'package:thk_tree/data/services/app_database.dart';
import 'package:thk_tree/data/services/biometric_service.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/stores/llm_config_store.dart';
import 'package:thk_tree/data/stores/node_store.dart';
import 'package:thk_tree/data/stores/session_store.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/stores/theme_store.dart';
import 'package:thk_tree/data/stores/note_store.dart';
import 'package:thk_tree/data/services/search_service.dart';
import 'package:thk_tree/data/services/apple_tts_service.dart';
import 'package:thk_tree/data/services/no_op_tts_service.dart';
import 'package:thk_tree/data/services/tts_service.dart';
import 'package:thk_tree/data/services/keyword_analysis_storage.dart';
import 'package:thk_tree/data/services/keyword_analysis_service.dart';
import 'package:thk_tree/data/services/keyword_extraction_service.dart';
import 'package:thk_tree/data/services/keyword_aggregation_service.dart';
import 'package:thk_tree/data/services/keyword_global_storage.dart';
import 'package:thk_tree/data/services/keyword_category_storage.dart';
import 'package:thk_tree/data/services/clip_storage.dart';

class NoteListVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final noteListVersionProvider = NotifierProvider<NoteListVersionNotifier, int>(NoteListVersionNotifier.new);

final appPathsProvider = FutureProvider<AppPaths>((ref) async {
  final paths = await AppPaths.load();
  await paths.ensureCreated();
  return paths;
});

final tempDirProvider = FutureProvider<Directory>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return paths.tempDir;
});

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  dev.log('[appDatabaseProvider] starting');
  final paths = await ref.watch(appPathsProvider.future);
  dev.log('[appDatabaseProvider] paths loaded, indexDbPath=${paths.indexDbPath}');
  final db = await AppDatabase.open(path: paths.indexDbPath);
  dev.log('[appDatabaseProvider] database opened');

  // Startup sync: reconcile disk vs DB (lightweight, runs once)
  // 注意：这是「自动修复数据」的主题/节点对齐，不是搜索 FTS 的 rebuildAll。
  dev.log(
    '[appDatabaseProvider] starting theme syncFromDisk '
    'rootDir=${paths.rootDir.path} themesDir=${paths.themesDir.path}',
  );
  final themeStore = ThemeStore(paths: paths, db: db.db);
  await themeStore.syncFromDisk();
  dev.log('[appDatabaseProvider] theme syncFromDisk completed');

  final nodeStore = NodeStore(db: db.db, paths: paths);
  final themes = await themeStore.listThemes();
  dev.log('[appDatabaseProvider] found ${themes.length} themes after sync');

  var nodesSynced = 0;
  for (final theme in themes) {
    final themePath = p.join(paths.themesDir.path, theme.themeId);
    dev.log('[appDatabaseProvider] syncing nodes for theme: ${theme.themeId}');
    await nodeStore.syncFromDisk(themePath: themePath);
    final count = (await nodeStore.listNodes(themeId: theme.themeId)).length;
    nodesSynced += count;
    dev.log(
      '[appDatabaseProvider] theme ${theme.themeId} nodesInDb=$count',
    );
  }

  // 确保"未分类"主题始终存在
  if (!themes.any((t) => t.title == '未分类')) {
    dev.log('[appDatabaseProvider] creating 未分类 theme');
    await themeStore.createTheme(title: '未分类');
  }

  dev.log(
    '[appDatabaseProvider] completed startup_sync_diag '
    'themes=${themes.length} nodesTotal=$nodesSynced '
    'rootDir=${paths.rootDir.path}',
  );
  return db;
});

final appLoggerProvider = FutureProvider<AppLogger>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  final remoteLogUrl = const String.fromEnvironment('THKTREE_LOG_URL');
  final logger = AppLogger(paths: paths, remoteLogUrl: remoteLogUrl);
  await logger.init();
  return logger;
});

final themeStoreProvider = FutureProvider<ThemeStore>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  return ThemeStore(paths: paths, db: db.db);
});

final nodeStoreProvider = FutureProvider<NodeStore>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  return NodeStore(db: db.db, paths: paths);
});

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  return SettingsStore(secureStorage: const FlutterSecureStorage());
});

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final store = ref.watch(settingsStoreProvider);
  return store.load();
});

final llmConfigStoreProvider = Provider<LlmConfigStore>((ref) {
  return LlmConfigStore(secureStorage: const FlutterSecureStorage());
});

final llmProvidersProvider = FutureProvider<List<LlmProviderConfig>>((ref) async {
  final store = ref.watch(llmConfigStoreProvider);
  await store.initializeIfNeeded();
  await store.migrateMissingPresets();
  await store.migrateDeepSeekToAnthropic();
  return store.loadAll();
});

final searchServiceProvider = FutureProvider<SearchService>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  final db = await ref.watch(appDatabaseProvider.future);
  final searchService = SearchService(
    db: db.db,
    paths: paths,
    noteStoreFactory: (themeId) => NoteStore(
      notesDir: Directory('${paths.themesDir.path}/$themeId/notes'),
    ),
  );

  // Check if index is empty and rebuild if needed
  final isEmpty = await searchService.isEmpty();
  if (isEmpty) {
    dev.log('[searchServiceProvider] Index is empty, starting rebuild...');
    final themeStore = await ref.read(themeStoreProvider.future);
    final themes = await themeStore.listThemes();
    final scanItems = themes.map((t) => ThemeScanItem(
      themeId: t.themeId,
      title: t.title,
      notesDir: Directory('${paths.themesDir.path}/${t.themeId}/notes'),
      nodesDir: Directory('${paths.themesDir.path}/${t.themeId}/nodes'),
    )).toList();

    // Run rebuild in background (fire-and-forget)
    unawaited(() async {
      try {
        final (total, skipped) = await searchService.rebuildAll(scanItems);
        dev.log('[searchServiceProvider] Rebuild complete: total=$total, skipped=$skipped');
      } catch (e) {
        dev.log('[searchServiceProvider] Rebuild failed: $e');
      }
    }());
  }

  return searchService;
});

final sessionStoreProvider = FutureProvider<SessionStore>((ref) async {
  final logger = await ref.watch(appLoggerProvider.future);
  dev.log('[sessionStoreProvider] init start');
  unawaited(logger.info('session_store.init_start'));
  final paths = await ref.watch(appPathsProvider.future);
  dev.log('[sessionStoreProvider] got paths, themesDir=${paths.themesDir.path}');
  unawaited(logger.info('session_store.got_paths', attrs: {'themesDir': paths.themesDir.path}));
  final nodeStore = await ref.watch(nodeStoreProvider.future);
  dev.log('[sessionStoreProvider] got nodeStore');
  unawaited(logger.info('session_store.got_nodeStore'));
  return SessionStore(
    getSessionPathForNode: (nodeId) async {
      // 诊断用：日志 tag 搜 get_session_path / session_path_diag
      // 用于区分 DB 幽灵节点 / session.md 丢失 / 路径漂移 / 数据目录错位。
      final themesDirPath = paths.themesDir.path;
      final rootDirPath = paths.rootDir.path;
      dev.log(
        '[getSessionPathForNode] start nodeId=$nodeId '
        'rootDir=$rootDirPath themesDir=$themesDirPath',
      );
      unawaited(logger.info('get_session_path.start', attrs: {
        'nodeId': nodeId,
        'rootDir': rootDirPath,
        'themesDir': themesDirPath,
      }));

      String? dbSessionPath;
      String? dbNodePath;
      String? dbThemeId;
      var dbRowFound = false;
      var dbSessionExists = false;
      var dbNodeDirExists = false;

      try {
        final row = await nodeStore.getNodeRow(nodeId: nodeId);
        dbRowFound = true;
        dbSessionPath = row['sessionPath'] as String?;
        dbNodePath = row['nodePath'] as String?;
        dbThemeId = row['themeId'] as String?;
        final sessionPath = dbSessionPath!;
        dbSessionExists = await File(sessionPath).exists();
        if (dbNodePath != null) {
          dbNodeDirExists = await Directory(dbNodePath).exists();
        }
        // 相对路径原始值（inflate 前）便于对照磁盘 / 根目录迁移
        final rawRows = await nodeStore.db.query(
          'nodes',
          columns: ['sessionPath', 'nodePath', 'themeId'],
          where: 'nodeId = ?',
          whereArgs: [nodeId],
          limit: 1,
        );
        final rawSession =
            rawRows.isEmpty ? null : rawRows.single['sessionPath'] as String?;
        final rawNode =
            rawRows.isEmpty ? null : rawRows.single['nodePath'] as String?;

        dev.log(
          '[getSessionPathForNode] DB hit nodeId=$nodeId themeId=$dbThemeId '
          'sessionAbs=$sessionPath exists=$dbSessionExists '
          'nodeDir=$dbNodePath nodeDirExists=$dbNodeDirExists '
          'rawSession=$rawSession rawNode=$rawNode',
        );
        unawaited(logger.info('get_session_path.db_hit', attrs: {
          'nodeId': nodeId,
          'themeId': dbThemeId,
          'sessionPath': sessionPath,
          'sessionExists': dbSessionExists,
          'nodePath': dbNodePath,
          'nodeDirExists': dbNodeDirExists,
          'rawSessionPath': rawSession,
          'rawNodePath': rawNode,
        }));
        if (dbSessionExists) {
          return sessionPath;
        }
        // 进一步：node 目录在、只有 session.md 丢了？
        if (dbNodeDirExists && dbNodePath != null) {
          final metaPath = p.join(dbNodePath, 'node.meta.json');
          final metaExists = await File(metaPath).exists();
          final sessionAtNode = p.join(dbNodePath, 'session.md');
          final sessionAtNodeExists = await File(sessionAtNode).exists();
          dev.log(
            '[getSessionPathForNode] stale session but nodeDir ok: '
            'metaExists=$metaExists sessionAtNode=$sessionAtNode '
            'sessionAtNodeExists=$sessionAtNodeExists '
            'hint=meta_only_missing_session → reindex 不够，需补 session.md',
          );
          unawaited(logger.info('get_session_path.meta_only_at_db_path', attrs: {
            'nodeId': nodeId,
            'nodePath': dbNodePath,
            'metaExists': metaExists,
            'sessionAtNodeExists': sessionAtNodeExists,
          }));
        }
        dev.log(
          '[getSessionPathForNode] stale DB path, falling back to filesystem, '
          'nodeId=$nodeId',
        );
        unawaited(logger.info('get_session_path.stale_db', attrs: {
          'nodeId': nodeId,
          'sessionPath': sessionPath,
          'nodePath': dbNodePath,
        }));
      } catch (e) {
        dev.log(
          '[getSessionPathForNode] DB miss, falling back to filesystem, '
          'nodeId=$nodeId error=$e',
        );
        unawaited(logger.info('get_session_path.db_miss', attrs: {
          'nodeId': nodeId,
          'error': e.toString(),
        }));
      }

      final themesDir = paths.themesDir;
      dev.log(
        '[getSessionPathForNode] last resort recursive scan '
        'themesDir=${themesDir.path} themesDirExists=${await themesDir.exists()}',
      );
      if (!await themesDir.exists()) {
        unawaited(logger.info('get_session_path.themes_dir_missing', attrs: {
          'themesDir': themesDir.path,
        }));
        throw StateError('Themes dir not found: ${themesDir.path}');
      }

      // 扫描统计：帮助判断 reindex 是否有用
      var dirsVisited = 0;
      var fullMatches = 0; // meta 匹配 + session.md 存在
      var metaOnlyMatches = 0; // meta 匹配但无 session.md
      var sessionWithoutMeta = 0; // 有 session.md 但无/不匹配 meta
      String? metaOnlyDir;
      String? fullMatchPath;

      Future<void> recursiveScan(Directory dir) async {
        final entities = await dir.list(followLinks: false).toList();
        for (final entity in entities) {
          if (entity is! Directory) continue;
          dirsVisited++;
          final possibleSessionPath = p.join(entity.path, 'session.md');
          final metaPath = p.join(entity.path, 'node.meta.json');
          final sessionExists = await File(possibleSessionPath).exists();
          final metaExists = await File(metaPath).exists();

          var metaMatches = false;
          if (metaExists) {
            try {
              final metaText = await File(metaPath).readAsString();
              final metaJson = jsonDecode(metaText) as Map<String, Object?>;
              metaMatches = metaJson['nodeId'] == nodeId;
            } catch (e) {
              dev.log(
                '[getSessionPathForNode] meta parse fail dir=${entity.path} e=$e',
              );
            }
          }

          if (metaMatches && sessionExists) {
            fullMatches++;
            fullMatchPath ??= possibleSessionPath;
          } else if (metaMatches && !sessionExists) {
            metaOnlyMatches++;
            metaOnlyDir ??= entity.path;
            dev.log(
              '[getSessionPathForNode] META_ONLY match (no session.md) '
              'dir=${entity.path}',
            );
          } else if (sessionExists && !metaMatches) {
            sessionWithoutMeta++;
          }

          await recursiveScan(entity);
        }
      }

      await recursiveScan(themesDir);

      final resolvedFull = fullMatchPath;
      if (resolvedFull != null) {
        dev.log(
          '[getSessionPathForNode] recursive FULL hit nodeId=$nodeId '
          'sessionPath=$resolvedFull '
          'dirsVisited=$dirsVisited full=$fullMatches metaOnly=$metaOnlyMatches',
        );
        unawaited(logger.info('get_session_path.recursive_hit', attrs: {
          'nodeId': nodeId,
          'sessionPath': resolvedFull,
          'dirsVisited': dirsVisited,
          'fullMatches': fullMatches,
          'metaOnlyMatches': metaOnlyMatches,
        }));
        unawaited(
          nodeStore.updateNodeSessionPath(
            nodeId: nodeId,
            sessionPath: resolvedFull,
          ),
        );
        return resolvedFull;
      }

      // 最终诊断：reindex / 搜索修复能否救
      final diagnosis = <String, Object?>{
        'nodeId': nodeId,
        'dbRowFound': dbRowFound,
        'dbSessionExists': dbSessionExists,
        'dbNodeDirExists': dbNodeDirExists,
        'dbSessionPath': dbSessionPath,
        'dbNodePath': dbNodePath,
        'dbThemeId': dbThemeId,
        'dirsVisited': dirsVisited,
        'fullMatches': fullMatches,
        'metaOnlyMatches': metaOnlyMatches,
        'sessionWithoutMeta': sessionWithoutMeta,
        'metaOnlyDir': metaOnlyDir,
        'themesDir': themesDir.path,
      };

      String fixHint;
      if (metaOnlyMatches > 0 || (dbNodeDirExists && !dbSessionExists)) {
        // 磁盘有节点目录/meta，缺 session.md：reindex 只写路径不造文件 → 不够
        fixHint =
            'meta_exists_session_missing: startup sync/reindex 不够；'
            '需补空 session.md 或从备份恢复。搜索「立即修复」只重建 FTS，无效。';
      } else if (!dbRowFound && fullMatches == 0 && metaOnlyMatches == 0) {
        fixHint =
            'ghost_or_wrong_datadir: DB/磁盘均无此 node；'
            '可能树缓存脏数据或 rootDir 不一致。reindex 会删 DB 幽灵行。';
      } else if (dbRowFound && !dbNodeDirExists && fullMatches == 0) {
        fixHint =
            'db_orphan_no_disk: DB 有行磁盘无目录；'
            '启动 syncFromDisk 本应删孤儿——若仍出现说明 list 未走 sync 或另一数据目录。';
      } else {
        fixHint =
            'unknown: 把 session_path_diag 整段日志发回分析。'
            '搜索 rebuildAll 不能修 session 路径。';
      }
      diagnosis['fixHint'] = fixHint;

      dev.log(
        '[getSessionPathForNode] NOT FOUND session_path_diag=$diagnosis',
      );
      unawaited(logger.info('get_session_path.not_found', attrs: diagnosis));
      unawaited(logger.info('session_path_diag', attrs: diagnosis));
      throw StateError(
        'Session path not found for nodeId=$nodeId '
        '(see logs: session_path_diag; $fixHint)',
      );
    },
  );
});


// ── TTS（语音播放） ──

/// TTS 服务 Provider。
///
/// iOS 使用 [AppleTtsService]（桥接 AVSpeechSynthesizer），
/// 其他平台（Android / 桌面）使用 [NoOpTtsService] 静默桩。
final ttsServiceProvider = Provider<TtsService?>((ref) {
  if (Platform.isIOS) {
    return AppleTtsService();
  }
  return NoOpTtsService();
});

// ── 关键词排行榜（per-theme + 全局） ──

/// 单个 theme 的 `keyword_analysis.json` 文件读写器。
///
/// 输入：[themeId] = theme 目录名（即 `themes/<themeId>`）。
/// 首次读取时自动初始化空骨架。
final keywordAnalysisStorageProvider =
    FutureProvider.family<KeywordAnalysisStorage, String>((ref, themeId) async {
  final paths = await ref.watch(appPathsProvider.future);
  final themePath = p.join(paths.themesDir.path, themeId);
  return KeywordAnalysisStorage(themePath: themePath);
});

/// 全局 `keyword_global.json` 文件读写器（含反向索引 keyword_leaf_map）。
final keywordGlobalStorageProvider = FutureProvider<KeywordGlobalStorage>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return KeywordGlobalStorage(rootDir: paths.rootDir.path);
});

/// 全局 `keyword_category_catalog.json` 文件读写器。
///
/// 首次读取时自动写入默认 10 个分类（id 由程序生成的 8 位短 ID）。
final keywordCategoryStorageProvider =
    FutureProvider<KeywordCategoryStorage>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return KeywordCategoryStorage(rootDir: paths.rootDir.path);
});

/// 全局 `clips.json` 文件读写器（碎片库）。
///
/// 碎片库是一个全局文本暂存区，存术语/关键词/常用句式，
/// 在不同对话里反复取用。不绑定 session/node/theme。
final clipStorageProvider = FutureProvider<ClipStorage>((ref) async {
  final paths = await ref.watch(appPathsProvider.future);
  return ClipStorage(rootDir: paths.rootDir.path);
});

/// 单个 theme 的关键词分析状态机服务（依赖对应 [keywordAnalysisStorageProvider]）。
///
/// 输入：[themeId] = theme 目录名。
/// 提供 leaf 三态状态机（pending / fresh / stale）+ 反向查询。
final keywordAnalysisServiceProvider =
    FutureProvider.family<KeywordAnalysisService, String>((ref, themeId) async {
  final storage = await ref.watch(keywordAnalysisStorageProvider(themeId).future);
  return KeywordAnalysisService(storage: storage);
});

/// Prompt A 关键词抽取服务（无状态，注册单例即可）。
///
/// 一次性调用 [KeywordExtractionService.extract] 跑 LLM 并返回
/// [KeywordExtractionResult]（含已校验的 keywords + 可选 pendingNewCategory）。
/// 任何不合规输出都会抛出 [KeywordExtractionException]，由调用方整体拒绝并保留旧数据。
final keywordExtractionServiceProvider = Provider<KeywordExtractionService>((ref) {
  return KeywordExtractionService();
});

/// Prompt B 聚合 + score 计算服务（无状态，注册单例即可）。
///
/// 一次性调用 [KeywordAggregationService.aggregate] 跑 LLM 并返回
/// 已校验的 `List<GlobalKeywordEntry>`（含 score 0.0-1.0 clamp）。
/// 任何不合规输出都抛出 [KeywordAggregationException]，由调用方整体拒绝并保留旧数据。
final keywordAggregationServiceProvider = Provider<KeywordAggregationService>((ref) {
  return KeywordAggregationService();
});
