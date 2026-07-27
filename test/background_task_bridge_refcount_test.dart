import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/background_task_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refcount: second begin does not call native again', () async {
    var nativeBegin = 0;
    var nativeEnd = 0;
    const channel = MethodChannel('thktree/background_task_test_refcount');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'begin':
          nativeBegin++;
          return 'native-1';
        case 'end':
          nativeEnd++;
          return true;
        default:
          return null;
      }
    });

    final bridge = BackgroundTaskBridge(methodChannel: channel);
    await bridge.begin();
    await bridge.begin();
    expect(nativeBegin, 1);
    expect(bridge.activeCount, 2);

    await bridge.end();
    expect(nativeEnd, 0);
    expect(bridge.activeCount, 1);

    await bridge.end();
    expect(nativeEnd, 1);
    expect(bridge.activeCount, 0);
  });
}
