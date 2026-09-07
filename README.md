# PineVault

PineVault（松匣）是一个离线优先、使用端到端加密并支持 WebDAV 同步的多端密码库。

## 文档

- [实施计划](docs/implementation-plan.md)

## 当前状态

- Flutter 多端项目已初始化。
- Android 包名和 Apple Bundle ID 为 `app.pinevault.client`。
- 已在 Android 真机上完成编译、安装和启动验证。
- 功能实现尚未开始，下一步是本地加密密码库闭环。

## 开发检查

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
