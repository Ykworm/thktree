import 'dart:developer';
import 'dart:io';

import 'package:path/path.dart' as p;

/// 聊天图片孤儿清理服务。
///
/// 磁盘上存在**两层不对称**的结构（务必以此为准，不要想当然当成同级）：
/// - `session.md` 位于嵌套的树目录：`themes/{themeId}/nodes/{nodeId}/.../session.md`
///   （树结构，节点可多层嵌套，nodeId 是 session.md 父目录名）
/// - `images/` 位于**扁平**目录：`themes/{themeId}/{nodeId}/images/`
///   （**没有** `nodes/` 这一层，与 chat 读图路径 `chat_controller`/`chat_screen`
///   的 `themesDir/{themeId}/{nodeId}/images` 一致）
/// 两者靠 `nodeId` 关联，并不在同一目录层级。
///
/// 文件名对应 session.md 消息头 `· image:<path>/<fileName>.jpg` 中的文件名。
///
/// 孤儿判定在**单个 node 内**完成（图片引用是 node 绑定的）：
/// 某 node 的 `images/` 目录里，文件名不在该 node 的 session.md 引用集合中的文件 = 孤儿。
///
/// 安全约束：
/// - 只处理 `.jpg` / `.jpeg` 文件，不动其他文件
/// - `pending_*.jpg` 的语义比"临时态"复杂：发送流程中图片先以 `pending_{ts}.jpg` 写入磁盘、
///   成功后 rename 成 `{msgId}.jpg` 并回写 session.md 引用；但真实数据里也存在
///   **长期保留 `pending_` 前缀、且已被 session.md 引用的正式图片**（rename 流程未执行）。
///   因此判定优先级是：先查 session.md 引用 —— 有引用则直接排除，绝不当孤儿；
///   只有"无引用 + 修改时间超过 [pendingGracePeriod]"的 `pending_` 文件，才视为
///   "发送失败/中断残留"可回收。保护期（默认 30 分钟）内的 `pending_` 一律保留，防误删正在发送的图片。
class ImageCleanupService {
  ImageCleanupService({required this.themesDir});

  final Directory themesDir;

  /// pending_ 文件安全阀：修改时间距现在超过该时长，才视为可回收孤儿。
  /// 正常发送流程不可能卡这么久，用于区分"正在发送"与"发送失败残留"。
  static const pendingGracePeriod = Duration(minutes: 30);

  /// 扫描所有 node 的图片，找出无引用的孤儿图片，并附带统计。
  ///
  /// **关键：单次递归遍历 `themesDir` 同时收集 `session.md` 与所有 `.jpg` 图片，
  /// 不再对每个 node 单独调用 `imagesDir.list()`。** 原因：iOS 真机（sandbox 容器）
  /// 上对构造出的 `themes/{themeId}/{nodeId}/images` 路径单独 `list()` 会抛
  /// `FileSystemException`（真机实测 56 个 node 全部失败），而同样从 `themesDir`
  /// 出发的递归 `list(recursive: true)` 正常工作（能找到 56 个 session.md）。
  /// 因此图片直接从递归流里按 nodeId 分组，彻底绕开会失败的二次 list()。
  ///
  /// 图片路径形如 `themes/{themeId}/{nodeId}/images/{file}.jpg` 或嵌套
  /// `themes/{themeId}/nodes/{nodeId}/images/{file}.jpg`，nodeId 始终是 `images`
  /// 段之前的目录名（见 [_nodeIdFromImagePath]），两种结构都正确。
  Future<ScanReport> scanAndReport() async {
    final images = <ImageEntry>[];
    var sessionFiles = 0;
    var imageFiles = 0;
    var imagesDirsHit = 0;
    var imagesDirsEmpty = 0;
    var listFailures = 0;
    var rawImageFiles = 0;

    final themesExists = await themesDir.exists();
    if (!themesExists) {
      log('[CleanImages.scan] themesDir NOT EXISTS: ${themesDir.path}');
      return ScanReport(
        images: images,
        sessionFiles: 0,
        imageFiles: 0,
        imagesDirsHit: 0,
        imagesDirsEmpty: 0,
        listFailures: 0,
        rawImageFiles: 0,
        themesExists: false,
      );
    }
    log('[CleanImages.scan] start themesDir=${themesDir.path}');

    // 单次递归遍历：session.md 收集起来稍后处理；图片按 nodeId 分组。
    // 不再对每个 node 单独 imagesDir.list()（iOS 真机上该调用会抛异常）。
    final imageFilesByNode = <String, List<File>>{};
    final sessionFilesList = <File>[];
    await for (final entity in themesDir.list(recursive: true)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name == 'session.md') {
        sessionFiles++;
        sessionFilesList.add(entity);
        continue;
      }
      final lower = entity.path.toLowerCase();
      if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg')) continue;
      // 递归流里实际见到的 .jpg 总数（诊断用，未经 nodeId 分组过滤）
      rawImageFiles++;
      final nodeId = _nodeIdFromImagePath(entity.path);
      if (nodeId == null) continue; // 不在图片目录下的图不归本服务管
      imageFilesByNode.putIfAbsent(nodeId, () => []).add(entity);
    }

    imageFiles = imageFilesByNode.values.fold(0, (s, l) => s + l.length);
    imagesDirsHit = imageFilesByNode.length;

    for (final sessionFile in sessionFilesList) {
      final nodeDir = sessionFile.parent;
      final nodeId = p.basename(nodeDir.path);
      final imgFiles = imageFilesByNode[nodeId] ?? const <File>[];
      if (imgFiles.isEmpty) imagesDirsEmpty++;

      // 收集该 node 被 session.md 引用的图片文件名集合
      final referenced = await _referencedImageNames(sessionFile);

      for (final imgEntity in imgFiles) {
        final fileName = p.basename(imgEntity.path);
        var isOrphan = !referenced.contains(fileName);

        // pending_ 文件：在保护期内视为"可能正在发送"，不当作孤儿
        if (isOrphan && fileName.startsWith('pending_')) {
          final stat = await imgEntity.stat();
          final age = DateTime.now().difference(stat.modified);
          if (age < pendingGracePeriod) isOrphan = false;
        }

        final size = await imgEntity.length();
        images.add(ImageEntry(
          path: imgEntity.path,
          nodeId: nodeId,
          sizeBytes: size,
          isOrphan: isOrphan,
        ));
      }
    }

    final r = ScanReport(
      images: images,
      sessionFiles: sessionFiles,
      imageFiles: imageFiles,
      imagesDirsHit: imagesDirsHit,
      imagesDirsEmpty: imagesDirsEmpty,
      listFailures: listFailures,
      rawImageFiles: rawImageFiles,
      themesExists: true,
    );
    log('[CleanImages.scan] DONE sessions=$sessionFiles '
        'imagesDirsHit=$imagesDirsHit imagesDirsEmpty=$imagesDirsEmpty '
        'imageFiles=$imageFiles orphans=${r.orphans.length}');
    return r;
  }

  /// 从图片绝对路径提取其所属 nodeId。
  ///
  /// 图片目录名可能是 `images`（当前布局）或历史布局的 `chat_images`
  /// （与 session.md 里 `· image:chat_images/...` 前缀对应），
  /// 只要目录名以 `images` 结尾即视为图片目录。nodeId 是该目录前的目录名，
  /// 与 session.md 父目录名一致。不在图片目录下的文件返回 null。
  String? _nodeIdFromImagePath(String path) {
    final dirParts = p.split(p.dirname(path));
    for (var i = dirParts.length - 1; i > 0; i--) {
      if (dirParts[i].toLowerCase().endsWith('images')) {
        return dirParts[i - 1];
      }
    }
    return null;
  }

  /// 扫描所有 node 的 images/ 目录，找出无引用的孤儿图片。
  /// 详见 [scanAndReport]，此方法是其 `orphans` 字段的便捷封装。
  Future<List<OrphanImage>> scanOrphans() async => (await scanAndReport()).orphans;

  /// 从 session.md 提取所有被引用的图片文件名集合。
  ///
  /// session.md 中 imagePath 形如 `chat_images/{fileName}.jpg`，
  /// 物理文件名在 node 的 `images/` 目录下，故只取 basename 比较。
  Future<Set<String>> _referencedImageNames(File sessionFile) async {
    final names = <String>{};
    if (!await sessionFile.exists()) return names;
    final content = await sessionFile.readAsString();
    final reg = RegExp(r'·\s*image:\s*(\S+)');
    for (final m in reg.allMatches(content)) {
      final raw = m.group(1);
      if (raw == null) continue;
      names.add(p.basename(raw));
    }
    return names;
  }

  /// 删除指定图片（**任意图片，含被聊天引用的"使用中"图片**），
  /// 返回成功释放的字节数。单个文件删除失败不影响其余（try-catch 吞掉）。
  ///
  /// 注意：删除"使用中"图片会导致对应聊天消息的图片缺失（文字仍在）。
  /// 是否允许删除由调用方（UI）结合教育提醒与二次确认决定，service 不做拦截。
  Future<int> deleteImages(List<ImageEntry> entries) async {
    var freed = 0;
    for (final e in entries) {
      final file = File(e.path);
      try {
        if (await file.exists()) {
          freed += await file.length();
          await file.delete();
        }
      } catch (_) {
        // 单个删除失败不阻断其余
      }
    }
    return freed;
  }

  /// 便捷封装：删除孤儿图片（见 [deleteImages]，逻辑一致）。
  Future<int> deleteOrphans(List<OrphanImage> orphans) async {
    final entries = orphans
        .map((o) => ImageEntry(
              path: o.path,
              nodeId: o.nodeId,
              sizeBytes: o.sizeBytes,
              isOrphan: true,
            ))
        .toList();
    return deleteImages(entries);
  }
}

/// 孤儿图片条目。
class OrphanImage {
  const OrphanImage({
    required this.path,
    required this.nodeId,
    required this.sizeBytes,
  });

  /// 绝对路径
  final String path;

  /// 所属 nodeId（便于日志 / 排查）
  final String nodeId;

  /// 文件大小（字节）
  final int sizeBytes;
}

/// 扫描结果 + 统计，便于 UI 展示与诊断。
class ScanReport {
  const ScanReport({
    required this.images,
    required this.sessionFiles,
    required this.imageFiles,
    required this.imagesDirsHit,
    required this.imagesDirsEmpty,
    required this.listFailures,
    required this.rawImageFiles,
    required this.themesExists,
  });

  /// 扫描到的全部图片（含在用与孤儿），UI 据此展示所有图片。
  final List<ImageEntry> images;

  /// 找到的 session.md 数量（约等于节点数）
  final int sessionFiles;

  /// 扫描到的图片文件总数
  final int imageFiles;

  /// 递归遍历流里实际见到的 `.jpg`/`.jpeg` 文件总数（未经 nodeId 分组过滤）。
  /// 诊断关键对比项：若 `rawImageFiles > 0` 但 `imagesDirsHit == 0`，
  /// 说明图片被找到了、只是目录名不被 [_nodeIdFromImagePath] 识别（如 `chat_images`）。
  /// 若 `rawImageFiles == 0`，说明递归遍历压根没见到任何 .jpg，问题在更外层（路径/位置）。
  final int rawImageFiles;

  /// 含图片的 node 数（单次递归遍历按 nodeId 分组得到）。
  /// =0 说明递归遍历没在任何 `images/` 下找到 .jpg（路径/结构问题）。
  final int imagesDirsHit;

  /// session.md 存在、但其 nodeId 下未找到任何图片的 node 数。
  final int imagesDirsEmpty;

  /// 保留字段：当前为单次递归扫描，不再对单个 images/ 目录单独 list()，
  /// 故恒为 0。曾用于统计 iOS 真机上 per-dir list() 抛异常的次数。
  final int listFailures;

  /// 数据根目录 themesDir 是否存在。false 说明 appPathsProvider 给的路径不对。
  final bool themesExists;

  /// 孤儿图片子集（无引用且不在保护期内的图片）
  List<OrphanImage> get orphans => images
      .where((e) => e.isOrphan)
      .map((e) => OrphanImage(
            path: e.path,
            nodeId: e.nodeId,
            sizeBytes: e.sizeBytes,
          ))
          .toList();
}

/// 扫描到的图片条目（含是否孤儿标记）。
class ImageEntry {
  const ImageEntry({
    required this.path,
    required this.nodeId,
    required this.sizeBytes,
    required this.isOrphan,
  });

  /// 绝对路径
  final String path;

  /// 所属 nodeId（便于日志 / 排查）
  final String nodeId;

  /// 文件大小（字节）
  final int sizeBytes;

  /// true = 无引用（可清理）；false = 被 session.md 引用（使用中，不可删）
  final bool isOrphan;
}
