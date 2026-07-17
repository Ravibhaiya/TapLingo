enum LibraryType { novel, manga }

class LibraryItem {
  final String id;
  final String name;
  final LibraryType type;
  final String url;
  final DateTime dateAdded;
  final String lastReadUrl;
  final double lastReadPosition;
  final DateTime? lastOpenedAt;

  const LibraryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    required this.dateAdded,
    required this.lastReadUrl,
    this.lastReadPosition = 0,
    this.lastOpenedAt,
  });

  LibraryItem copyWith({
    String? id,
    String? name,
    LibraryType? type,
    String? url,
    DateTime? dateAdded,
    String? lastReadUrl,
    double? lastReadPosition,
    DateTime? lastOpenedAt,
  }) {
    return LibraryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      url: url ?? this.url,
      dateAdded: dateAdded ?? this.dateAdded,
      lastReadUrl: lastReadUrl ?? this.lastReadUrl,
      lastReadPosition: lastReadPosition ?? this.lastReadPosition,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'url': url,
        'dateAdded': dateAdded.toIso8601String(),
        'lastReadUrl': lastReadUrl,
        'lastReadPosition': lastReadPosition,
        'lastOpenedAt': lastOpenedAt?.toIso8601String(),
      };

  factory LibraryItem.fromJson(Map<dynamic, dynamic> json) {
    return LibraryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: LibraryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => LibraryType.novel,
      ),
      url: json['url'] as String,
      dateAdded: DateTime.parse(json['dateAdded'] as String),
      lastReadUrl: (json['lastReadUrl'] as String?) ?? json['url'] as String,
      lastReadPosition: (json['lastReadPosition'] as num?)?.toDouble() ?? 0,
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.tryParse(json['lastOpenedAt'] as String)
          : null,
    );
  }
}
