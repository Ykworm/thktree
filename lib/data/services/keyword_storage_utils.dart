import 'dart:io';
import 'dart:math';

/// 关键词排行榜共用的底层工具：8 位随机短 ID 生成 + 原子写入。
class KeywordStorageUtils {
  KeywordStorageUtils._();

  static final Random _random = Random.secure();

  /// 生成 8 位随机短 ID（字母 + 数字），用于 catalog category id。
  ///
  /// 字符集：`[a-z0-9]`，共 36^8 ≈ 2.8 万亿组合。
  /// 实际唯一性靠重试保证：生成后与现有 id 集合查重，撞到就重试，最多 16 次。
  static String generateShortId(Set<String> existing) {
    const charset = 'abcdefghijklmnopqrstuvwxyz0123456789';
    for (var attempt = 0; attempt < 16; attempt++) {
      final buf = StringBuffer();
      for (var i = 0; i < 8; i++) {
        buf.write(charset[_random.nextInt(charset.length)]);
      }
      final candidate = buf.toString();
      if (!existing.contains(candidate)) return candidate;
    }
    // 极端情况：16 次都撞上 → fallback 到时间戳后缀
    final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return suffix.substring(suffix.length - 8).padLeft(8, '0');
  }

  /// 原子写入：先写 `<filePath>.tmp`，再 rename 到目标路径。
  /// 中途崩溃不会破坏目标文件（最多残留 tmp，可下次清理）。
  static Future<void> atomicWriteString(String filePath, String content) async {
    final tmpPath = '$filePath.tmp';
    final tmpFile = File(tmpPath);
    await tmpFile.writeAsString(content);
    await tmpFile.rename(filePath);
  }
}