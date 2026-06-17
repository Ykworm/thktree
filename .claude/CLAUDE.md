# CLAUDE.md

## context-sync 触发

用户说 `ctsync`、`同步文档`、`docs sync`、`context-sync` 时，执行 `/context-sync` 命令。

## 项目级 Skill 约定

ThkTree 是 Flutter 项目，`flutter-dev` 是主线 skill；`ios-application-dev` / `android-native-dev` 等平台原生 skill 仅在处理 platform channel、原生构建问题时按需触发。
