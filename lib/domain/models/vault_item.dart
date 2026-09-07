enum VaultItemType { login, secureNote }

class VaultItem {
  const VaultItem({
    required this.id,
    required this.type,
    required this.title,
    required this.username,
    required this.password,
    required this.urls,
    required this.notes,
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
    required this.revision,
  });

  final String id;
  final VaultItemType type;
  final String title;
  final String username;
  final String password;
  final List<String> urls;
  final String notes;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int revision;

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {
        'id': final String id,
        'type': final String type,
        'title': final String title,
        'username': final String username,
        'password': final String password,
        'urls': final List<dynamic> urls,
        'notes': final String notes,
        'favorite': final bool favorite,
        'createdAt': final String createdAt,
        'updatedAt': final String updatedAt,
        'revision': final int revision,
      } =>
        VaultItem(
          id: id,
          type: VaultItemType.values.byName(type),
          title: title,
          username: username,
          password: password,
          urls: List.unmodifiable(urls.cast<String>()),
          notes: notes,
          favorite: favorite,
          createdAt: DateTime.parse(createdAt),
          updatedAt: DateTime.parse(updatedAt),
          revision: revision,
        ),
      _ => throw const FormatException('Invalid vault item.'),
    };
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'username': username,
    'password': password,
    'urls': urls,
    'notes': notes,
    'favorite': favorite,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'revision': revision,
  };

  VaultItem copyWith({
    String? title,
    String? username,
    String? password,
    List<String>? urls,
    String? notes,
    bool? favorite,
    DateTime? updatedAt,
    int? revision,
  }) {
    return VaultItem(
      id: id,
      type: type,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      urls: List.unmodifiable(urls ?? this.urls),
      notes: notes ?? this.notes,
      favorite: favorite ?? this.favorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      revision: revision ?? this.revision,
    );
  }
}
