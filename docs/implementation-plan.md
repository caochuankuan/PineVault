# PineVault 实施计划

本文档记录 PineVault（松匣）的实现边界、架构决策、交付阶段和验收条件。它面向参与项目开发的人员，不是最终用户使用说明。

当前进度：本地加密密码库闭环已经实现，并在 Android 真机通过加密、错误密码、密文篡改、持久化与重新解锁测试。WebDAV 配置与同步尚未开始。

## 1. 产品目标

PineVault 是一个离线优先的多端密码库。客户端负责加密和解密，WebDAV 服务只保存密文，主密码和明文密码条目不得离开设备。

首批目标平台：

- Android
- iOS
- macOS
- Windows

Linux 在核心依赖通过构建和安全存储验证后加入。Web 端不属于首版范围。

## 2. 第一条可用闭环

首个里程碑必须完成以下真实流程：

```text
首次启动
  → 设置主密码
  → 创建加密密码库
  → 新增密码条目
  → 加密保存
  → 终止应用并重新启动
  → 输入主密码解锁
  → 读取原有条目
```

这一阶段包括：

1. 建立 PineVault 应用外壳和依赖注入入口。
2. 实现创建密码库和解锁密码库页面。
3. 定义密码库、密码条目和加密文件模型。
4. 实现序列化、加密、原子保存和恢复。
5. 实现密码条目的新增、编辑、删除和搜索。
6. 在 Android 真机上验证重启后的持久化与解锁。

## 3. 明确不进入首个里程碑的功能

- 系统自动填充
- 浏览器扩展
- TOTP 动态验证码
- 附件
- KeePass 或 CSV 导入
- 密码泄漏检查
- WebDAV 自动合并
- 生物识别快捷解锁

这些功能将在本地密码库闭环稳定后分阶段加入。

## 4. 安全模型

### 4.1 防护目标

PineVault 需要防护：

- WebDAV 或云盘文件泄露。
- 锁定状态下的设备文件被复制。
- 密文被意外损坏或主动篡改。
- 同步过程中发生静默覆盖和数据丢失。

以下情形不在客户端密码库能完整防护的范围内：

- 设备系统已经被攻破。
- 应用处于解锁状态时存在恶意软件或键盘记录器。
- 用户选择了可被快速猜测的弱主密码。

### 4.2 密钥层次

创建密码库时：

1. 使用系统安全随机源生成 256 位 `VaultKey`。
2. 使用 Argon2id 将主密码派生为 `KeyEncryptionKey`。
3. 使用 `KeyEncryptionKey` 加密包装 `VaultKey`。
4. 使用 `VaultKey` 加密完整密码库 payload。

更改主密码时只重新包装 `VaultKey`，不改变密码库的数据模型。

### 4.3 算法

- 密码派生：Argon2id。
- 数据加密：XChaCha20-Poly1305。
- 随机数：操作系统安全随机源。
- 每次加密生成新的随机 nonce。
- 文件头中的格式版本、密码库 ID 和 KDF 参数作为 AEAD additional data 参与认证。

实现使用 `sodium`，由同一个底层库提供 Argon2id、XChaCha20-Poly1305、安全随机数和安全密钥接口。当前 Flutter 3.41.9 / Dart 3.11.5 解析到 `sodium 3.4.6`，因此同时使用配套的 `sodium_libs 3.4.6+4` 提供多端原生二进制。升级到支持 sodium 4 Native Assets 的 Flutter/Dart 后，应移除 `sodium_libs`。

### 4.4 凭据规则

- 主密码永不保存。
- `VaultKey` 只在密码库解锁期间保留。
- WebDAV 应用密码存入平台安全存储。
- 日志、错误报告和分析事件不得包含密钥、密码、Authorization 或密码条目内容。
- 不支持可靠安全存储的平台不得降级为明文配置文件。

Dart 运行时无法保证垃圾回收前立即覆写所有字符串内存，因此应避免创建不必要的主密码副本，并在锁定时释放所有可控的密钥引用。

## 5. 加密文件格式

首版文件扩展名为 `.pvlt`。外层采用带版本号的 JSON envelope，业务 payload 序列化后整体加密。

```json
{
  "magic": "PINEVAULT",
  "version": 1,
  "vaultId": "uuid",
  "kdf": {
    "algorithm": "argon2id13",
    "salt": "base64",
    "operations": 3,
    "memory": 67108864
  },
  "wrappedKey": {
    "nonce": "base64",
    "ciphertext": "base64"
  },
  "payload": {
    "nonce": "base64",
    "ciphertext": "base64"
  }
}
```

除完成格式识别和密钥派生所需的字段外，条目标题、用户名、网站、标签和修改时间等业务信息全部位于加密 payload 中。

格式版本升级使用显式迁移，不在正常读写路径中长期保留未经实际数据证明需要的兼容层。

## 6. 本地存储

磁盘只保存密文：

```text
pine_vault/
├── vault.pvlt
└── vault.prev.pvlt
```

保存流程：

1. 在内存中序列化当前密码库。
2. 使用新的 nonce 加密完整 payload。
3. 将新 envelope 写入同目录临时文件。
4. 重新读取并完成格式与认证校验。
5. 将当前文件保留为 `vault.prev.pvlt`。
6. 原子替换 `vault.pvlt`。

首版不使用磁盘明文 SQLite、明文 JSON、明文搜索索引或明文临时文件。密码库解锁后，条目保存在内存中并由 Repository 作为单一数据源管理。

## 7. 领域模型

### 7.1 Vault

```text
Vault
- id
- schemaVersion
- createdAt
- updatedAt
- items[]
- tombstones[]
```

### 7.2 VaultItem

```text
VaultItem
- id: UUID
- type: login | secureNote
- title
- username
- password
- urls[]
- notes
- tags[]
- favorite
- createdAt
- updatedAt
- revision
```

条目使用手写不可变模型，避免在当前规模下引入没有实际收益的代码生成链。

删除操作生成 tombstone，而不是立即抹除记录，以便后续同步阶段传播删除状态。

## 8. 应用架构

项目遵循 View、ViewModel、Repository 和 Service 分层。复杂的跨数据源业务逻辑放入 Use Case。

```text
用户界面
  │
  ▼
ViewModel：管理界面状态和用户命令
  │
  ▼
Use Case：创建、解锁、保存、同步、合并
  │
  ├── VaultRepository
  │     ├── VaultFileService
  │     └── 内存中的解密 Vault
  │
  ├── SyncRepository
  │     └── WebDavService
  │
  └── SecurityRepository
        ├── CryptoService
        └── SecureStorageService
```

计划目录：

```text
lib/
├── app/
│   ├── pine_vault_app.dart
│   └── app_dependencies.dart
├── domain/
│   ├── models/
│   └── use_cases/
├── data/
│   ├── repositories/
│   ├── services/
│   └── serialization/
└── ui/
    ├── core/
    └── features/
        ├── onboarding/
        ├── unlock/
        ├── vault/
        ├── item_editor/
        └── settings/
```

状态管理使用 `provider` 和 `ChangeNotifier`。View 不直接访问文件、加密接口或网络。

主要会话状态：

```text
noVault
creating
locked
unlocking
unlocked
saving
error
```

## 9. 首版界面

首轮包含：

- 欢迎页：创建新密码库、从 WebDAV 恢复。
- 创建页：主密码、确认密码和强度提示。
- 解锁页：主密码输入和可恢复的错误提示。
- 密码库首页：搜索、条目列表、新增和锁定。
- 条目编辑页：名称、用户名、密码、网站、备注和收藏。

手机采用单栏布局。窗口宽度足够时使用“列表 + 详情”双栏布局。布局只依据可用窗口宽度，不依据设备型号或屏幕方向。

## 10. WebDAV 连接

本地闭环稳定后实现 WebDAV 设置：

```text
设置
  → WebDAV
  → 输入服务器地址、账号和应用密码
  → 测试连接
  → 创建 PineVault 远端目录
```

`WebDavService` 首版只实现实际需要的方法：

- `PROPFIND`
- `GET`
- `PUT`
- 必要时 `MKCOL`
- 读取 ETag

默认坚果云服务地址为 `https://dav.jianguoyun.com/dav/`。用户必须使用坚果云第三方应用密码，而不是账号登录密码。

远端路径：

```text
/dav/Apps/PineVault/<vault-id>/vault.pvlt
```

## 11. 同步策略

每台设备记录：

- 当前本地版本。
- 上次成功同步的加密基线。
- 上次远端 ETag。
- 尚未上传的本地修改状态。

同步流程：

1. 读取远端 ETag。
2. 远端未变化且本地有修改时，使用条件请求上传。
3. 远端已变化时，下载并解密远端版本。
4. 使用 Base、Local、Remote 做逐条目三方合并。
5. 同一条目发生不同修改时保留冲突，不静默覆盖。
6. 上传合并结果；若 ETag 再次变化则重新执行同步。
7. 成功后更新本地基线和 ETag。

合并规则：

- 仅本地变化：保留本地版本。
- 仅远端变化：采用远端版本。
- 双边结果相同：直接合并。
- 双边结果不同：生成冲突条目。
- 一边删除、另一边编辑：生成冲突，不静默删除。

## 12. 测试与验收

### 12.1 加密测试

- 正确主密码可以解密。
- 错误主密码无法解密。
- 密文任意字节被修改后认证失败。
- 每次保存使用不同 nonce。
- 文件中不存在条目明文片段。
- Android 真机上的 Argon2id 耗时和内存处于可接受范围。

### 12.2 本地存储测试

- 首次创建后可以立即重新解锁。
- 写入中断不破坏上一份有效文件。
- 当前文件损坏时可以识别并从加密备份恢复。
- 应用锁定后 Repository 不再暴露条目。

### 12.3 同步测试

- 两台设备修改不同条目时自动合并。
- 两台设备修改同一条目时产生冲突。
- 删除和编辑冲突不会丢失数据。
- ETag 变化后不会覆盖远端新版本。
- 401、403、404、412、超时和空间不足均产生可恢复错误。

### 12.4 每次提交前

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

阶段性功能还需在 Android 真机上运行验证。

## 13. 实施阶段和提交计划

### 阶段一：应用架构

提交：`refactor: establish PineVault application architecture`

验收：模板页面被替换，依赖注入和空状态路由可运行。

### 阶段二：加密文件

提交：`feat: add encrypted vault format and crypto service`

验收：所有加密测试通过，并在 Android 真机验证 Argon2id 和 XChaCha20-Poly1305。

### 阶段三：创建与解锁

提交：`feat: add vault creation and unlock flow`

验收：杀掉应用并重启后，可以用主密码重新解锁。

### 阶段四：密码条目

提交：`feat: add password item management`

验收：可以新增、编辑、删除和搜索条目，所有修改均加密保存。

### 阶段五：WebDAV 配置

提交：`feat: add WebDAV connection settings`

验收：可以保存坚果云应用密码、测试连接并上传或下载加密文件。

### 阶段六：安全同步

提交：`feat: add conflict-safe vault synchronization`

验收：三方合并、条件上传、删除传播和冲突界面通过测试。

## 14. 后续功能

在上述阶段完成后，再按实际需求评估：

- 生物识别快捷解锁。
- TOTP 动态验证码。
- 密码强度和重复密码审计。
- KeePass、CSV 导入。
- Android Autofill Service。
- iOS Credential Provider Extension。
- 浏览器扩展和桌面自动填充。
- 加密附件。

## 15. 参考资料

- [Flutter 应用架构指南](https://docs.flutter.dev/app-architecture/guide)
- [sodium Dart 包](https://pub.dev/packages/sodium)
- [libsodium XChaCha20-Poly1305](https://doc.libsodium.org/secret-key_cryptography/aead/chacha20-poly1305/xchacha20-poly1305_construction)
- [RFC 9106: Argon2](https://www.rfc-editor.org/info/rfc9106/)
- [RFC 4918: WebDAV](https://www.rfc-editor.org/info/rfc4918/)
- [坚果云 WebDAV 官方说明](https://help.jianguoyun.com/?p=2064)
