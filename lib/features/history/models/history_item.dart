class HistoryItem {
  final String id;
  final String imagePath;
  final String extractedText;
  final List<String> phoneNumbers;
  final List<String> websites;
  final List<String> addresses;
  final List<String> dates;
  final DateTime createdAt;

  const HistoryItem({
    required this.id,
    required this.imagePath,
    required this.extractedText,
    required this.phoneNumbers,
    required this.websites,
    required this.addresses,
    required this.dates,
    required this.createdAt,
  });

  // Convert HistoryItem into JSON-compatible data.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'imagePath': imagePath,
      'extractedText': extractedText,
      'phoneNumbers': phoneNumbers,
      'websites': websites,
      'addresses': addresses,
      'dates': dates,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Restore HistoryItem from stored data.
  factory HistoryItem.fromMap(Map<String, dynamic> map) {
    return HistoryItem(
      id: map['id'] as String,
      imagePath: map['imagePath'] as String,
      extractedText: map['extractedText'] as String,
      phoneNumbers: List<String>.from(map['phoneNumbers'] ?? []),
      websites: List<String>.from(map['websites'] ?? []),
      addresses: List<String>.from(map['addresses'] ?? []),
      dates: List<String>.from(map['dates'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}