import 'package:flutter_test/flutter_test.dart';
import 'package:thk_tree/domain/ids.dart';

void main() {
  test('generates ids with expected prefixes', () {
    expect(newThemeId(), startsWith('thm_'));
    expect(newNodeId(), startsWith('nd_'));
    expect(newNoteId(), startsWith('nt_'));
    expect(newMsgId(), startsWith('msg_'));
    expect(newRequestId(), startsWith('req_'));
  });
}

