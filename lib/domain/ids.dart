import 'package:ulid/ulid.dart';

String _newUlidUpper() => Ulid().toString().toUpperCase();

String newThemeId() => 'thm_${_newUlidUpper()}';
String newNodeId() => 'nd_${_newUlidUpper()}';
String newNoteId() => 'nt_${_newUlidUpper()}';
String newMsgId() => 'msg_${_newUlidUpper()}';
String newRequestId() => 'req_${_newUlidUpper()}';
