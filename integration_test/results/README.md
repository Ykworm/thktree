# 测试结果（results）

> 本目录存放每个 case 每端的**最新**运行结果。模型：**跑完覆盖旧结果，不堆历史**。
> 与 `docs/test-cases-catalog.md`（规范真源）配套：catalog 写「该测什么」，results 写「跑得怎样」。

## 结构

```
results/
├── README.md                 ← 本文件
├── <CASE-ID>/
│   ├── ios.md                ← iOS 结果（跑 iOS 只覆盖这份）
│   ├── android.md            ← Android 结果
│   └── macos.md              ← macOS 结果
└── artifacts/
    └── <CASE-ID>-<platform>.png   ← 结果/失败截图（随结果提交进仓库，Gitee 内联渲染）
```

- 一个 case 每端一个文件：跑 `BC-1` 的 Android **只覆盖 `results/BC-1/android.md`**，
  iOS / macOS 那份原封不动 → 满足「各端结果互不被覆盖」（你定的硬要求）。
- `artifacts/*.png` 随结果一起**提交进仓库**（不再 gitignore），Gitee 上结果 md 用 `../artifacts/...`
  相对路径内联渲染，协作者无需任何图床 / key 即可查看。

## 单个结果文件格式（results/BC-1/android.md）

```
case:     BC-1
title:    选中文本 + raw 模式创建分支
platform: android
updated:  2026-07-12T17:16+08:00

状态: ✅ PASS        （或 ❌ FAIL / ⚠️ 阻塞 / N/A）

运行方式:
  flutter test integration_test/common/branch_creation_test.dart \
    --plain-name "选中文本 + raw 模式创建分支" -d emulator-5554
  LLM: real（强制，已注入 key，禁止 mock）

环境:
  device:    emulator-5554
  flutter:   3.32.x
  app-build: dev

时长: 41s

失败详情（仅 FAIL 时填）:
  - 报错: <assertion / exception 摘要>
  - 日志: <tail 20 行>
  - 截图: ../artifacts/BC-1-android.png
  ![失败截图](../artifacts/BC-1-android.png)
```

> 结果 md 是**普通 markdown**（非代码块），`![...](../artifacts/...)` 会在 Gitee 网页上直接渲染成图片。
> 截图路径相对当前文件：`results/<CASE-ID>/<platform>.md` → `../artifacts/<CASE-ID>-<platform>.png`。

## LLM 规则（硬约束）

**LLM 绝对不能 mock。** 所有 case 必须用真实 LLM（`--dart-define-from-file=build/dart_define.json`）。
runner 在缺 key 时**拒绝运行**并明确报错。结果文件里只记 `LLM: real（强制）`，没有 mock 选项。

> 例外：依赖 mock 的历史债 case（`llm_error_retry` / `offline` / `theme_chat_e2e`，编译债）在修好 mock 前标 `N/A`，不计入有效结果。

## 怎么跑

```bash
# 在 app worktree 根目录（integration_test/ 是本地目录）
bash integration_test/tools/run_e2e.sh BC-1 android
```

参数：`<CASE-ID> <platform: ios|android|macos>`

runner 自动从 `docs/test-cases-catalog.md` 解析出脚本路径与 `--plain-name`，按平台选默认设备，注入真实 LLM key，跑完覆盖写回对应结果文件。

- 默认设备：`android → emulator-5554` / `ios → 需设 IOS_DEVICE` / `macos → -d macos`
- 设备可用环境变量覆盖：`ANDROID_DEVICE` / `IOS_DEVICE` / `MACOS_DEVICE`
- 多脚本 case（如 E2E-BC）目前需手动逐脚本跑，runner 仅处理单 Related script 的 case

## 提交约定

跑完一轮后，把 `results/` 的 md **与 `artifacts/*.png` 一起**提交到主仓库（message `test: update results <date>`）。
`artifacts/*.png` 随结果提交（不再 gitignore）。多 case 一轮跑完**批量提交一次**，别每 case 一 commit。
