# 集成测试步骤计时报告（StepTimer）

> 状态：草案 v1  
> 来源：用户提出 `theme_chat_e2e_test` 缺少测试报告功能，希望看到每步耗时

---

## 1. 背景

当前 `theme_chat_e2e_test.dart` 只有一行 `print` 输出 LLM 厂商信息，测试结果依赖 Flutter 默认的控制台 pass/fail 输出。

缺少的信息：
- 每步花了多久（LLM 冷启动慢不慢？）
- 挂在哪一步（主题创建失败还是流式回复超时？）
- 总耗时

---

## 2. 方案

### 2.1 创建共享 helper：`integration_test/_support/step_timer.dart`

**API 设计**：

```dart
final timer = StepTimer()..start();

timer.step('启动 App + 注入');
// ... 做事 ...
timer.step('切换底部 tab 到"主题"');
// ... 做事 ...

timer.finish(); // 打印分隔线 + 总耗时
```

**核心逻辑**：
- 内部用 `Stopwatch` 计时，维护 `_lastElapsed` 记录上一步结束时间点
- `step(name)` 计算本步耗时 = 当前累计 - 上一步累计，`print` 输出并记录到 `List<StepRecord>`
- `finish()` 停表 + 打印总耗时
- 步骤序号自增，不需要手动传
- 提供 `steps` getter 供外部读取（为将来对接 `binding.reportData` 留口子）

**输出格式**：

```
[theme_chat_e2e] 使用 LLM 厂商: DeepSeek
[Step 1] 启动 App + 注入          — 耗时 3.2s
[Step 2] 切换底部 tab 到"主题"     — 耗时 0.8s
[Step 3] 创建主题                  — 耗时 1.5s
[Step 4] 进入主题详情              — 耗时 0.6s
[Step 5] 创建节点                  — 耗时 1.2s
[Step 6] 进入聊天页                — 耗时 0.5s
[Step 7] Round 1 发消息等回复      — 耗时 28.4s
[Step 8] Round 2 发消息等回复      — 耗时 15.7s
[Step 9] 最终断言                  — 耗时 0.1s
───────────────────────────────────
总耗时: 52.0s
```

### 2.2 修改 `theme_chat_e2e_test.dart`

- 在 `testWidgets` 开头 `StepTimer()..start()`
- 在现有每个逻辑段落前插一行 `timer.step('xxx')`
- 在最后 `expect` 之后 `timer.finish()`
- 大约加 10 行，不改任何现有逻辑

**插入位置**（基于现有代码行号）：
- 启动 App + 注入（createTestApp 前）
- 切换 tab 前
- 创建主题前
- 进入主题详情前
- 创建节点前
- 进入聊天页前
- Round 1 前
- Round 2 前
- 最终断言前
- 断言后 finish()

---

## 3. 文件清单

| 文件 | 操作 | 说明 |
|------|------|------|
| `integration_test/_support/step_timer.dart` | 新建 | 共享 StepTimer 类 |
| `integration_test/theme_chat_e2e_test.dart` | 小改 | 插入 step 调用 |

---

## 4. 验收方式

1. 运行 `flutter test integration_test/theme_chat_e2e_test.dart`，控制台输出步骤计时
2. 每步耗时合理（非 0、非负）
3. 总耗时 = 各步耗时之和
4. 现有测试逻辑不变（pass/fail 结果与改动前一致）

---

## 5. 后续扩展（不在本次范围）

- 截图留证（`tester.takeScreenshot`）
- `binding.reportData` 结构化输出
- 其他测试复用 StepTimer
