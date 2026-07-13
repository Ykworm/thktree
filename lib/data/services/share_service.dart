import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
// 延迟加载：ShareCardWidget 间接依赖 gpt_markdown 等较重 UI 库，
// 仅在 shareAsImage 真正截图时才需要，避免服务层被静态拖入重依赖。
import 'package:thk_tree/ui/core/shared/share_card_widget.dart'
    deferred as scw;

/// 分享问答对为图片
///
/// 流程：构建 ShareCardWidget → offscreen 渲染 → toImage → 写临时文件 → 系统分享
class ShareService {
  /// 将一组消息生成图片并调起系统分享面板。
  ///
  /// [messages] 按时间顺序排列；每条消息可携带本地已加载的图片字节（[ShareMessage.image]）。
  /// [sharePositionOrigin] iPad 上分享弹窗的锚点位置（必传，否则 iPad 会崩溃）。
  static Future<void> shareAsImage({
    required BuildContext context,
    required List<ShareMessage> messages,
    Rect? sharePositionOrigin,
  }) async {
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;

    // 1. 按需加载重 UI 依赖（gpt_markdown 等），构建 widget 并插入 overlay（offscreen 渲染）
    await scw.loadLibrary();
    final boundary = GlobalKey();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000, // 移出屏幕，用户不可见
        top: -10000,
        child: RepaintBoundary(
          key: boundary,
          child: scw.ShareCardWidget(
            messages: messages,
          ),
        ),
      ),
    );
    overlay.insert(entry);

    try {
      // 2. 等待一帧让 widget 完成布局和渲染
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final renderObject = boundary.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('ShareService: RenderRepaintBoundary not found');
      }

      // 3. 截图并转 PNG 字节
      final ui.Image image = await renderObject.toImage(
        pixelRatio: pixelRatio,
      );
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('ShareService: Failed to encode image');
      }
      final pngBytes = byteData.buffer.asUint8List();

      // 4. 写入临时文件
      final tempDirPath = (await getTemporaryDirectory()).path;
      final file = File(
        '$tempDirPath/thktree_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      // 5. 系统分享
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      // 6. 清理 overlay
      entry.remove();
    }
  }
}
