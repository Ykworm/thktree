import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/services/settings_store.dart';

class _MemSecureStorage extends FlutterSecureStorage {
  _MemSecureStorage([Map<String, String> initial = const {}])
    : _store = Map<String, String>.from(initial);

  final Map<String, String> _store;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async => _store[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    MacOsOptions? mOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
  }) async {
    _store.remove(key);
  }
}

void main() {
  late SettingsStore store;

  setUp(() {
    store = SettingsStore(secureStorage: _MemSecureStorage());
  });

  test('defaults to warmPaper when unset', () async {
    final settings = await store.load();
    expect(settings.colorPalette, isNull);
  });

  test('save and load morandi', () async {
    await store.saveColorPalette('morandi');
    final settings = await store.load();
    expect(settings.colorPalette, 'morandi');
  });

  test('invalid value falls back to warmPaper on parse', () async {
    await store.saveColorPalette('not-a-palette');
    final settings = await store.load();
    expect(settings.colorPalette, 'not-a-palette');
  });

  test('clear palette deletes key', () async {
    await store.saveColorPalette('morandi');
    await store.saveColorPalette(null);
    final settings = await store.load();
    expect(settings.colorPalette, isNull);
  });
}
