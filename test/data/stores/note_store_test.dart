import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/data/stores/note_store.dart';

void main() {
  group('NoteStore', () {
    late Directory tempDir;
    late NoteStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('note_store_test_');
      store = NoteStore(notesDir: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('appends text to a newly created note and reads it back', () async {
      final meta = await store.createNote(
        themeId: 'theme_1',
        title: 'My note',
      );

      await store.appendBody(meta.noteId, 'First line');
      await store.appendBody(meta.noteId, 'Second line');

      final body = await store.readBody(meta.noteId);

      expect(body, 'First line\n\n---\nSecond line');
    });

    test('writeBody replaces the entire note body', () async {
      final meta = await store.createNote(
        themeId: 'theme_1',
        title: 'My note',
      );

      await store.appendBody(meta.noteId, 'Old text');
      await store.writeBody(meta.noteId, 'New text');

      final body = await store.readBody(meta.noteId);
      expect(body, 'New text');
    });
  });
}
