import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:thk_tree/data/services/image_cleanup_service.dart';

void main() {
  group('ImageCleanupService', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('img_cleanup_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    Directory makeNode(String themeId, String nodeId) {
      // 真实物理结构：themes/{themeId}/{nodeId}（无 nodes/ 层）
      final dir = Directory(p.join(tempDir.path, 'themes', themeId, nodeId));
      dir.createSync(recursive: true);
      return dir;
    }

    Directory makeNodeWithNodesLayer(String themeId, String nodeId) {
      // 真实结构：session.md 在嵌套的 nodes/{nodeId}/ 下（树结构）
      final dir = Directory(p.join(tempDir.path, 'themes', themeId, 'nodes', nodeId));
      dir.createSync(recursive: true);
      return dir;
    }

    File makeImage(Directory nodeDir, String name, {DateTime? modified}) {
      // 真实结构：图片在扁平的 {themeId}/{nodeId}/images，与 session.md 的嵌套
      // nodes/ 树不同级。若 nodeDir 是嵌套路径（含 /nodes/），写到去掉该层后的扁平位置，
      // 与 chat 读图路径 themesDir/{themeId}/{nodeId}/images 一致。
      final flatPath = nodeDir.path.replaceFirst('/nodes/', '/');
      final file = File(p.join(flatPath, 'images', name));
      file.createSync(recursive: true);
      file.writeAsBytesSync(const [1, 2, 3, 4]); // 固定 4 bytes，便于校验释放空间
      if (modified != null) {
        file.setLastModifiedSync(modified);
      }
      return file;
    }

    File makeSession(Directory nodeDir, List<String> imagePaths) {
      final sb = StringBuffer();
      sb.writeln('---');
      sb.writeln('schema: session/v1');
      sb.writeln('---');
      sb.writeln();
      for (var i = 0; i < imagePaths.length; i++) {
        sb.writeln('## user · 2026-01-01T00:00:0${i}.000Z · msg_$i · image:${imagePaths[i]}');
      }
      final file = File(p.join(nodeDir.path, 'session.md'));
      file.writeAsStringSync(sb.toString());
      return file;
    }

    ImageCleanupService service() =>
        ImageCleanupService(themesDir: Directory(p.join(tempDir.path, 'themes')));

    test('正常引用的图片不判为孤儿', () async {
      final node = makeNode('thm1', 'nd1');
      makeImage(node, 'msg_1.jpg');
      makeSession(node, ['chat_images/msg_1.jpg']);
      final orphans = await service().scanOrphans();
      expect(orphans, isEmpty);
    });

    test('真实 msg_ ULID 文件名（有引用）正确排除', () async {
      // 真实数据示例：rename 成功后的正式文件名，前缀 msg_ + ULID
      // 见 newMsgId() → 'msg_${_newUlidUpper()}'，chat_controller.dart:575 用它重命名磁盘文件
      final node = makeNode('thm1', 'nd1');
      makeImage(node, 'msg_01KX1JHZPCB78TKE56JN0BGAQ1.jpg');
      makeSession(node, ['chat_images/msg_01KX1JHZPCB78TKE56JN0BGAQ1.jpg']);
      final orphans = await service().scanOrphans();
      expect(orphans, isEmpty);
    });

    test('未被引用的图片判为孤儿', () async {
      final node = makeNode('thm1', 'nd1');
      makeImage(node, 'msg_orphan.jpg');
      makeSession(node, ['chat_images/msg_1.jpg']);
      final orphans = await service().scanOrphans();
      expect(orphans.length, 1);
      expect(p.basename(orphans.first.path), 'msg_orphan.jpg');
      expect(orphans.first.nodeId, 'nd1');
    });

    test('新生 pending_ 文件受保护，不判为孤儿', () async {
      final node = makeNode('thm1', 'nd1');
      makeImage(node, 'pending_recent.jpg');
      makeSession(node, ['chat_images/msg_1.jpg']);
      final orphans = await service().scanOrphans();
      expect(orphans, isEmpty);
    });

    test('过期 pending_ 文件判为孤儿', () async {
      final node = makeNode('thm1', 'nd1');
      makeImage(node, 'pending_old.jpg',
          modified: DateTime.now().subtract(const Duration(hours: 1)));
      makeSession(node, ['chat_images/msg_1.jpg']);
      final orphans = await service().scanOrphans();
      expect(orphans.length, 1);
      expect(p.basename(orphans.first.path), 'pending_old.jpg');
    });

    test('图片引用按 node 隔离，不跨 node 串台', () async {
      final node1 = makeNode('thm1', 'nd1');
      final node2 = makeNode('thm1', 'nd2');
      makeImage(node1, 'shared.jpg');
      makeImage(node2, 'shared.jpg');
      makeSession(node1, ['chat_images/shared.jpg']);
      makeSession(node2, []); // nd2 未引用任何图片
      final orphans = await service().scanOrphans();
      expect(orphans.length, 1);
      expect(orphans.first.nodeId, 'nd2');
    });

    test('非 jpg 文件不被误清', () async {
      final node = makeNode('thm1', 'nd1');
      File(p.join(node.path, 'images', 'note.txt')).createSync(recursive: true);
      makeSession(node, ['chat_images/msg_1.jpg']);
      final orphans = await service().scanOrphans();
      expect(orphans, isEmpty);
    });

    test('删除孤儿释放空间并移除文件', () async {
      final node = makeNode('thm1', 'nd1');
      final orphan = makeImage(node, 'msg_orphan.jpg');
      makeSession(node, ['chat_images/msg_1.jpg']);
      final svc = service();
      final orphans = await svc.scanOrphans();
      expect(orphans.length, 1);
      final freed = await svc.deleteOrphans(orphans);
      expect(freed, 4);
      expect(await orphan.exists(), isFalse);
    });

    test('deleteOrphans 对不存在的文件不报错', () async {
      final svc = service();
      final freed = await svc.deleteOrphans([
        const OrphanImage(path: '/no/such/file.jpg', nodeId: 'ndX', sizeBytes: 0),
      ]);
      expect(freed, 0);
    });

    test('deleteImages 可删除"使用中"(被引用)图片，且释放空间', () async {
      // 产品决策：清理页允许删除任意图片（含被聊天引用的），仅由 UI 教育栏 + 二次确认把关。
      // 此测试锁定 service 层不拦截"使用中"图片的删除。
      final node = makeNode('thm1', 'nd1');
      final inUse = makeImage(node, 'msg_1.jpg');
      makeSession(node, ['chat_images/msg_1.jpg']);

      final report = await service().scanAndReport();
      final inUseEntry =
          report.images.firstWhere((e) => e.path == inUse.path);
      expect(inUseEntry.isOrphan, isFalse, reason: '该图被引用，标记为使用中');

      final freed = await service().deleteImages([inUseEntry]);
      expect(freed, 4);
      expect(await inUse.exists(), isFalse);
    });

    test('兼容旧的 nodes/ 层级结构也能扫描到孤儿', () async {
      final node = makeNodeWithNodesLayer('thm1', 'nd1');
      makeImage(node, 'msg_orphan.jpg');
      makeSession(node, ['chat_images/msg_1.jpg']);
      final orphans = await service().scanOrphans();
      expect(orphans.length, 1);
      expect(p.basename(orphans.first.path), 'msg_orphan.jpg');
    });

    test('回归(iOS)：图片在嵌套 nodes/{nodeId}/images 也能被递归找到', () async {
      // iPhone 真机现象：旧代码对每个 node 单独 list() 扁平 imagesDir 抛异常 → 0 图片。
      // 根因是旧代码只查 themes/{themeId}/{nodeId}/images（扁平）；
      // 若图片实际在嵌套 nodes/{nodeId}/images（旧布局），扁平路径不存在 → list 失败。
      // 新实现用单次递归遍历按 nodeId 分组，两种布局都能找到，不依赖 per-dir list()。
      final node = makeNodeWithNodesLayer('thm1', 'nd1');
      // 图片直接写到嵌套 images 目录（不放到扁平位置）
      final nestedImagesDir = Directory(
          p.join(tempDir.path, 'themes', 'thm1', 'nodes', 'nd1', 'images'));
      nestedImagesDir.createSync(recursive: true);
      File(p.join(nestedImagesDir.path, 'msg_1.jpg'))
          .writeAsBytesSync(const [1, 2, 3, 4]);
      File(p.join(nestedImagesDir.path, 'msg_orphan.jpg'))
          .writeAsBytesSync(const [1, 2, 3, 4]);
      makeSession(node, ['chat_images/msg_1.jpg']);

      final report = await service().scanAndReport();
      expect(report.images.length, 2, reason: '嵌套 images 目录下的图必须被找到');
      expect(report.orphans.length, 1);
      expect(p.basename(report.orphans.first.path), 'msg_orphan.jpg');
      // nodeId 正确归属，且路径确实是嵌套位置（旧扁平公式会找不到）
      expect(report.images.every((e) => e.nodeId == 'nd1'), isTrue);
      expect(
          report.images.any((e) => e.path.contains('/nodes/nd1/images/')), isTrue);
    });

    test('兼容旧布局图片目录名为 chat_images（非 images）', () async {
      // 真实数据：旧版本把图片写在 chat_images/ 目录（与 session.md 的
      // `chat_images/` 前缀对应），当前部分用户磁盘上仍是此布局。
      // _nodeIdFromImagePath 必须识别"目录名以 images 结尾"，否则会漏掉全部图片
      // （iPhone 真机实测：命中图片目录 0、空目录 56，正是这个原因）。
      final node = makeNode('thm1', 'nd1');
      final chatImagesDir =
          Directory(p.join(tempDir.path, 'themes', 'thm1', 'nd1', 'chat_images'));
      chatImagesDir.createSync(recursive: true);
      File(p.join(chatImagesDir.path, 'msg_1.jpg'))
          .writeAsBytesSync(const [1, 2, 3, 4]);
      File(p.join(chatImagesDir.path, 'msg_orphan.jpg'))
          .writeAsBytesSync(const [1, 2, 3, 4]);
      makeSession(node, ['chat_images/msg_1.jpg']);

      final report = await service().scanAndReport();
      expect(report.images.length, 2, reason: 'chat_images 目录下的图必须被找到');
      expect(report.orphans.length, 1);
      expect(p.basename(report.orphans.first.path), 'msg_orphan.jpg');
      expect(report.images.every((e) => e.path.contains('/chat_images/')), isTrue);
      expect(report.rawImageFiles, 2, reason: '递归流应见到 2 个原始 jpg');
    });

    test('真实结构：session.md 嵌套 nodes/ + images 扁平，引用正确排除', () async {
      // 复现模拟器实测结构：
      // themes/thm1/nodes/nd1/session.md（嵌套）
      // themes/thm1/nd1/images/msg_1.jpg（扁平，被引用）
      // themes/thm1/nd1/images/msg_orphan.jpg（扁平，孤儿）
      final node = makeNodeWithNodesLayer('thm1', 'nd1');
      makeImage(node, 'msg_1.jpg');
      makeImage(node, 'msg_orphan.jpg');
      makeSession(node, ['chat_images/msg_1.jpg']);
      final report = await service().scanAndReport();
      // 两张图都被扫到（扁平 images 目录）
      expect(report.images.length, 2);
      // 只有未被引用的那张是孤儿
      expect(report.orphans.length, 1);
      expect(p.basename(report.orphans.first.path), 'msg_orphan.jpg');
      // 被引用的图 isOrphan=false，不被误删
      final inUse = report.images.firstWhere((e) => e.path.endsWith('msg_1.jpg'));
      expect(inUse.isOrphan, isFalse);
    });

    test('scanAndReport 返回带 isOrphan 标记的全量图片', () async {
      final node = makeNode('thm1', 'nd1');
      makeImage(node, 'msg_1.jpg'); // 被引用 → 在用
      makeImage(node, 'msg_orphan.jpg'); // 无引用 → 孤儿
      makeSession(node, ['chat_images/msg_1.jpg']);
      final report = await service().scanAndReport();

      // 全部图片都出现，孤儿子集正确
      expect(report.images.length, 2);
      expect(report.orphans.length, 1);
      expect(p.basename(report.orphans.first.path), 'msg_orphan.jpg');

      // isOrphan 标记正确
      final inUse = report.images.firstWhere((e) => e.path.endsWith('msg_1.jpg'));
      final orphan = report.images.firstWhere((e) => e.path.endsWith('msg_orphan.jpg'));
      expect(inUse.isOrphan, isFalse);
      expect(orphan.isOrphan, isTrue);
    });
  });
}
