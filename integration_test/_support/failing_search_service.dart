// 模拟 DatabaseException 的 SearchService 子类。
//
// 用于 Case 3：搜索索引异常 → 修复弹窗 → 修复完成。
// search() 抛出 DatabaseException，rebuildAll() 保持父类正常行为。

import 'package:sqflite/sqflite.dart';
import 'package:thk_tree/data/services/search_service.dart';

class FailingSearchService extends SearchService {
  FailingSearchService({
    required super.db,
    required super.paths,
    required super.noteStoreFactory,
  });

  @override
  Future<List<SearchResult>> search(String query, {int limit = 50}) async {
    throw _SimulatedDatabaseException('Simulated FTS5 corruption');
  }
}

class _SimulatedDatabaseException implements DatabaseException {
  const _SimulatedDatabaseException(this._message);
  final String _message;

  @override
  String toString() => 'DatabaseException($_message)';

  @override
  Object? get result => null;

  @override
  int? getResultCode() => null;

  @override
  bool isNoSuchTableError([String? table]) => false;

  @override
  bool isDuplicateColumnError([String? column]) => false;

  @override
  bool isSyntaxError() => false;

  @override
  bool isOpenFailedError() => false;

  @override
  bool isDatabaseClosedError() => false;

  @override
  bool isReadOnlyError() => false;

  @override
  bool isUniqueConstraintError([String? field]) => false;

  @override
  bool isNotNullConstraintError([String? field]) => false;
}
