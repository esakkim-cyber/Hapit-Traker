class CompletionModel {
  final String id;
  final String habitId;
  final String date; // YYYY-MM-DD
  final DateTime completedAt;
  final double? value;
  final String status; // 'completed', 'partial', 'missed'
  final String? notes;

  const CompletionModel({
    required this.id,
    required this.habitId,
    required this.date,
    required this.completedAt,
    this.value,
    this.status = 'completed',
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'habitId': habitId,
      'date': date,
      'completedAt': completedAt.toIso8601String(),
      'value': value,
      'status': status,
      'notes': notes,
    };
  }

  factory CompletionModel.fromJson(Map<String, dynamic> json) {
    return CompletionModel(
      id: json['id'] as String,
      habitId: json['habitId'] as String,
      date: json['date'] as String,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ?? DateTime.now(),
      value: (json['value'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'completed',
      notes: json['notes'] as String?,
    );
  }
}
