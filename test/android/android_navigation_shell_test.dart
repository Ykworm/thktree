import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/ui/platform/android/android_color_scheme.dart';
import 'package:thk_tree/ui/platform/android/android_navigation_shell.dart';

void main() {
  group('响应式断点 isTabletWidth', () {
    test('低于 600 视为手机', () {
      expect(isTabletWidth(360), isFalse);
      expect(isTabletWidth(599.9), isFalse);
    });

    test('≥ 600 视为平板（走导航栏 rail）', () {
      expect(isTabletWidth(600), isTrue);
      expect(isTabletWidth(840), isTrue);
    });

    test('断点常量与判定一致', () {
      expect(isTabletWidth(kAndroidTabletBreakpoint - 0.01), isFalse);
      expect(isTabletWidth(kAndroidTabletBreakpoint), isTrue);
    });
  });
}
