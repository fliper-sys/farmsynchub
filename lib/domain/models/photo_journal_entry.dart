/// A single dated photo entry in a crop or livestock photo journal.
class PhotoJournalEntry {
  const PhotoJournalEntry({
    required this.id,
    required this.base64,
    required this.date,
    this.caption = '',
    this.isFavorite = false,
  });

  final String id;
  final String base64;
  final DateTime date;
  final String caption;
  final bool isFavorite;

  PhotoJournalEntry copyWith({
    String? base64,
    DateTime? date,
    String? caption,
    bool? isFavorite,
  }) =>
      PhotoJournalEntry(
        id: id,
        base64: base64 ?? this.base64,
        date: date ?? this.date,
        caption: caption ?? this.caption,
        isFavorite: isFavorite ?? this.isFavorite,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'base64': base64,
        'date': date.toIso8601String(),
        'caption': caption,
        'isFavorite': isFavorite,
      };

  factory PhotoJournalEntry.fromJson(Map<String, dynamic> json) =>
      PhotoJournalEntry(
        id: json['id'] as String? ?? '',
        base64: json['base64'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        caption: json['caption'] as String? ?? '',
        isFavorite: json['isFavorite'] as bool? ?? false,
      );
}
