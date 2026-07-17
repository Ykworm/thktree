import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:thk_tree/data/services/session_markdown.dart';
// 延迟加载：ShareCardWidget 间接依赖 gpt_markdown 等较重 UI 库，
// 仅在 shareAsImage 真正截图时才需要，避免服务层被静态拖入重依赖。
import 'package:thk_tree/ui/core/shared/share_card_widget.dart'
    deferred as scw;

/// 分享内容过高/过大，无法落成单张图片。
class ShareContentTooLargeException implements Exception {
  ShareContentTooLargeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 分享问答对为图片
///
/// 流程：构建 ShareCardWidget → 近透明 overlay 布局 → toImage → 写临时文件 → 系统分享
class ShareService {
  /// GPU 纹理边长上限（多数设备 4096；略保守避免半边被裁 / toImage 抛错）。
  static const double _maxTextureEdge = 4096;

  /// 允许的最小 pixelRatio：极长整聊会降到此值（约可撑 ~2 万逻辑像素高）。
  static const double _minPixelRatio = 0.2;

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
    final devicePr = mq.devicePixelRatio;
    // 卡片逻辑宽：不超过屏宽，避免横向溢出；不小于 320 保证可读。
    final cardWidth = mq.size.width.clamp(320.0, 420.0);
    final textDirection = Directionality.of(context);
    final overlay = Overlay.of(context, rootOverlay: true);

    await scw.loadLibrary();
    final boundary = GlobalKey();

    // 注意：
    // - Opacity(0) 会跳过绘制，toImage 会失败 → 必须用极低但不为 0 的 opacity
    // - 负坐标屏外在部分机型上会被裁 → 放在 (0,0) 用几乎透明叠层
    // - 宽度用 OverflowBox 钉死，避免约束不稳导致右半空白/裁切
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 0,
        top: 0,
        child: Opacity(
          opacity: 0.02,
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
      await _waitForPaint();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _waitForPaint();

      final renderObject = boundary.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        throw StateError('ShareService: RenderRepaintBoundary not found');
      }

      final size = renderObject.size;
      if (size.width <= 0 || size.height <= 0) {
        throw StateError('ShareService: invalid share card size $size');
      }

      // 按纹理上限压 pixelRatio。长图必须允许 pr < 1（旧代码强制 pr≥1，
      // 导致 toImage 失败，上层却一律提示「内容过多」）。
      var pr = devicePr;
      pr = math.min(pr, _maxTextureEdge / size.width);
      pr = math.min(pr, _maxTextureEdge / size.height);
      if (pr < _minPixelRatio) {
        // 仍装不下：真正「内容过多」
        throw ShareContentTooLargeException(
          'share card too tall: ${size.width.toStringAsFixed(0)}×'
          '${size.height.toStringAsFixed(0)}',
        );
      }

      debugPrint(
        '[ShareService] capture size=${size.width.toStringAsFixed(0)}×'
        '${size.height.toStringAsFixed(0)} pr=${pr.toStringAsFixed(2)} '
        'msgs=${messages.length}',
      );

      final ui.Image image = await renderObject.toImage(pixelRatio: pr);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('ShareService: Failed to encode image');
      }
      final pngBytes = byteData.buffer.asUint8List();

      final tempDirPath = (await getTemporaryDirectory()).path;
      final file = File(
        '$tempDirPath/thktree_share_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
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
