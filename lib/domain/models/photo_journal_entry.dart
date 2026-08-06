/// A single dated photo entry in a crop or livestock photo journal.
class PhotoJournalEntry {
  const PhotoJournalEntry({
    required this.id,
    required this.base64,
    required this.date,
    this.caption = '',
  });

  final String id;
  final String base64;
  final DateTime date;
  final String caption;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'base64': base64,
        'date': date.toIso8601String(),
        'caption': caption,
      };

  factory PhotoJournalEntry.fromJson(Map<String, dynamic> json) =>
      PhotoJournalEntry(
        id: json['id'] as String? ?? '',
        base64: json['base64'] as String? ?? '',
        date: DateTime.tryParse(json['date'] as String? ?? '') ??
            DateTime.now(),
        caption: json['caption'] as String? ?? '',
      );
}
