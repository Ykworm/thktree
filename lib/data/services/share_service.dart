import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
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
/// 流程：构建 ShareCardWidget → 近透明 overlay 布局 → 高清截图
/// （超 GPU 纹理上限时纵向分片 + 软件拼接）→ 写临时文件 → 系统分享
class ShareService {
  /// 单次 GPU 栅格化边长上限（多数设备 4096；分片时每片不超此值）。
  static const double _maxTextureEdge = 4096;

  /// 最终输出长边上限（分片拼接后的物理像素），防 OOM。
  static const int _maxOutputLongEdge = 24576;

  /// 清晰度下限：长文宁可分片，也不再压到 0.2 这种糊字档。
  static const double _minPixelRatio = 1.5;

  /// 分享图 pixelRatio 上限（再高收益有限、文件暴涨）。
  static const double _maxPixelRatio = 3.0;

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
    // - Overlay/_Theater 对 Positioned(仅 left/top) 子树给的是无界约束；
    //   OverflowBox 自身会吃满父约束，无界时变成 Infinity×Infinity 直接 assert。
    //   因此先用有限 SizedBox 兜住外层，再用 OverflowBox 放宽高度，
    //   让整聊长卡按内容长高（可超屏），宽度钉死避免右半空白/裁切。
    // - RepaintBoundary 在 Opacity 内侧：toImage 取 boundary 自身 layer，
    //   不受祖先 0.02 透明度影响，导出图仍是不透明的。
    final slotHeight = mq.size.height.clamp(1.0, double.infinity);
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
                child: SizedBox(
                  width: cardWidth,
                  height: slotHeight,
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

      final pr = _resolvePixelRatio(
        logicalSize: size,
        devicePr: devicePr,
      );

      debugPrint(
        '[ShareService] capture size=${size.width.toStringAsFixed(0)}×'
        '${size.height.toStringAsFixed(0)} pr=${pr.toStringAsFixed(2)} '
        'msgs=${messages.length} '
        'out≈${(size.width * pr).round()}×${(size.height * pr).round()}',
      );

      final pngBytes = await _rasterizeToPng(renderObject, pixelRatio: pr);

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

  /// 解析截图像素比：优先设备 DPR（封顶 [_maxPixelRatio]），
  /// 仅因「最终输出长边 / 宽度纹理」压低，**不再**为总高度压到 0.2。
  /// 超高内容走分片，而不是糊成一团。
  static double _resolvePixelRatio({
    required Size logicalSize,
    required double devicePr,
  }) {
    var pr = math.min(devicePr, _maxPixelRatio);
    // 宽度必须单次进 GPU
    pr = math.min(pr, _maxTextureEdge / logicalSize.width);
    // 最终拼接图长边安全上限（内存）
    final longEdge = math.max(logicalSize.width, logicalSize.height);
    pr = math.min(pr, _maxOutputLongEdge / longEdge);

    if (pr < _minPixelRatio) {
      throw ShareContentTooLargeException(
        'share card too tall for sharp capture: '
        '${logicalSize.width.toStringAsFixed(0)}×'
        '${logicalSize.height.toStringAsFixed(0)}',
      );
    }
    return pr;
  }

  /// 高清栅格化：单张塞得进纹理则一次 [toImage]；
  /// 否则按纵向切片 [OffsetLayer.toImage]，再用 package:image 软件拼 PNG。
  static Future<Uint8List> _rasterizeToPng(
    RenderRepaintBoundary boundary, {
    required double pixelRatio,
  }) async {
    final size = boundary.size;
    final physicalW = (size.width * pixelRatio).ceil();
    final physicalH = (size.height * pixelRatio).ceil();

    // 单次可完整捕获
    if (physicalW <= _maxTextureEdge && physicalH <= _maxTextureEdge) {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('ShareService: Failed to encode image');
        }
        return byteData.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    }

    // RenderObject.layer 为 protected；分片截图只能经 OffsetLayer.toImage(rect)。
    // ignore: invalid_use_of_protected_member
    final rawLayer = boundary.layer;
    if (rawLayer is! OffsetLayer) {
      throw StateError('ShareService: OffsetLayer missing for tiled capture');
    }
    final layer = rawLayer;

    // 每片物理高度 ≤ 纹理上限；按物理像素推进，减少缝隙。
    final maxTilePhyH = _maxTextureEdge.floor();
    final full = img.Image(width: physicalW, height: physicalH);
    var phyY = 0;
    var tileIndex = 0;

    while (phyY < physicalH) {
      final tilePhyH = math.min(maxTilePhyH, physicalH - phyY);
      final logicalY = phyY / pixelRatio;
      final logicalH = tilePhyH / pixelRatio;
      final rect = Rect.fromLTWH(0, logicalY, size.width, logicalH);

      final tileUi = await layer.toImage(rect, pixelRatio: pixelRatio);
      try {
        final raw = await tileUi.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (raw == null) {
          throw StateError('ShareService: tile $tileIndex raw bytes null');
        }
        final tile = img.Image.fromBytes(
          width: tileUi.width,
          height: tileUi.height,
          bytes: raw.buffer,
          bytesOffset: raw.offsetInBytes,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
        img.compositeImage(full, tile, dstY: phyY);
        phyY += tileUi.height;
      } finally {
        tileUi.dispose();
      }
      tileIndex++;
    }

    debugPrint(
      '[ShareService] tiled capture tiles=$tileIndex '
      'out=${physicalW}x$physicalH',
    );

    final png = img.encodePng(full);
    return Uint8List.fromList(png);
  }

  static Future<void> _waitForPaint() async {
    final binding = WidgetsBinding.instance;
    await binding.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    await binding.endOfFrame;
  }
}
