import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 图片压缩与磁盘读写工具。
///
/// 压缩策略：最长边 ≤ [maxLongSide]，JPEG quality [quality]。
/// 用于聊天图片持久化（预览用）和 LLM 超限时降级。
class ChatImageService {
  /// 压缩图片并返回 JPEG 字节。
  ///
  /// - 如果图片最长边 ≤ [maxLongSide] 且原始大小 ≤ [maxBytes]，直接返回原图
  /// - 否则缩放到 [maxLongSide] 并以 [quality] 压缩为 JPEG
  static Future<Uint8List> compress({
    required Uint8List rawBytes,
    int maxLongSide = 1024,
    int quality = 80,
    int maxBytes = 4 * 1024 * 1024, // 4MB default (Claude limit after base64)
  }) async {
    // 原图已在限制内，直接返回
    if (rawBytes.length <= maxBytes) {
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
        if (longest <= maxLongSide) return rawBytes;
      }
      // 解码失败或超尺寸，继续压缩
    }

    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes; // 无法解码，返回原图

    // 缩放
    img.Image resized = decoded;
    final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
    if (longest > maxLongSide) {
      final scale = maxLongSide / longest;
      resized = img.copyResize(
        decoded,
        width: (decoded.width * scale).round(),
        height: (decoded.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  /// 将图片字节保存到磁盘。
  ///
  /// 返回保存后的绝对路径。
  static Future<String> saveToDisk({
    required Uint8List bytes,
    required String dirPath,
    required String fileName,
  }) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('$dirPath/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 从磁盘加载图片字节。
  static Future<Uint8List?> loadFromDisk(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// 删除磁盘上的图片文件。
  static Future<void> deleteFromDisk(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
