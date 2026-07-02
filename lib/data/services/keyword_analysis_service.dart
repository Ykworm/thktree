import 'package:thk_tree/data/services/keyword_analysis_storage.dart';

/// leaf 状态机服务（per-theme）。
///
/// 在 [KeywordAnalysisStorage] 之上提供：
/// - **状态机流转**：`markFresh` / `markStaleIfAnalyzed` / `recordUserMessage`
/// - **查询**：按 leafId 读、按 theme 列举 analyzable leaves
/// - **跨 leaf 反向查询**：同 theme 内某 keyword 关联的 leaf 列表
///
/// 设计约束：
/// - pending → fresh → stale 单向流转（stale → fresh 只在重新抽取完成时升级）
/// - 「已分析」= [LeafAnalysisRecord.lastAnalyzedAt] 非空
/// - 写入全部走 [KeywordAnalysisStorage.updateAsync]（原子读 → 修改 → 写）
/// - 写入失败抛出异常，由调用方决定是否降级（chat_controller hook 默认静默失败）
class KeywordAnalysisService {
  KeywordAnalysisService({required this.storage});

  final KeywordAnalysisStorage storage;

  /// 启动时同步：保证 `last_user_message_at > last_analyzed_at` 的已分析 leaf 一定处于 stale。
  ///
  /// 通过 `updateAsync` 走读 → 修复 → 写原子流程，幂等且无副作用。
  /// 返回该 theme 下所有 leaf 记录。
  Future<List<LeafAnalysisRecord>> syncStaleOnLoad() async {
    final updated = await storage.updateAsync((file) {
      for (final record in file.leaves.values) {
        final msgAt = record.lastUserMessageAt;
        final anaAt = record.lastAnalyzedAt;
        if (msgAt != null &&
            anaAt != null &&
            msgAt.isAfter(anaAt) &&
            record.status != LeafStatus.stale) {
          record.status = LeafStatus.stale;
        } else if (msgAt != null &&
            anaAt == null &&
            record.status == LeafStatus.fresh) {
          // 异常态：标 fresh 但无分析时间 → 回退 stale 等下次分析
          record.status = LeafStatus.stale;
        }
      }
      return file;
    });
    return updated.leaves.values.toList();
  }

  /// 获取或初始化单个 leaf 的分析记录（始终返回非空）。
  ///
  /// leaf 不存在时**不写盘**，仅返回内存中新对象；状态变更时再统一落盘。
  Future<LeafAnalysisRecord> getOrInitLeaf(String leafId) async {
    final file = await storage.loadOrInit();
    final existing = file.leaves[leafId];
    if (existing != null) return existing;

    return LeafAnalysisRecord(
      leafId: leafId,
      status: LeafStatus.pending,
    );
  }

  /// 当前 leaf 的记录（可能为 null）。
  Future<LeafAnalysisRecord?> getLeaf(String leafId) async {
    final file = await storage.loadOrInit();
    return file.leaves[leafId];
  }

  /// 标记某个 leaf 为 fresh，并写入本次抽取的关键词。
  ///
  /// - pending → fresh
  /// - fresh → fresh（覆盖关键词，重置 lastUserMessageAt 为 null？）
  /// - stale → fresh（重置分析与消息时间一致）
  ///
  /// 关键词列表为空时按"无关键词"处理（仍标 fresh）。
  Future<void> markFresh({
    required String leafId,
    required List<KeywordEntry> keywords,
    DateTime? analyzedAt,
  }) async {
    final ts = analyzedAt ?? DateTime.now().toUtc();
    await storage.updateAsync((file) {
      file.leaves[leafId] = LeafAnalysisRecord(
        leafId: leafId,
        status: LeafStatus.fresh,
        lastAnalyzedAt: ts,
        lastUserMessageAt: file.leaves[leafId]?.lastUserMessageAt,
        keywords: List<KeywordEntry>.from(keywords),
      );
      return file;
    });
  }

  /// 标记某个 leaf 为 stale（如果已分析过）。
  ///
  /// 用于 chat_controller 的 sendUserMessage hook：
  /// - 只有 `lastAnalyzedAt != null`（即 status 是 fresh / stale）才流转到 stale
  /// - pending 状态不流转（避免对未分析的 leaf 误设 stale）
  /// - 已经是 stale 时 no-op
  /// - **静默**：异常被吞掉，由调用方负责 log（不阻塞主流程）
  Future<void> markStaleIfAnalyzed({
    required String leafId,
    DateTime? userMessageAt,
  }) async {
    final ts = userMessageAt ?? DateTime.now().toUtc();
    try {
      await storage.updateAsync((file) {
        final record = file.leaves[leafId];
        if (record == null) return file; // 未分析过 → no-op
        if (record.lastAnalyzedAt == null) return file; // pending → 跳过
        if (record.status == LeafStatus.stale) return file; // 已是 stale

        record.status = LeafStatus.stale;
        record.lastUserMessageAt = ts;
        return file;
      });
    } catch (_) {
      // 静默失败（chat_controller 不允许被阻塞）
    }
  }

  /// 记录 leaf 的用户消息时间（无论是否已分析）。
  ///
  /// 用于：
  /// - 状态机一致性修复（启动时检测 stale）
  /// - 兜底：即使 storage 抛错，状态字段仍可独立追溯
  Future<void> recordUserMessage({
    required String leafId,
    DateTime? userMessageAt,
  }) async {
    final ts = userMessageAt ?? DateTime.now().toUtc();
    try {
      await storage.updateAsync((file) {
        final existing = file.leaves[leafId];
        if (existing != null) {
          existing.lastUserMessageAt = ts;
        } else {
          // 用户消息先于分析：建占位 pending 记录，仅记录消息时间
          file.leaves[leafId] = LeafAnalysisRecord(
            leafId: leafId,
            status: LeafStatus.pending,
            lastUserMessageAt: ts,
          );
        }
        return file;
      });
    } catch (_) {
      // 静默失败
    }
  }

  /// 列出该 theme 下"可分析"的 leaf（pending 或 stale）。
  ///
  /// fresh 不再需要立即重新抽取（除非用户主动触发），所以 analyzable = pending ∪ stale。
  Future<List<LeafAnalysisRecord>> getAnalyzableLeaves() async {
    final file = await storage.loadOrInit();
    return file.leaves.values
        .where((r) =>
            r.status == LeafStatus.pending || r.status == LeafStatus.stale)
        .toList();
  }

  /// 列出该 theme 下所有 stale leaf。
  Future<List<LeafAnalysisRecord>> getStaleLeaves() async {
    final file = await storage.loadOrInit();
    return file.leaves.values
        .where((r) => r.status == LeafStatus.stale)
        .toList();
  }

  /// 反向查询：同 theme 内包含某 keyword 的 leaf 列表。
  ///
  /// 仅在该 theme 文件范围内反查；跨 theme 反查见
  /// `KeywordGlobalStorage.keywordLeafMap`（由 aggregation 服务维护）。
  Future<List<LeafAnalysisRecord>> getLeavesForKeyword(String keyword) async {
    final file = await storage.loadOrInit();
    return file.leaves.values
        .where((r) => r.keywords.any((k) => k.keyword == keyword))
        .toList();
  }

  /// 重置 leaf 为 pending（用户主动删除关键词记录等场景）。
  Future<void> resetLeaf(String leafId) async {
    await storage.updateAsync((file) {
      file.leaves.remove(leafId);
      return file;
    });
  }
}
