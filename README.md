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
- 已实现坚果云 WebDAV 连接设置；凭据随密码库加密保存，不依赖平台钥匙串。
- 已实现手动、解锁后、内容变更后、返回前台及每 5 分钟自动同步。
- 已实现加密基线、三方合并、编辑/删除冲突副本、WebDAV 配置冲突提示和 ETag 条件上传；遇到 412 会重新下载并重试一次。
- 新设备可从固定 WebDAV 路径下载密文，使用原主密码验证后恢复本地密码库和同步基线。
- 已实现同步阶段提示、最近 100 条持久化同步历史和主密码修改。
- 锁定状态不会同步，因为同步凭据只有在主密码解锁后才能读取。

## 开发检查

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```
