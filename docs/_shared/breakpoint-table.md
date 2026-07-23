# 断点表（哪一步容易断、怎么防）

| 断点 | 症状 | 闸门 / 补救 |
|------|------|-------------|
| 新 chat 无上文 | 重聊已定结论 | 必读 `_tmp/<topic>.md`；用户点名 topic |
| 没读模块 README | 踩 SSE/存储等坑 | ARCHITECTURE 地图 + README 顶部必读；改前 cross-check |
| 双人新模块两名 | `docs/modules` 分叉 | 登记表 + `migrate_module_slug.sh` |
| ctsync 乱改 | 写错模块 / 漏改 | 只认登记 id + diff；**确认后才写** |
| 当 E2E 完成其实只是 integration | 假闭环 | 所有端：必须真壳启动（非 `flutter test integration_test/`）；测试进度参考 `docs/test/PROGRESS.md` |
| litemode 未 merge | 你在 dev 测不到 | litemode **强制** merge 进 dev |
| freemode 实验进主线 | 脏历史 | freemode 不默认；要进 dev 先升 litemode/fullmode 收尾 |
| 信息缺失仍开工 | 半成品 | go-gate：验收不清 → 停下提问 |
