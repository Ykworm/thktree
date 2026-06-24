# 笔记集成测试方案

## 目标

为笔记模块编写集成测试，覆盖完整 CRUD 操作，验证自动化回归和数据持久化。

## 测试范围

- 完整 CRUD：创建、编辑、重命名、删除
- 持久化验证：重启 App 后数据仍在
- 测试数据：时间戳唯一标识（不清理）

## 测试文件

- 文件名：`integration_test/note_crud_test.dart`
- 超时：90 秒

## 参考实现

- `theme_chat_e2e_test.dart`：完整 E2E 流程
- `branch_creation_test.dart`：创建操作
