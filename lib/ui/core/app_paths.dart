import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths({
    required this.rootDir,
    required this.themesDir,
    required this.logsDir,
    required this.tempDir,
    required this.indexDbPath,
    required this.appLogPath,
  });

  final Directory rootDir;
  final Directory themesDir;
  final Directory logsDir;
  final Directory tempDir;
  final String indexDbPath;
  final String appLogPath;

  String get todayLogPath {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return p.join(logsDir.path, 'app-$date.log');
  }

  static Future<AppPaths> load() async {
    final docDir = await getApplicationDocumentsDirectory();
    final rootDir = Directory(p.join(docDir.path, 'thktree'));
    final themesDir = Directory(p.join(rootDir.path, 'themes'));
    final logsDir = Directory(p.join(rootDir.path, 'logs'));
    final tempDir = Directory(p.join(rootDir.path, 'temp'));
    final indexDbPath = p.join(rootDir.path, 'index.sqlite');
    final appLogPath = p.join(logsDir.path, 'app.log');
    return AppPaths(
      rootDir: rootDir,
      themesDir: themesDir,
      logsDir: logsDir,
      tempDir: tempDir,
      indexDbPath: indexDbPath,
      appLogPath: appLogPath,
    );
  }

  Future<void> ensureCreated() async {
    if (!await rootDir.exists()) {
      await rootDir.create(recursive: true);
    }
    if (!await themesDir.exists()) {
      await themesDir.create(recursive: true);
    }
    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
  }

  String toRootRelativePath(String path) {
    if (p.isAbsolute(path)) {
      return p.normalize(p.relative(path, from: rootDir.path));
    }
    return p.normalize(path);
  }

  String toAbsolutePath(String path) {
    if (p.isAbsolute(path)) {
      return p.normalize(path);
    }
    return p.normalize(p.join(rootDir.path, path));
  }
}
