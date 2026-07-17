import 'dart:io';
import 'dart:math' as math;
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
/// 流程：构建 ShareCardWidget → 透明 overlay 布局 → toImage → 写临时文件 → 系统分享
class ShareService {
  /// GPU 纹理边长上限（多数 iOS/Android 为 4096；保守取值避免半边被裁）。
  static const double _maxTextureEdge = 4096;

  /// 将一组消息生成图片并调起系统分享面板。
  ///
  /// [messages] 按时间顺序排列；每条消息可携带本地已加载的图片字节（[ShareMessage.image]）。
  /// [sharePositionOrigin] iPad 上分享弹窗的锚点位置（必传，否则 iPad 会崩溃）。
  static Future<void> shareAsImage({
    required BuildContext context,
    required List<ShareMessage> messages,
    Rect? sharePositionOrigin,
  }) async {
    final mq = MediaQuery.of(context);
    final pixelRatio = mq.devicePixelRatio;
    // 卡片逻辑宽：不超过屏宽，避免布局溢出后右侧被裁；也不小于 320 保证可读。
    final cardWidth = mq.size.width.clamp(320.0, 420.0);
    final textDirection = Directionality.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);

    await scw.loadLibrary();
    final boundary = GlobalKey();

    // 不用 left:-10000 屏外坐标：部分机型/系统对屏外层 toImage 会裁切。
    // 改为 opacity:0 叠在左上角布局，宽度用 OverflowBox 钉死。
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: Opacity(
          opacity: 0,
          child: IgnorePointer(
            child: MediaQuery(
              data: mq,
              child: Directionality(
                textDirection: textDirection,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: cardWidth,
                  maxWidth: cardWidth,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: RepaintBoundary(
                    key: boundary,
                    child: scw.ShareCardWidget(
                      messages: messages,
                      cardWidth: cardWidth,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);

    try {
      // 等布局 + markdown / 图片完成（多帧更稳）
      await _waitForPaint();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await _waitForPaint();

      final renderObject = boundary.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw Exception('ShareService: RenderRepaintBoundary not found');
      }

      // 按纹理上限压 pixelRatio，避免超高整聊图被 GPU 裁半
      final size = renderObject.size;
      if (size.width <= 0 || size.height <= 0) {
        throw Exception('ShareService: invalid share card size $size');
      }
      var pr = pixelRatio;
      final maxByW = _maxTextureEdge / size.width;
      final maxByH = _maxTextureEdge / size.height;
      pr = math.min(pr, math.min(maxByW, maxByH));
      if (pr < 1.0) pr = 1.0;

      final ui.Image image = await renderObject.toImage(pixelRatio: pr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw Exception('ShareService: Failed to encode image');
      }
      final pngBytes = byteData.buffer.asUint8List();

      final tempDirPath = (await getTemporaryDirectory()).path;
      final file = File(
        '$tempDirPath/thktree_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        sharePositionOrigin: sharePositionOrigin,
      );
    } finally {
      entry.remove();
    }
  }

  static Future<void> _waitForPaint() async {
    final binding = WidgetsBinding.instance;
    await binding.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    await binding.endOfFrame;
  }
}
