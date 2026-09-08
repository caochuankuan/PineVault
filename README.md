# 松匣（PineVault）

松匣是一个离线优先的多端密码管理器。密码库在本机加密保存，也可以通过坚果云 WebDAV 同步；WebDAV 上保存的始终是密文，不是明文密码。

- Flutter 多端项目
- Android 包名、Apple Bundle ID：`app.pinevault.client`
- Android、macOS 已完成本地构建和运行验证

## 功能概览

- 主密码创建、解锁、修改和锁定（主密码至少 8 个字符）
- 密码条目新增、编辑、查看、删除、收藏，以及长按快捷操作
- 名称、用户名、密码、网站、备注字段；查看面板支持复制，网站支持复制和打开
- 每条记录支持多个标签；标签只在查看和编辑面板展示，首页卡片不显示
- 分组：新建和编辑时选择分组，首页按分组筛选
- 搜索：按名称、用户名或网站过滤
- 首页显示开关：密码、网站可分别控制
- 排序：按名称或更新时间，支持正序/逆序切换
- 坚果云 WebDAV：手动同步、解锁后同步、内容变更同步、配置变更同步和定时同步
- KDBX 导入和导出（密码版 KDBX 3/4）

## 安全模型

1. 松匣主密码不会保存。它通过 Argon2id 派生加密密钥，密码库使用 XChaCha20-Poly1305 加密，并以原子方式写入本地。
2. WebDAV 只上传加密后的 `vault.pvlt`，服务端无法直接读取条目内容；同步基线保存在本机用于合并。
3. KDBX 导入时输入的密码只用于解码选中的文件；导出时单独设置 KDBX 文件密码。两者都不会替代、覆盖或同步松匣主密码。
4. 新设备恢复时，需要配置同一个 WebDAV 地址并输入原密码库主密码；验证成功后才会保存密文到本机。

## 使用说明

### 坚果云同步

在“更多 → WebDAV 设置”中填写坚果云 WebDAV 地址、账号和应用密码。建议使用坚果云生成的“第三方应用密码”，不要填写网页登录密码。

远端固定使用相对路径：`Apps/PineVault/vault.pvlt`。配置完成后可在“更多”中手动同步，并在同步历史中查看结果。同步遇到远端并发更新时会重新下载并重试；条目冲突会保留本机和远端可恢复的副本。主密码在另一台设备修改后，当前设备下次解锁应输入新主密码。

### KDBX 导入

1. 打开“更多 → 导入 KDBX”，选择 `.kdbx` 文件。
2. 输入该 KDBX 文件自己的主密码（仅用于本次解码）。
3. 在预览列表中逐条勾选要导入的条目。
4. 已存在的条目会标记“重复”并默认不选；缺少名称或密码的条目会标记问题，可手动决定是否导入。
5. 导入是新增操作，不会覆盖现有条目。

当前支持 Title、UserName、Password、URL、Notes，以及分组和收藏标记。暂不支持 KDBX 密钥文件、附件和自定义字段。

### KDBX 导出

打开“更多 → 导出 KDBX”，设置并确认一个新的 KDBX 主密码（至少 8 个字符），随后通过系统保存对话框选择位置。导出的密码与松匣主密码相互独立。

## 本地数据

应用支持目录下的 `PineVault/` 保存加密密码库、备份文件、同步基线和同步历史。macOS 沙盒运行时通常位于：

```text
~/Library/Containers/app.pinevault.client/Data/Library/Application Support/app.pinevault.client/PineVault
```

如需清除 macOS 调试数据，退出应用后删除该目录即可；这会删除本机数据，不会删除坚果云远端文件。

## 开发与构建

需要 Flutter SDK 和对应平台工具链。首次拉取项目后执行：

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

### macOS

```bash
flutter run -d macos
flutter build macos --release
open build/macos/Build/Products/Release/PineVault.app
```

本地 Release 构建使用 ad-hoc 签名，适合个人测试；未配置 Apple Developer Team，也不是可直接提交 App Store 的签名包。

### Android

```bash
flutter devices
flutter run -d <设备 ID>
flutter build apk --release
```

Android Release 签名由本地被 Git 忽略的 `android/key.properties` 和 `android/app/pinevault-release.jks` 提供。不要把密钥或密码提交到仓库；没有这些文件时仍可进行开发和调试构建。

## 当前边界

- 尚未实现 Android Autofill、iOS Credential Provider、生物识别解锁、TOTP 和浏览器扩展。
- KDBX 暂不支持密钥文件、附件和自定义字段。
- 坚果云双设备真实同步仍需使用你自己的有效账号进行验证。
- iOS、Windows、Linux 尚未完成与 Android/macOS 同等程度的发布验证。

## 相关文档

- [实施计划](docs/implementation-plan.md)
