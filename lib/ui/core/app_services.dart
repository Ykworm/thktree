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
import 'package:thk_tree/data/services/llm_client.dart';
import 'package:thk_tree/data/services/settings_store.dart';
import 'package:thk_tree/data/stores/llm_config_store.dart';
import 'package:thk_tree/data/stores/node_store.dart';
import 'package:thk_tree/data/stores/session_store.dart';
import 'package:thk_tree/data/models/llm_provider_config.dart';
import 'package:thk_tree/data/stores/theme_store.dart';

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
  final paths = await ref.watch(appPathsProvider.future);
  return AppDatabase.open(path: paths.indexDbPath);
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

final llmClientProvider = FutureProvider<LlmClient>((ref) async {
  final settings = await ref.watch(appSettingsProvider.future);
  return LlmClient.forProvider(settings.llmProvider);
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
  await store.migrateFromLegacy();
  return store.loadAll();
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
      dev.log('[getSessionPathForNode] start, nodeId=$nodeId');
      unawaited(logger.info('get_session_path.start', attrs: {'nodeId': nodeId}));
      
      // First, try to reindex all themes from disk to make sure all nodes are in DB!
      dev.log('[getSessionPathForNode] reindexing all themes first...');
      final themeStore = await ref.read(themeStoreProvider.future);
      await themeStore.reindexThemesFromDisk();
      final themes = await themeStore.listThemes();
      for (final theme in themes) {
        final themeRow = await nodeStore.getThemeRow(themeId: theme.themeId);
        final themePath = themeRow['themePath']! as String;
        dev.log('[getSessionPathForNode] reindexing theme ${theme.themeId} at $themePath');
        await nodeStore.reindexNodesFromDisk(themePath: themePath);
      }
      
      try {
        final row = await nodeStore.getNodeRow(nodeId: nodeId);
        final sessionPath = row['sessionPath']! as String;
        final exists = await File(sessionPath).exists();
        dev.log('[getSessionPathForNode] DB hit, nodeId=$nodeId, sessionPath=$sessionPath, exists=$exists');
        unawaited(logger.info('get_session_path.db_hit', attrs: {'nodeId': nodeId, 'sessionPath': sessionPath, 'exists': exists}));
        if (exists) {
          return sessionPath;
        }
        dev.log('[getSessionPathForNode] stale DB path, falling back to filesystem, nodeId=$nodeId');
        unawaited(logger.info('get_session_path.stale_db', attrs: {'nodeId': nodeId}));
      } catch (e) {
        dev.log('[getSessionPathForNode] DB miss, falling back to filesystem, nodeId=$nodeId, error=$e');
        unawaited(
          logger.info('get_session_path.db_miss', attrs: {'nodeId': nodeId, 'error': e.toString()}),
        );
      }

      // If still not found, try recursive scan (as a last resort)
      final themesDir = paths.themesDir;
      dev.log('[getSessionPathForNode] last resort: recursive scan themesDir=${themesDir.path}');
      if (!await themesDir.exists()) {
        throw StateError('Themes dir not found: ${themesDir.path}');
      }
      
      Future<String?> recursiveFindSession(Directory dir) async {
        final entities = await dir.list(followLinks: false).toList();
        for (final entity in entities) {
          if (entity is Directory) {
            final possibleSessionPath = p.join(entity.path, 'session.md');
            if (await File(possibleSessionPath).exists()) {
              // Check if this directory has a node.meta.json with matching nodeId
              final metaPath = p.join(entity.path, 'node.meta.json');
              if (await File(metaPath).exists()) {
                try {
                  final metaText = await File(metaPath).readAsString();
                  final metaJson = jsonDecode(metaText) as Map<String, Object?>;
                  if (metaJson['nodeId'] == nodeId) {
                    return possibleSessionPath;
                  }
                } catch (_) {}
              }
            }
            // Recurse into subdirectories
            final found = await recursiveFindSession(entity);
            if (found != null) {
              return found;
            }
          }
        }
        return null;
      }
      
      final found = await recursiveFindSession(themesDir);
      if (found != null) {
        dev.log('[getSessionPathForNode] recursive hit, nodeId=$nodeId, sessionPath=$found');
        unawaited(logger.info('get_session_path.recursive_hit', attrs: {'nodeId': nodeId, 'sessionPath': found}));
        unawaited(nodeStore.updateNodeSessionPath(nodeId: nodeId, sessionPath: found));
        return found;
      }
      dev.log('[getSessionPathForNode] NOT FOUND anywhere, nodeId=$nodeId');
      unawaited(logger.info('get_session_path.not_found', attrs: {'nodeId': nodeId}));
      throw StateError('Session path not found for nodeId=$nodeId');
    },
  );
});

