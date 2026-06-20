# LLM 测试 Key 注入方案:从 assets 迁移到 dart-define

> **创建**:2026-06-20
> **维护者**:AI 起草 + 用户审阅
> **状态**:设计已定稿,待实现
> **关联**:brainstorming 会话结论 / 项目禁用单元测试策略 / ThkTree 集成测试核心策略

---

## 1. 背景与动机

ThkTree 集成测试需要真实 LLM API Key 才能驱动聊天链路。2026-06-18 修复过一次 LLM 配置加载失败的问题(见 [docs/modules/llm/specs/integration-test-llm-injection.md](../../modules/llm/specs/integration-test-llm-injection.md)),将 Key 的物理位置从 `tool/test_llm_config.json` 迁移到 `assets/test_llm_config/test_llm_config.json`,通过 `pubspec.yaml` 的 `assets:` 声明把整个目录打进 Flutter bundle,集成测试进程通过 `rootBundle.loadString` 读取。

但本次复盘发现一个**安全红线**:

> `pubspec.yaml` 中 `assets: - assets/test_llm_config/` 是对**整个目录**的声明,**任何 build mode(debug / profile / release)都会把含真实 Key 的 json 烤进 bundle**。
>
> 当前仓库 `assets/test_llm_config/test_llm_config.json` 里持有 `sk-8a3e5b90d3574becacab2e14bf62f3a6` 这类真实 deepseek Key。一旦运行 `flutter build ipa --release`,Key 就以明文形式进入 `.app` bundle,可以轻易从 ipa 里 grep 出来。

**`.gitignore` 只解决"不提交",不解决"不进 release 包" —— 这是两个独立维度。**

用户提出的三个子问题:

1. `tool/test_llm_config.json` 是不是死代码 → **是**(simulator 看不到 host 文件)
2. 打包 APP 不能带 Key → **对,这就是当前漏洞**
3. 未来测试自主调 LLM → 当前 `theme_chat_e2e_test.dart` 已部分实现(Dart 真发请求),本方案为后续扩展留好接口

---

## 2. 设计目标 / 非目标

### 2.1 目标

- **物理隔离**:Key 不进入任何构建产物(`.app` / `.apk` / `.ipa`)
- **本地开发友好**:开发者本机一键准备配置,跑测试命令简单
- **架构前瞻**:为未来"测试代码自主调 LLM 生成内容"留好接口,不需要再做一轮重构
- **文档同步**:集成测试相关的 5 个 .md 文档同步更新,不留 dead reference

### 2.2 非目标

- 不引入 Build flavors(项目当前不需要,杀鸡用牛刀)
- 不引入 CI 配置(本地开发为主,未来需要时再单独设计)
- 不修改 `LlmTestConfig` 之外的集成测试基础设施
- 不迁移到第三方密钥管理服务(GCP Secret Manager / Vault 等)

---

## 3. 方案总览

**核心机制**：`String.fromEnvironment('TEST_LLM_CONFIG_JSON')` 编译期读 `--dart-define` 注入的 JSON 字符串，值只存在于编译期常量池，不写文件、不进 bundle、运行时也取不到原始注入路径。

```
[本机/host]                              [生成器]                              [编译期]                  [运行期集成测试]
test_llm_config.local.json  ────▶  tools/gen_dart_define.dart  ────▶  --dart-define-from-file  ────▶  String.fromEnvironment
  (开发者本机，不入仓)                  (包装为 dart-define 期望格式)              (只活在编译时)              (Dart 内存常量)
```

**为什么需要生成器**：Flutter 的 `--dart-define-from-file` 只接受 `{"KEY":"VALUE"}` 简单映射，且注入的 value 不能包含字面换行符。直接把 LLM 配置 JSON 原样传给 `--dart-define-from-file` 会导致：

1. Flutter 工具链找不到 `TEST_LLM_CONFIG_JSON` 这个 key，**静默返回空字符串**（不报错）。
2. 即使手动包成 `{"KEY":"<inner>"}` 格式，如果 inner 是 pretty-print JSON（含字面 `\n`），`frontend_server` 的 `resolveInputUri` 会把 dart-define 命令行参数当 URI 解析，URI scheme 不允许换行符。

生成器负责读取开发者友好的 LLM 配置 → `jsonDecode` 解析 → `jsonEncode` 压缩为单行紧凑 JSON → 再包成 dart-define 期望的简单映射。详见 ADR-013。

**对比表**：

| 维度 | 现状（assets） | 方案 A（dart-define） |
|------|-------------|---------------------|
| Key 物理位置 | `assets/test_llm_config/test_llm_config.json` | 编译期常量，Dart 二进制中 |
| 是否进 release 包 | **是（漏洞）** | **否（物理隔离）** |
| 是否在 .gitignore | 是 | 不需要（没有文件可忽略） |
| 集成测试运行命令 | `flutter test integration_test/` | 先跑生成器，再 `flutter test integration_test/ --dart-define-from-file=build/dart_define.json` |
| 真 Key 泄露风险 | 高（任何人 build ipa 就泄露） | 极低（只有跑集成测试时才传入） |

---

## 4. 文件改动清单

### 4.1 删除(共 4 个文件 + 1 个目录)

| 路径 | 删除理由 |
|------|---------|
| `tool/test_llm_config.example.json` | 死代码,simulator 看不到 host |
| `tool/test_llm_config.json` | 死代码 + 含真 Key |
| `assets/test_llm_config/test_llm_config.example.json` | 被 dart-define-from-file 取代 |
| `assets/test_llm_config/test_llm_config.json` | 含真 Key,且会让 release 包泄露 |
| `assets/test_llm_config/` 整目录 | 删除 4 个文件后目录无意义,一并删 |

### 4.2 修改(共 10 个文件)

**配置 / 加载器(3 个):**

| 路径 | 改动要点 |
|------|---------|
| `pubspec.yaml` | 删除 `assets: - assets/test_llm_config/` 那行 + 上面两行说明性注释 |
| `.gitignore` | 删除 `tool/test_llm_config.json` 和 `assets/test_llm_config/test_llm_config.json` 两条规则(文件都没了) |
| `integration_test/_support/llm_test_config.dart` | `loadFromAsset()` 重写为 `loadFromDefine()`;`loadFromAsset()` 标记 `@Deprecated` 并保留一个版本以做平滑迁移;顶部 doc comment 重写,说明新机制 |

**集成测试用例(1 个):**

| 路径 | 改动要点 |
|------|---------|
| `integration_test/theme_chat_e2e_test.dart` | 调用点从 `LlmTestConfig.loadFromAsset(...)` 改为 `LlmTestConfig.loadFromDefine()` |

**集成测试文档(5 个,`docs/_shared/integration-testing/` 下):**

| 路径 | 改动要点 |
|------|---------|
| `fixtures.md` | § 1 / § 2 / § 4 / § 5 / § 6 等所有提到"assets"路径的地方改为 dart-define |
| `llm-injection.md` | TL;DR 第 4 条"API Key 来自 assets JSON"改为"API Key 来自 --dart-define" |
| `chat-streaming.md` | § 3.1 加载配置示例代码改用 `loadFromDefine` |
| `theme-chat-e2e.md` | § "配置来源"表更新,代码示例同步 |
| `branch-creation.md` | 第 256 行示例代码同步 |

**LLM 模块文档(1 个):**

| 路径 | 改动要点 |
|------|---------|
| `docs/modules/llm/specs/integration-test-llm-injection.md` | § 6 数据流图更新,key 来源从 asset 改为 env |

### 4.3 新增

- 无新文件需要入仓 —— 配置文件由开发者本机自由管理

---

## 5. LlmTestConfig 改造设计

### 5.1 API 变更

```dart
// 旧
LlmTestConfig.loadFromAsset('assets/test_llm_config/test_llm_config.json')

// 新
LlmTestConfig.loadFromDefine()  // 内部读 TEST_LLM_CONFIG_JSON 这个 dart-define
```

`loadFromAsset()` 方法**标记 `@Deprecated` 而非直接删除**,原因:

- `loadFromAsset` 当前只在 `theme_chat_e2e_test.dart` 有一处调用,理论上可以直接删
- 但保留一个版本作为逃生通道:如果 `dart-define-from-file` 遇到问题,还能回退到 asset 路径
- `@Deprecated` 标注会触发 IDE 警告,推动迁移

> **下次重构(下一次集成测试基础设施大改时)**:如果 dart-define 方案稳定运行,再彻底删除 `loadFromAsset()`。

### 5.2 加载流程

1. 读取 `String.fromEnvironment('TEST_LLM_CONFIG_JSON', defaultValue: '')`
2. 若为空字符串 → 抛 `StateError`,错误信息明确指引用户:
   ```
   LLM test config not found.
   
   集成测试需要通过 --dart-define-from-file=<path> 传入 LLM 配置。
   
   准备步骤:
   1. 在工程外任意位置创建 test_llm_config.json,参考 § 7 的 JSON 结构
   2. 填入对应厂商的 apiKey
   3. 运行:
      flutter test integration_test/ \
        --dart-define-from-file=/your/path/test_llm_config.json
   ```
3. 解析 JSON → 沿用现有校验逻辑(activeProvider 必须存在,对应 provider 的 apiKey 非空)
4. 返回 `LlmTestConfig` 实例

### 5.3 下游零改动

`LlmTestConfig` 的现有方法**保持不变**:

- `toAppSettings()` —— 注入 appSettingsProvider 用
- `toLlmConfigStore()` —— 注入 llmConfigStoreProvider 用
- `activeProvider` —— 当前激活厂商

`createTestApp()` 的 `llmSettings` / `llmConfigStore` 参数签名**不变**,下游集成测试代码不需要改这些接口。

### 5.4 未来扩展接口(为第三问预留)

未来如果测试代码需要"自主调 LLM 生成内容",可以新增:

```dart
// 伪代码,本设计不实现
extension LlmTestClient on LlmTestConfig {
  Future<String> chat(String prompt) async {
    // 复用 chat_controller 已有的 LLM 调用链
  }
}
```

当前设计**不实现**这个扩展,只确保 `LlmTestConfig` 持有完整的 providers/apiKeys 映射,扩展时不需要再回头改基础设施。

---

## 6. 集成测试运行命令

### 6.1 一次性准备(开发者本机)

```bash
# 在工程外任意位置创建配置,推荐放 ~/.thktree/ 或工程内的 _local/(自己 gitignore)
mkdir -p ~/.thktree
cat > ~/.thktree/test_llm_config.json <<'EOF'
{
  "activeProvider": "deepseek",
  "providers": {
    "deepseek": {
      "apiKey": "sk-你的真实-key",
      "model": "deepseek-v4-flash"
    }
  }
}
EOF
```

**关键约束**:这个文件**不入仓**,放哪里由开发者自己决定,推荐 `~/.thktree/` 这样的工程外位置,避免任何"我以为 gitignore 了"的失误。

### 6.2 每次跑测试

> **重要**：不要直接把 `~/.thktree/test_llm_config.json` 喂给 `--dart-define-from-file`。
> 那个文件是开发者友好的 pretty-print JSON（含字面 `\n`），会被 `frontend_server` 报 URI 解析错。
> 必须先经生成器压缩为单行紧凑 JSON 再注入。

**步骤 1 — 生成 `build/dart_define.json`（不入仓，`build/` 在 `.gitignore`）**：

```bash
dart run tools/gen_dart_define.dart \
  ~/.thktree/test_llm_config.json \
  build/dart_define.json
```

**步骤 2 — 跑集成测试，指定生成产物**：

```bash
flutter test integration_test/ \
  --dart-define-from-file=build/dart_define.json
```

**为什么两步**：生成器把开发者友好的 pretty-print JSON 压缩为单行紧凑 JSON（去字面 `\n`），再包成 `{"TEST_LLM_CONFIG_JSON": "<compact>"}` 这种 Flutter `--dart-define-from-file` 期望的简单映射。详见 § 3 与 ADR-013。

> `--dart-define-from-file` 是 Flutter 3.7+ 引入的特性。ThkTree 当前 Dart `^3.12.0`,完全支持。

### 6.3 CI(未来需要时)

CI 同样需要两步:

```bash
# 步骤 1: 生成器(从 CI secret 路径读真 Key)
dart run tools/gen_dart_define.dart \
  $CI_SECRET_DIR/test_llm_config.json \
  build/dart_define.json

# 步骤 2: 跑测试
flutter test integration_test/ \
  --dart-define-from-file=build/dart_define.json
```

> 本设计不实现 CI 配置,留待后续。

---

## 7. JSON 配置文件结构

```json
{
  "activeProvider": "deepseek",
  "providers": {
    "deepseek": {
      "apiKey": "sk-...",
      "model": "deepseek-v4-flash"
    },
    "openai":  { "apiKey": "sk-...", "model": "gpt-4o" },
    "claude":  { "apiKey": "sk-ant-...", "model": "claude-sonnet-4-20250514" },
    "gemini":  { "apiKey": "...", "model": "gemini-2.5-flash" },
    "minimax": { "apiKey": "...", "model": "MiniMax-Text-01" },
    "kimi":    { "apiKey": "sk-...", "model": "moonshot-v1-8k" }
  }
}
```

字段说明:

- `activeProvider`:必填,枚举值,见 `LlmProvider`(deepseek / openai / claude / gemini / minimax / kimi)
- `providers.<name>.apiKey`:必填(只对 activeProvider),其他厂商可填可空
- `providers.<name>.model`:选填,空时使用 `LlmProvider.defaultModel`

详细校验规则沿用现有 `LlmTestConfig` 实现,本设计不改动。

---

## 8. 验收方式

### 8.1 静态隔离验收(关键 ⭐)

```bash
# 1. 构建 release ipa
flutter build ipa --release

# 2. 解压 .app
unzip -o build/ios/ipa/Runner.ipa -d /tmp/ipa-inspect
ls /tmp/ipa-inspect/Payload/Runner.app/Frameworks/App.framework/flutter_assets/

# 3. 搜索 test_llm_config 路径
grep -r "test_llm_config" /tmp/ipa-inspect/
# 预期:无任何输出

# 4. 搜索常见 Key 前缀
grep -rE "sk-(ant-)?[a-zA-Z0-9]{20,}" /tmp/ipa-inspect/
# 预期:无任何输出
```

**通过条件**:以上两条 grep 全部无输出。

### 8.2 集成测试验收

```bash
# 步骤 1: 生成器
dart run tools/gen_dart_define.dart \
  ~/.thktree/test_llm_config.json \
  build/dart_define.json

# 步骤 2: 跑测试
flutter test integration_test/theme_chat_e2e_test.dart \
  --dart-define-from-file=build/dart_define.json
```

**通过条件**:`theme_chat_e2e_test.dart` 的 `主题 → 节点 → 聊天 2 round 完整链路` 正常通过,流式响应正常,stop_button 出现→消失。

### 8.3 错误路径验收(快速失败)

```bash
# 不传 dart-define
flutter test integration_test/theme_chat_e2e_test.dart
# 预期:启动时快速抛 StateError,错误信息包含"请用 --dart-define-from-file"提示
```

```bash
# 传 build/dart_define.json 但生成器输出被破坏(含字面 \n)
flutter test integration_test/theme_chat_e2e_test.dart \
  --dart-define-from-file=<bad-file>
# 预期:frontend_server 报 URI 解析错(快速失败,不会进测试)
```

### 8.4 静态分析

```bash
flutter analyze
# 预期:无新增 error
```

---

## 9. 错误处理清单

| 错误场景 | 触发条件 | 行为 |
|---------|---------|------|
| 缺 dart-define | `String.fromEnvironment(...)` 返回空 | StateError + 明确指引用户 |
| 文件不存在 | `--dart-define-from-file` 指向不存在的路径 | Flutter 工具链自己报错,不进测试 |
| 文件不是合法 JSON | JSON.parse 失败 | FormatException(沿用现有) |
| 缺 activeProvider | JSON 解析后无 activeProvider 字段 | FormatException(沿用现有) |
| activeProvider 无 apiKey | JSON 解析后该 provider 的 apiKey 为空 | StateError(沿用现有) |
| 未知 LlmProvider 名 | activeProvider 不在 LlmProvider 枚举中 | FormatException(沿用现有) |

所有错误信息都遵循"提示 + 解决步骤"格式,不裸抛异常。

---

## 10. 风险与回滚

| 风险 | 等级 | 缓解措施 |
|------|------|---------|
| `dart-define-from-file` 是 Flutter 3.7+ 才有 | 低 | ThkTree 当前 Dart `^3.12.0` ✓ |
| dart-define 字符串长度上限 | 低 | 当前配置 < 1KB,远低于 ~10KB 理论上限 |
| 现有测试代码需同步改 | 低 | 改动集中在 `theme_chat_e2e_test.dart` 一处 |
| 5 个 .md 文档需同步 | 低 | 文档任务集中处理 |
| 旧 `loadFromAsset()` 残留 | 低 | 标记 `@Deprecated` 推动迁移,下个版本删除 |

**回滚方案**:

1. `git revert` 整个改动的 commit
2. 重新执行 `cp tool/test_llm_config.example.json tool/test_llm_config.json` 并填 Key
3. 集成测试可继续以旧 asset 路径运行

**回滚时间估计**:< 5 分钟(假设 revert 后无其他冲突)。

---

## 11. 范围检查

### 11.1 范围内(本设计实现)

- `LlmTestConfig` 加载机制迁移
- 死代码清理
- 5 个 .md 文档(`docs/_shared/integration-testing/` 下)+ 1 个 LLM 模块说明文档同步
- 集成测试命令调整
- 静态隔离验收

### 11.2 范围外(明确不做)

- Build flavors 体系
- CI 配置
- LLM 调用客户端抽象(`LlmTestClient`,留给未来)
- 集成测试用例扩充(主题/笔记/拖拽等已有测试不需要改)
- Android 平台特有适配(本设计 iOS / Android 通用,无平台分支)

### 11.3 后续可能展开(独立任务)

- "Dart 测试自主调 LLM 生成内容" → 独立 brainstorming + 设计
- 集成测试覆盖度扩充 → 独立任务
- CI 接入 → 独立任务

---

## 12. 决策记录(ADR 草稿)

待用户确认本设计后,在 `docs/DECISIONS.md` 新增 ADR:

> **ADR-013:LLM 测试 Key 通过 dart-define 注入,放弃 assets 路径**
>
> - 状态:已接受
> - 日期:2026-06-20
> - 背景:assets 路径会让 release 包泄露真实 API Key
> - 决策:改用 `String.fromEnvironment` + `--dart-define-from-file`
> - 影响:集成测试运行命令变化,5 个文档同步更新
> - 取舍:放弃"零配置即可跑测试"的便利,换取"Key 物理不泄露"
>
> **已知限制(2026-06-20 验收暴露)**:
> - `--dart-define-from-file` 只接受 `{"KEY":"VALUE"}` 简单映射,非任意 JSON
> - dart-define value 不能含字面 `\n`(会触发 frontend_server URI 解析错)
>
> **方案 — 引入生成器**:`tools/gen_dart_define.dart` 读开发者友好的 pretty-print JSON → `jsonDecode` → `jsonEncode` 压缩为单行紧凑 → 包成简单映射。开发者运行命令:
> ```bash
> dart run tools/gen_dart_define.dart <input> build/dart_define.json
> flutter test integration_test/ --dart-define-from-file=build/dart_define.json
> ```

---

## 附录 A · 完整改动命令清单(实现阶段用,本设计不出代码)

实现阶段会按以下顺序执行(每个步骤有独立 commit,便于回滚):

1. 删除 `tool/` 下两个文件
2. 删除 `assets/test_llm_config/` 整目录
3. 修改 `pubspec.yaml` 删 assets 声明
4. 修改 `.gitignore` 删两条规则
5. 重写 `integration_test/_support/llm_test_config.dart`(新增 `loadFromDefine`,标记 `loadFromAsset` Deprecated)
6. 修改 `integration_test/theme_chat_e2e_test.dart` 调新方法
7. 同步 5 个 .md 文档
8. 在 `docs/DECISIONS.md` 新增 ADR
9. 执行验收(§ 8.1 - § 8.4)

## 附录 B · 术语表

| 术语 | 含义 |
|------|------|
| dart-define | Flutter 编译期常量注入机制 |
| dart-define-from-file | dart-define 的便捷形式,从 JSON 文件批量注入 |
| rootBundle | Flutter 框架的运行时资源访问入口(本设计不再使用) |
| InMemoryLlmConfigStore | 测试用内存假 LlmConfigStore,本设计不改动 |
| LlmTestConfig | 集成测试配置加载器,本设计主要改动对象 |

---

**规格自检待执行**:占位符扫描 / 内部一致性 / 范围 / 模糊性检查。
