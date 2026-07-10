## ADR-001: 状态管理选型 Riverpod StateNotifier

项目从一开始就选 Riverpod 作为状态管理方案，2026-05 定基线。选 Riverpod 而非 Provider/Bloc/MVI：Riverpod 的 family/autoDispose 跟"节点作用域"高度契合，chat/notes 都是按 `nodeId` 做 family；编译期检查避免运行期找不到 provider；测试时 `ProviderContainer` 注入 mock 比 Bloc 简单很多。StateNotifier 而非 `@riverpod` 注解：注解风格虽新，但项目里大部分 controller 已经用 `AsyncNotifier` 类的形式，迁注解的收益不抵风险。影响范围：所有 `lib/data/stores/` + `lib/ui/features/*/` 下的 controller；`pubspec.yaml` `flutter_riverpod` 依赖。实施要点：换状态管理 = 整库改写，**禁止局部切换**。
