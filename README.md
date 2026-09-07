# PineVault

PineVault（松匣）是一个离线优先、使用端到端加密并支持 WebDAV 同步的多端密码库。

## 文档

- [实施计划](docs/implementation-plan.md)

## 当前状态

- Flutter 多端项目已初始化。
- Android 包名和 Apple Bundle ID 为 `app.pinevault.client`。
- 已完成本地密码库创建、主密码解锁、条目新增/编辑/删除和搜索。
- 密码库使用 Argon2id 派生密钥，并以 XChaCha20-Poly1305 加密后原子保存。
- 已在 Android 真机上验证加密、篡改检测、锁定后重新解锁、持久化、安装和启动。
- WebDAV 配置与冲突安全同步尚未实现，是下一阶段工作。

## 开发检查

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
