---
name: yk-frontend-project-test
description: >
  写/跑测试：unit / integration / e2e（真壳零 mock）。
  触发：跑测试 / unit / integration / e2e / 测试进度 / 中断恢复测。
---

# 项目测试 Skill

## 必读

1. 测试进度 / 体系：`docs/test/`（有 `PROGRESS.md` 则先读；本仓过渡期可读 `docs/IMPLEMENTATION-PROGRESS.md` 中测试段 + `docs/testing-*.md`）  
2. `docs/agent-working-agreement.md`  
3. `docs/testing-engineering-decisions*.md` · `docs/testing-guide.md` · `test-script/README.md`  
4. 测试坑记 **`docs/test/war-stories/`**；产品坑记 **`docs/dev/war-stories/`** — 本 skill **不**勾 dev 完成条

## 硬规则

| 层 | 命令 | 无 key | 勾 E2E 完成？ |
|----|------|--------|----------------|
| Unit | `test:unit` | 应绿 | 否 |
| Integration | `test:integration` | 硬失败 | **否** |
| **E2E** | `test:e2e`（真壳） | 硬失败 | **仅此** |

- **勾「E2E 完成」只认：`npm run test:e2e` 真壳绿 + 零 mock。**  
- **E2E = 真壳 + UI + 全链路 100% 真。** Integration 真网子集同样禁 mock 模型；契约子集可无 key。  
- **`test:integration` 绿 ≠ E2E 完成**（T4.2）。  
- bootstrap 只物化 `.env`；`contracts` 仅离线契约；真网 + E2E 才强制 key。  
- 分支：**blank / raw / summarize 三种都要测**；创建分支 **不**自动发 LLM，等用户在 input 输入后再发。  
- 禁止：mock 模型、demo_stream、browser+IPC shim、旁路 LLM 代理当 E2E。  
- 密钥：真 key **只**在 gitignore 的 **`docs/test/secrets.keys.md`**（模板 `secrets.example.md`）→ bootstrap → `.env`；**不要**把 requirements 当密钥库；永不 commit / 不打印 key。  
- 每切片：PROGRESS + commit。  

## 失败诊断原则

**测试失败 ≠ 测试脚本有问题。** 按以下顺序排查，禁止直接跳到修脚本：

1. **被测对象** — 程序行为是否符合预期？（UI / 逻辑 / 数据）
2. **环境** — 配置、依赖、网络、密钥
3. **测试脚本本身** — 选择器、超时、断言逻辑

> 适用：unit / integration / e2e 全层级。

## 命令

```bash
npm run test:unit
npm run test:integration          # 中间层
npm run test:integration:live
npm run test:e2e                  # 真壳 UI E2E only
npm run test:e2e:ui:legacy        # 实验，不算完成
```

Harness：`test-script/`（同仓，无 sub-repo）。

## 文案硬规则

- **禁止章节符号（Unicode U+00A7 / section sign）**：聊天、`docs/**`、`docs/_tmp/**`、commit/PR、skill 正文一律不得出现该字符；交叉引用写「第 N 节」。**常驻生效**。  
