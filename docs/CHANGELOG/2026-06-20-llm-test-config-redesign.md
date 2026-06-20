# LLM 测试 Key 注入方案:从 assets 迁移到 dart-define

| 属性 | 说明 |
|------|------|
| 日期 | 2026-06-20 |
| 范围 | 集成测试基础设施(`integration_test/_support/llm_test_config.dart`)+ 死代码清理 + 5 份集成测试 doc + 1 份 LLM 模块 doc + `pubspec.yaml` / `.gitignore` |
| 设计文档 | [`docs/_tmp/2026-06-20-llm-test-config-redesign.md`](../_tmp/2026-06-20-llm-test-config-redesign.md) |
| ADR | [ADR-013](../DECISIONS.md#adr-013-llm-测试-key-通过-dart-define-注入放弃-assets-路径) |
| 状态 | ✅ 完成 |

## 背景

ThkTree 集成测试需要真实 LLM API Key 才能驱动聊天链路。2026-06-18 修复过一次 LLM 配置加载失败问题,把 Key 的物理位置从 `tool/test_llm_config.json` 迁移到 `assets/test_llm_config/test_llm_config.json`,通过 `pubspec.yaml` 的 `assets:` 声明把整个目录打进 Flutter bundle,集成测试进程通过 `rootBundle.loadString` 读取。

但本次复盘发现一个**安全红线**:`pubspec.yaml` 中 `assets: - assets/test_llm_config/` 是对**整个目录**的声明,**任何 build mode(debug / profile / release)都会把含真实 Key 的 json 烤进 bundle**。当前仓库 `assets/test_llm_config/test_llm_config.json` 里持有 `sk-8a3e5b90d3574becacab2e14bf62f3a6` 这类真实 deepseek Key。一旦运行 `flutter build ipa --release`,Key 就以明文形式进入 `.app` bundle,可以轻易从 ipa 里 grep 出来。

> **`.gitignore` 只解决"不提交",不解决"不进 release 包" —— 这是两个独立维度。**

## 根因

旧方案选型时只考虑了"如何让 simulator 看到 host 上的 Key",没考虑"release 包是否也带 Key"。`pubspec.yaml` 的 `assets:` 是**无条件**打进 bundle 的,这是 Flutter 框架的设计,与 build mode 无关。

由此引出三个待回答的子问题:

1. `tool/test_llm_config.json` 是不是死代码 → **是**(simulator 看不到 host 文件)
2. 打包 APP 不能带 Key → **对,这就是当前漏洞**
3. 未来测试自主调 LLM → 当前 `theme_chat_e2e_test.dart` 已部分实现(Dart 真发请求),本方案为后续扩展留好接口

## 方案

走 **方案 A:dart-define + 生成器**。核心机制是 `String.fromEnvironment('TEST_LLM_CONFIG_JSON')` 编译期读 `--dart-define` 注入的 JSON 字符串,值只存在于编译期常量池,不写文件、不进 bundle、运行时也取不到原始注入路径。

```
[本机/host]                              [生成器]                              [编译期]                  [运行期集成测试]
test_llm_config.local.json  ────▶  tools/gen_dart_define.dart  ────▶  --dart-define-from-file  ────▶  String.fromEnvironment
  (开发者本机,不入仓)                  (包装为 dart-define 期望格式)              (只活在编译时)              (Dart 内存常量)
```

**为什么需要生成器**:Flutter 的 `--dart-define-from-file` 只接受 `{"KEY":"VALUE"}` 简单映射,且注入的 value 不能包含字面换行符。直接把 LLM 配置 JSON 原样传给 `--dart-define-from-file` 会导致:

1. Flutter 工具链找不到 `TEST_LLM_CONFIG_JSON` 这个 key,**静默返回空字符串**(不报错)。
2. 即使手动包成 `{"KEY":"<inner>"}` 格式,如果 inner 是 pretty-print JSON(含字面 `\n`),`frontend_server` 的 `resolveInputUri` 会把 dart-define 命令行参数当 URI 解析,URI scheme 不允许换行符。

生成器负责读取开发者友好的 LLM 配置 → `jsonDecode` 解析 → `jsonEncode` 压缩为单行紧凑 JSON → 再包成 dart-define 期望的简单映射。

### 关键约束

- Key 物理不进入任何构建产物(`.app` / `.apk` / `.ipa`)
- 本地开发友好:开发者本机一键准备配置
- 架构前瞻:为未来"测试代码自主调 LLM 生成内容"留好接口(`LlmTestConfig` 持有完整的 providers/apiKeys 映射)
- 文档同步:集成测试相关的 5 个 .md 文档同步更新,不留 dead reference

## 实施内容

### 删除文件(共 4 个文件 + 1 个目录)

```
tool/test_llm_config.example.json                            # 死代码,simulator 看不到 host
tool/test_llm_config.json                                    # 死代码 + 含真 Key
assets/test_llm_config/test_llm_config.example.json          # 被 dart-define-from-file 取代
assets/test_llm_config/test_llm_config.json                  # 含真 Key,且会让 release 包泄露
assets/test_llm_config/                                      # 删除 4 个文件后目录无意义,一并删
```

### 新增文件(1 个)

```
tools/gen_dart_define.dart                                   # 读 pretty-print JSON → 压缩 → 包成 dart-define 简单映射
```

### 修改文件(共 9 个)

```
pubspec.yaml                                                                 # 删 assets: - assets/test_llm_config/ 那行 + 注释
.gitignore                                                                   # 删 tool/test_llm_config.json / assets/test_llm_config/ 两条规则
integration_test/_support/llm_test_config.dart                               # loadFromAsset → loadFromDefine;旧方法标 @Deprecated
integration_test/theme_chat_e2e_test.dart                                     # 调用点 LlmTestConfig.loadFromAsset → loadFromDefine
docs/_shared/integration-testing/README.md                                   # § 2 / § 6 / § 7.2-7.4 / § 7.6 / § 8.3 / § 9 / § 12
docs/_shared/integration-testing/fixtures.md                                 # § 1 / § 2 / § 4.4 / § 5 / § 6
docs/_shared/integration-testing/theme-chat-e2e.md                           # § 4.1
docs/modules/llm/specs/integration-test-llm-injection.md                     # § 4 / § 6 数据流
docs/DECISIONS.md                                                            # 新增 ADR-013
```

### 关键改动

**`integration_test/_support/llm_test_config.dart` — 新增 `loadFromDefine`:**

```dart
/// 读 --dart-define-from-file 注入的 TEST_LLM_CONFIG_JSON。
///
/// 注入机制:
///   1. 开发者本机准备 test_llm_config.json(放 ~/.thktree/ 等工程外位置)
///   2. 跑生成器: dart run tools/gen_dart_define.dart <input> build/dart_define.json
///   3. 跑测试: flutter test integration_test/ --dart-define-from-file=build/dart_define.json
///
/// 为何不能直接传 pretty-print JSON:Flutter 的 --dart-define-from-file 只接受
/// {"KEY":"VALUE"} 简单映射,且 value 不能含字面 \n(否则 frontend_server 的
/// resolveInputUri 会因 URI scheme 解析失败而报错)。
factory LlmTestConfig.loadFromDefine() {
  const raw = String.fromEnvironment('TEST_LLM_CONFIG_JSON', defaultValue: '');
  if (raw.isEmpty) {
    throw StateError(
      'LLM test config not found.\n\n'
      '集成测试需要通过 --dart-define-from-file=<path> 传入 LLM 配置。\n'
      '准备步骤:\n'
      '  1. 在工程外任意位置创建 test_llm_config.json,参考 docs/_shared/integration-testing/fixtures.md § 2.1\n'
      '  2. 填入对应厂商的 apiKey\n'
      '  3. 跑生成器: dart run tools/gen_dart_define.dart <input> build/dart_define.json\n'
      '  4. 跑测试: flutter test integration_test/ --dart-define-from-file=build/dart_define.json',
    );
  }
  // ... 沿用现有 JSON 解析 + 校验逻辑
}

/// @Deprecated: 推荐改用 loadFromDefine + --dart-define-from-file。
/// 本方法保留一个版本作为逃生通道,下次集成测试基础设施大改时彻底删除。
@Deprecated('Use loadFromDefine() with --dart-define-from-file instead')
factory LlmTestConfig.loadFromAsset(String assetPath) { /* 旧实现 */ }
```

**`tools/gen_dart_define.dart` — 核心逻辑:**

```dart
// 1. 读开发者准备的 pretty-print JSON
final input = File(args[0]).readAsStringSync();
final parsed = jsonDecode(input) as Map<String, dynamic>;

// 2. 压缩为单行紧凑 JSON(去字面 \n)
final compact = jsonEncode(parsed);

// 3. 包成 --dart-define-from-file 期望的简单映射
final output = <String, String>{
  'TEST_LLM_CONFIG_JSON': compact,
};
File(args[1]).writeAsStringSync(jsonEncode(output));
```

**`pubspec.yaml` — 删除 assets 声明:**

```yaml
# 删除以下 3 行(原来是注释 + 实际声明)
# LLM test config (integration tests only)
# Loaded via rootBundle in tests; do not commit real keys
# assets:
#   - assets/test_llm_config/
```

## 集成测试运行命令

### 一次性准备(开发者本机)

```bash
# 在工程外任意位置创建配置,推荐放 ~/.thktree/
mkdir -p ~/.thktree
$EDITOR ~/.thktree/test_llm_config.json
```

### 每次跑测试

> **重要**:不要直接把 `~/.thktree/test_llm_config.json` 喂给 `--dart-define-from-file`。那个文件是开发者友好的 pretty-print JSON(含字面 `\n`),会被 `frontend_server` 报 URI 解析错。必须先经生成器压缩为单行紧凑 JSON 再注入。

**步骤 1 — 生成 `build/dart_define.json`(不入仓):**

```bash
dart run tools/gen_dart_define.dart \
  ~/.thktree/test_llm_config.json \
  build/dart_define.json
```

**步骤 2 — 跑集成测试,指定生成产物:**

```bash
flutter test integration_test/ \
  --dart-define-from-file=build/dart_define.json
```

## 验证

| 类别 | 状态 |
|---|---|
| **静态隔离**(关键 ⭐) | ✅ `flutter build ipa --release` 后 `grep -r "test_llm_config" /tmp/ipa-inspect/` 与 `grep -rE "sk-(ant-)?[a-zA-Z0-9]{20,}" /tmp/ipa-inspect/` 均无输出 |
| 集成测试 `theme_chat_e2e_test.dart` | ✅ 主题 → 节点 → 聊天 2 round 完整链路通过,流式响应正常,stop_button 出现→消失 |
| 错误路径(缺 dart-define) | ✅ 启动时快速抛 StateError,错误信息明确指引用户用 `--dart-define-from-file` |
| 错误路径(坏 JSON 含字面 `\n`) | ✅ `frontend_server` 报 URI 解析错,快速失败不会进测试 |
| `flutter analyze` | ✅ 无新增 error |

## 已知风险(留给后续决定)

- `loadFromAsset()` 标记 `@Deprecated` 但保留一个版本 → 下次集成测试基础设施大改时彻底删除。
- `tools/gen_dart_define.dart` 仅做"压缩 + 包装",不做 JSON 合法性校验(由 `LlmTestConfig.loadFromDefine` 内部校验)。如果将来要加更多 dart-define 字段,需在生成器里做 schema 校验。
- `String.fromEnvironment` 的字符串长度上限:当前配置 < 1KB,远低于 ~10KB 理论上限,暂不构成风险。
- 本设计不实现 CI 配置,留待后续单独任务。

## 关联

- [ADR-013](../DECISIONS.md#adr-013-llm-测试-key-通过-dart-define-注入放弃-assets-路径) — 决策记录
- [docs/_tmp/2026-06-20-llm-test-config-redesign.md](../_tmp/2026-06-20-llm-test-config-redesign.md) — 完整设计 spec(463 行)
- [docs/_shared/integration-testing/README.md](../_shared/integration-testing/README.md) — 集成测试总览(已同步)
- [docs/_shared/integration-testing/fixtures.md](../_shared/integration-testing/fixtures.md) — fixtures + 注入方式(已同步)
- [docs/_shared/integration-testing/theme-chat-e2e.md](../_shared/integration-testing/theme-chat-e2e.md) — theme_chat_e2e_test 配套文档(已同步)
- [docs/modules/llm/specs/integration-test-llm-injection.md](../modules/llm/specs/integration-test-llm-injection.md) — LLM 模块集成测试说明(已同步)
