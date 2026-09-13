# KDBX 附件支持方案

本文记录松匣后续实现附件能力的设计，范围包括本地存储、WebDAV 同步以及 KDBX 导入导出。

## 目标

- 密码条目可以关联多个文件附件。
- 附件在本地和 WebDAV 上始终保持应用层加密。
- KDBX 导入和导出时不丢失附件。
- 相同内容只存储一份，避免重复占用空间。
- 兼容现有没有附件字段的密码库数据。

## 数据模型

`VaultItem` 增加附件元数据列表，文件内容不直接放入条目 JSON：

```dart
class VaultAttachment {
  const VaultAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.size,
    required this.sha256,
    required this.createdAt,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int size;
  final String sha256;
  final DateTime createdAt;
}
```

`VaultItem` 增加：

```dart
final List<VaultAttachment> attachments;
```

旧数据缺少 `attachments` 时按空列表读取。附件 ID 使用稳定值，文件内容使用 SHA-256 寻址。

## 本地存储

建议目录：

```text
<app-private-data>/attachments/<sha256>.blob
```

写入流程：

1. 选择文件并计算 SHA-256。
2. 使用密码库派生的附件密钥进行 AEAD 加密。
3. 先写临时文件，校验完成后原子重命名为 `<sha256>.blob`。
4. 将文件名、MIME 类型、大小和哈希写入 `VaultItem`。

不要把附件 Base64 编码进密码库 JSON。这样可以避免每次密码库变更都重新上传全部大文件。

建议初始限制：单个附件 50 MB，总空间限制可配置。删除条目时先删除引用，附件文件由后台垃圾清理任务在确认没有引用后删除。

## 加密

附件在离开设备前必须完成应用层加密，不能只依赖 WebDAV 的 HTTPS 或服务器权限。附件格式至少包含：

```text
magic | version | nonce | ciphertext | authentication tag
```

附件密钥从现有密码库密钥派生，使用项目已有的密码学库和随机数实现。不要使用文件名或 SHA-256 作为加密密钥。

## WebDAV 同步

推荐采用主清单加独立 blob 文件：

```text
/pinevault/vault.enc
/pinevault/attachments/<sha256>.blob
/pinevault/manifest.json
```

`vault.enc` 保存密码条目、附件元数据和引用关系；附件文件只保存加密 blob。

### 上传顺序

1. 上传远端缺失的附件 blob。
2. 上传新的加密密码库清单。
3. 最后更新 `manifest.json`。

### 下载顺序

1. 下载并验证密码库清单。
2. 找出本地缺失的附件。
3. 下载附件 blob，并校验解密后的 SHA-256。
4. 校验通过后原子写入本地。
5. 延迟清理不再被任何版本引用的远端附件。

文件名只使用 SHA-256，不使用用户输入的原始文件名，避免路径注入和编码问题。上传、下载和清理都需要支持超时、断点失败重试以及 ETag 条件更新。

## 冲突合并

附件 blob 是不可变对象，冲突只处理元数据和引用：

- 相同 SHA-256：合并为一个附件。
- 一端新增：加入合并结果。
- 同名但内容不同：按不同 SHA-256 保留两个附件。
- 条目冲突复制：同时复制附件引用。
- 删除附件：仅删除引用；物理文件延迟垃圾回收。

## KDBX 导入

KDBX 将附件放在全局 `Meta/Binaries` 池中，条目通过 `Binary Ref` 引用。导入流程：

1. 遍历 `entry.binaries`。
2. 通过 `BinaryReference` 取得 `KdbxDataBinary.data`。
3. 写入本地加密附件存储。
4. 将文件名、大小、MIME 类型和哈希写入 `KdbxImportEntry`。
5. 导入预览显示附件数量和文件名。
6. 用户确认后再写入 `VaultItem`。

解析失败时不能静默丢弃附件，应在预览和最终结果中提示失败数量。

## KDBX 导出

1. 读取 `VaultItem.attachments` 对应的本地 blob。
2. 解密并校验 SHA-256。
3. 创建 `PlainBinary` 或 `ProtectedBinary`。
4. 调用 `database.binaries.add(binary)` 加入全局二进制池。
5. 将返回的 `BinaryReference` 写入 `entry.binaries[fileName]`。

MIME 类型不是所有 KDBX 客户端都会保留，可以使用自定义字段保存，例如：

```text
PineVault-Attachment-Mime-<fileName>
```

## UI

条目详情页增加附件区域：

- 文件名、文件大小和类型图标
- 添加附件
- 打开
- 分享
- 删除

KDBX 导入预览增加附件统计，例如：

```text
登录条目：23
附件：8 个
预计占用：12.4 MB
```

WebDAV 同步期间显示附件上传和下载进度。

## 实现顺序

1. 增加 `VaultAttachment` 和 JSON 序列化。
2. 实现本地加密附件存储服务。
3. 在条目详情页增加附件 UI。
4. 实现 KDBX 导入附件。
5. 实现 KDBX 导出附件。
6. 扩展 WebDAV 仓库和同步用例。
7. 增加冲突合并和远端垃圾附件清理。
8. 增加旧数据、重复附件、断网恢复、大文件和跨设备测试。

第一阶段建议先实现本地存储和 KDBX 导入导出，验证数据模型稳定后再接入 WebDAV，避免同步协议和附件模型同时变化。
