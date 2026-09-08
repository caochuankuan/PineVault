enum VaultItemType { login, secureNote }

class VaultItem {
  const VaultItem({
    required this.id,
    this.groupId = 'default',
    required this.type,
    required this.title,
    required this.username,
    required this.password,
    required this.urls,
    required this.notes,
    this.tags = const [],
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
  });

  final String id;
  final String groupId;
  final VaultItemType type;
  final String title;
  final String username;
  final String password;
  final List<String> urls;
  final String notes;
  final List<String> tags;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      groupId: json['groupId'] as String? ?? 'default',
      type: VaultItemType.values.byName(json['type'] as String),
      title: json['title'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      urls: List.unmodifiable((json['urls'] as List<dynamic>).cast<String>()),
      notes: json['notes'] as String,
      tags: List.unmodifiable(
        (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      ),
      favorite: json['favorite'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      revision: json['revision'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'groupId': groupId,
    'type': type.name,
    'title': title,
    'username': username,
    'password': password,
    'urls': urls,
    'notes': notes,
    'tags': tags,
    'favorite': favorite,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
  };

  VaultItem copyWith({
    String? groupId,
    String? title,
    String? username,
    String? password,
    List<String>? urls,
    String? notes,
    List<String>? tags,
    bool? favorite,
    DateTime? updatedAt,
    int? revision,
  }) {
    return VaultItem(
      id: id,
      groupId: groupId ?? this.groupId,
      type: type,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      urls: List.unmodifiable(urls ?? this.urls),
      notes: notes ?? this.notes,
      tags: List.unmodifiable(tags ?? this.tags),
      favorite: favorite ?? this.favorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
    );
  }
}
