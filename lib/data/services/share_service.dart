import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thk_tree/ui/core/shared/share_card_widget.dart';

/// 分享问答对为图片
///
/// 流程：构建 ShareCardWidget → offscreen 渲染 → toImage → 写临时文件 → 系统分享
class ShareService {
  /// 将问答对生成图片并调起系统分享面板。
  ///
  /// [userQuestion] 可为 null（仅分享 AI 回答）。
  /// [assistantAnswer] 不能为空。
  /// [sharePositionOrigin] iPad 上分享弹窗的锚点位置（必传，否则 iPad 会崩溃）。
  static Future<void> shareAsImage({
    required BuildContext context,
    required String? userQuestion,
    required String assistantAnswer,
    Rect? sharePositionOrigin,
  }) async {
    final boundary = GlobalKey();
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // 1. 构建 widget 并插入 overlay（offscreen 渲染）
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000, // 移出屏幕，用户不可见
        top: -10000,
        child: RepaintBoundary(
          key: boundary,
          child: ShareCardWidget(
            userQuestion: userQuestion,
            assistantAnswer: assistantAnswer,
          ),
        ),
      ),
    );
    overlay.insert(entry);

    try {
      // 2. 等待一帧让 widget 完成布局和渲染
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // 3. 截图
      final renderObject = boundary.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('ShareService: RenderRepaintBoundary not found');
      }
      final ui.Image image = await renderObject.toImage(
        pixelRatio: pixelRatio,
      );

      // 4. 转 PNG 字节
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('ShareService: Failed to encode image');
      }
      final pngBytes = byteData.buffer.asUint8List();

      // 5. 写入临时文件
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/thktree_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      // 6. 系统分享
      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      // 7. 清理 overlay
      entry.remove();
    }
  }
}
