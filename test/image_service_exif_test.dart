import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:thk_tree/data/services/image_service.dart';

/// 在 SOI 后插入 APP1 Exif 段，模拟含 GPS 的实拍照片 JPEG。
Uint8List jpegWithExif(String markerPayload) {
  final base = img.encodeJpg(img.Image(width: 10, height: 10));
  final payload = Uint8List.fromList([
    ...ascii.encode('Exif\x00\x00'),
    ...ascii.encode(markerPayload),
  ]);
  final app1Len = payload.length + 2;
  return Uint8List.fromList([
    base[0], base[1], // SOI
    0xFF, 0xE1, app1Len >> 8, app1Len & 0xFF,
    ...payload,
    ...base.sublist(2),
  ]);
}

bool containsBytes(Uint8List haystack, List<int> needle) {
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return true;
  }
  return false;
}

void main() {
  group('ChatImageService.compress EXIF 剥离', () {
    test('小 JPEG：重编码后不再携带 EXIF / GPS 明文', () async {
      const gps = 'FakeGPS 31.2304N 121.4737E';
      final out = await ChatImageService.compress(rawBytes: jpegWithExif(gps));
      expect(containsBytes(out, ascii.encode('Exif')), isFalse);
      expect(containsBytes(out, ascii.encode(gps)), isFalse);
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.width, 10);
    });

    test('小 PNG：保持 PNG 格式与尺寸', () async {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 8, height: 6)),
      );
      final out = await ChatImageService.compress(rawBytes: png);
      expect(out[0], 0x89);
      expect(out[1], 0x50); // P
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 8);
      expect(decoded.height, 6);
    });

    test('GIF：原样透传（GIF 无 EXIF，保留动画字节）', () async {
      // 最小合法 1x1 GIF89a
      final gif = Uint8List.fromList([
        0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00,
        0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x2C,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x02,
        0x02, 0x44, 0x01, 0x00, 0x3B,
      ]);
      final out = await ChatImageService.compress(rawBytes: gif);
      expect(out, equals(gif));
    });

    test('超尺寸图片：缩放到 maxLongSide 以内', () async {
      final big = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 4000, height: 2000)),
      );
      final out = await ChatImageService.compress(rawBytes: big);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, lessThanOrEqualTo(1024));
      expect(decoded.height, lessThanOrEqualTo(1024));
    });
  });
}
