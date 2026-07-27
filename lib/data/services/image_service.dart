import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// 图片压缩与磁盘读写工具。
///
/// 压缩策略：最长边 ≤ [maxLongSide]，JPEG quality [quality]。
/// 用于聊天图片持久化（预览用）和 LLM 超限时降级。
class ChatImageService {
  /// 压缩图片。
  ///
  /// - 图片最长边 ≤ [maxLongSide] 且原始大小 ≤ [maxBytes]：不缩放，但会
  ///   剥离 EXIF（可能含 GPS 定位）后按原格式重编码；GIF 无 EXIF 且重编码
  ///   会丢动画，原样透传
  /// - 否则缩放到 [maxLongSide] 并以 [quality] 压缩为 JPEG（重编码即剥离 EXIF）
  static Future<Uint8List> compress({
    required Uint8List rawBytes,
    int maxLongSide = 1024,
    int quality = 80,
    int maxBytes = 4 * 1024 * 1024, // 4MB default (Claude limit after base64)
  }) async {
    // 原图已在限制内：不缩放，但仍需剥离 EXIF 再返回
    if (rawBytes.length <= maxBytes) {
      final decoded = img.decodeImage(rawBytes);
      if (decoded != null) {
        final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
        if (longest <= maxLongSide) {
          return _reencodeWithoutExif(rawBytes, decoded, quality: quality);
        }
      }
      // 解码失败或超尺寸，继续压缩
    }

    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes; // 无法解码，返回原图

    // 缩放（bakeOrientation 把 EXIF 方向烘焙进像素，避免重编码丢 EXIF 后显示旋转错误）
    img.Image resized = img.bakeOrientation(decoded);
    final longest = resized.width > resized.height ? resized.width : resized.height;
    if (longest > maxLongSide) {
      final scale = maxLongSide / longest;
      resized = img.copyResize(
        resized,
        width: (resized.width * scale).round(),
        height: (resized.height * scale).round(),
        interpolation: img.Interpolation.linear,
      );
    }

    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }

  /// 剥离 EXIF 并按原格式重编码。
  ///
  /// encodeJpg / encodePng 均不写入 EXIF 段，重编码即完成剥离；
  /// bakeOrientation 先把 EXIF 方向烘焙进像素，避免剥离后显示旋转错误。
  /// GIF 不支持 EXIF，且重编码会丢失动画，直接透传原字节。
  static Uint8List _reencodeWithoutExif(
    Uint8List rawBytes,
    img.Image decoded, {
    required int quality,
  }) {
    if (_isGif(rawBytes)) return rawBytes;
    final baked = img.bakeOrientation(decoded);
    if (_isPng(rawBytes)) {
      return Uint8List.fromList(img.encodePng(baked));
    }
    return Uint8List.fromList(img.encodeJpg(baked, quality: quality));
  }

  static bool _isPng(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 && // P
      bytes[2] == 0x4E && // N
      bytes[3] == 0x47; // G

  static bool _isGif(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0x47 && // G
      bytes[1] == 0x49 && // I
      bytes[2] == 0x46; // F

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
